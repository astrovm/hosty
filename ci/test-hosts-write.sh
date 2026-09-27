#!/bin/sh
# Exercise the production writer against temporary files, never /etc/hosts.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/ci/lib.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0
# Load only this function so option parsing and system writes cannot run.
awk '/^install_hosts_file\(\) \{/ { copying = 1 } copying { print } copying && /^\}/ { exit }' \
    "$ROOT/hosty.sh" > "$WORK/writer.sh"
# shellcheck disable=SC1091
. "$WORK/writer.sh"
fail() { die "$*"; }
printf '%s\n' '127.0.0.1 localhost' '0.0.0.0 ads.example.test' > "$WORK/source"
OUTPUT_HOSTS="$WORK/hosts"
for mode in 600 640 644; do
    printf '%s\n' old > "$OUTPUT_HOSTS"
    chmod "$mode" "$OUTPUT_HOSTS"
    # A hard link proves that the existing inode is retained.
    ln "$OUTPUT_HOSTS" "$WORK/linked-hosts"
    install_hosts_file "$WORK/source"
    assert_mode "$OUTPUT_HOSTS" "$mode" "writing existing hosts should preserve mode"
    cmp "$WORK/source" "$OUTPUT_HOSTS"
    cmp "$WORK/source" "$WORK/linked-hosts"
    rm "$WORK/linked-hosts"
done
rm "$OUTPUT_HOSTS"
install_hosts_file "$WORK/source"
assert_mode "$OUTPUT_HOSTS" 644 "new hosts should be world-readable"
cmp "$WORK/source" "$OUTPUT_HOSTS"
# Simulate a busy bind mount: first write and rename fail, retry succeeds.
for existing in yes no; do
    if [ "$existing" = yes ]; then
        printf '%s\n' old > "$OUTPUT_HOSTS"
        chmod 640 "$OUTPUT_HOSTS"
        expected_mode=640
    else
        rm "$OUTPUT_HOSTS"
        expected_mode=644
    fi
    cat_calls=0
    # Called by the sourced production writer.
    # shellcheck disable=SC2329
    cat() {
        cat_calls=$((cat_calls + 1))
        if [ "$existing" = yes ] && [ "$cat_calls" -eq 2 ]; then
            return 1
        fi
        command cat "$@"
    }
    # Called by the sourced production writer.
    # shellcheck disable=SC2329
    mv() { return 1; }
    install_hosts_file "$WORK/source"
    unset -f cat mv
    assert_mode "$OUTPUT_HOSTS" "$expected_mode" "fallback write should use the correct mode"
    cmp "$WORK/source" "$OUTPUT_HOSTS"
done
for leftover in "$WORK"/.hosty.*; do
    [ ! -e "$leftover" ] || die "staging file was not removed"
done
printf '%s\n' 'OK: hosts contents, existing modes and inode preserved; new files use 644'
