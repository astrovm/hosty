#!/bin/sh
# Exercise the production writer against temporary files, never /etc/hosts.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/ci/lib.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0
# Keep only the writer and its helpers, blanking other lines so option parsing
# and system writes cannot run and line numbers still match hosty.sh.
WRITER="$WORK/hosts-writer/hosty"
mkdir -p "$WORK/hosts-writer"
awk '
    /^(fail|install_hosts_file)\(\) \{/ { copying = 1 }
    NR <= 3 || copying { print; if (copying && /^\}/) copying = 0; next }
    { print "" }
' "$ROOT/hosty.sh" > "$WRITER"
cat >> "$WRITER" << 'EOF_DRIVER'
OUTPUT_HOSTS=$1
if [ -n "${HOSTS_WRITER_FAULTS:-}" ]; then
    . "$HOSTS_WRITER_FAULTS"
fi
install_hosts_file "$2"
EOF_DRIVER
chmod 755 "$WRITER"

write_hosts() {
    HOSTS_WRITER_FAULTS=${FAULTS:-} "$WRITER" "$OUTPUT_HOSTS" "$WORK/source"
}

printf '%s\n' '127.0.0.1 localhost' '0.0.0.0 ads.example.test' > "$WORK/source"
OUTPUT_HOSTS="$WORK/hosts"
for mode in 600 640 644; do
    printf '%s\n' old > "$OUTPUT_HOSTS"
    chmod "$mode" "$OUTPUT_HOSTS"
    # A hard link proves that the existing inode is retained.
    ln "$OUTPUT_HOSTS" "$WORK/linked-hosts"
    write_hosts
    assert_mode "$OUTPUT_HOSTS" "$mode" "writing existing hosts should preserve mode"
    cmp "$WORK/source" "$OUTPUT_HOSTS"
    cmp "$WORK/source" "$WORK/linked-hosts"
    rm "$WORK/linked-hosts"
done
rm "$OUTPUT_HOSTS"
write_hosts
assert_mode "$OUTPUT_HOSTS" 644 "new hosts should be world-readable"
cmp "$WORK/source" "$OUTPUT_HOSTS"

# Simulate a busy bind mount: first write and rename fail, retry succeeds.
FAULTS="$WORK/busy-mount.faults"
cat > "$FAULTS" << 'EOF_FAULTS'
cat_calls=0
cat() {
    cat_calls=$((cat_calls + 1))
    if [ "$HOSTS_EXISTING" = yes ] && [ "$cat_calls" -eq 2 ]; then
        return 1
    fi
    command cat "$@"
}
mv() { return 1; }
EOF_FAULTS
for HOSTS_EXISTING in yes no; do
    export HOSTS_EXISTING
    if [ "$HOSTS_EXISTING" = yes ]; then
        printf '%s\n' old > "$OUTPUT_HOSTS"
        chmod 640 "$OUTPUT_HOSTS"
        expected_mode=640
    else
        rm "$OUTPUT_HOSTS"
        expected_mode=644
    fi
    write_hosts
    assert_mode "$OUTPUT_HOSTS" "$expected_mode" "fallback write should use the correct mode"
    cmp "$WORK/source" "$OUTPUT_HOSTS"
done
for leftover in "$WORK"/.hosty.*; do
    [ ! -e "$leftover" ] || die "staging file was not removed"
done

# The hosts directory refuses new files: stage in TMPDIR, then write in place.
FAULTS="$WORK/no-staging-in-destination.faults"
cat > "$FAULTS" << 'EOF_FAULTS'
mktemp() {
    case ${1:-} in
        */.hosty.*) return 1 ;;
    esac
    command mktemp "$@"
}
EOF_FAULTS
mkdir "$WORK/tmp"
printf '%s\n' old > "$OUTPUT_HOSTS"
chmod 600 "$OUTPUT_HOSTS"
TMPDIR="$WORK/tmp" write_hosts
cmp "$WORK/source" "$OUTPUT_HOSTS"
assert_mode "$OUTPUT_HOSTS" 600 "staging elsewhere should still preserve mode"
assert_no_extra_files "$WORK/tmp" "" "staging file in TMPDIR was not removed"

# No temporary file can be created anywhere: abort before touching hosts.
FAULTS="$WORK/no-mktemp.faults"
printf '%s\n' 'mktemp() { return 1; }' > "$FAULTS"
printf '%s\n' old > "$OUTPUT_HOSTS"
if write_hosts > "$WORK/result" 2>&1; then
    die "writer should fail when no staging file can be created"
fi
assert_eq "$(cat "$OUTPUT_HOSTS")" old "hosts should be unchanged without a staging file"

# Every write fails: report the error and keep the staged copy for recovery.
FAULTS=""
OUTPUT_HOSTS="$WORK/missing-directory/hosts"
if TMPDIR="$WORK/tmp" write_hosts > "$WORK/result" 2>&1; then
    die "writer should fail when the destination cannot be written"
fi
assert_file_contains "$WORK/result" "failed to write $OUTPUT_HOSTS; recovery copy kept at $WORK/tmp/"
recovery_copy=$(sed -n 's/.*recovery copy kept at //p' "$WORK/result")
cmp "$WORK/source" "$recovery_copy"
[ ! -e "$OUTPUT_HOSTS" ] || die "unwritable destination should not be created"
printf '%s\n' 'OK: hosts contents, modes, inode and failure recovery preserved'
