#!/bin/sh
# Exercise report validation without running the system-changing smoke suite.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/ci/lib.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0
mkdir -p "$WORK/bin"
# Report line 3 as covered for each of COVERAGE_TEST_TARGETS, or the
# COVERAGE_TEST_LINES "line:hits" pairs for hosty.sh when set, and log
# COVERAGE_TEST_MULTILINE lines as reported multi-line commands.
cat > "$WORK/bin/kcov" << 'EOF_KCOV'
#!/bin/sh
set -eu
while [ "${1#--}" != "$1" ]; do shift; done
mkdir -p "$1/synthetic"
{
    printf '<coverage><classes>'
    for target in $COVERAGE_TEST_TARGETS; do
        printf '<class filename="/copy/%s"><lines>' "$target"
        pairs=3:1
        if [ "$target" = hosty.sh ]; then
            pairs=${COVERAGE_TEST_LINES:-3:1}
        fi
        for pair in $pairs; do
            printf '<line number="%s" hits="%s"/>' "${pair%:*}" "${pair#*:}"
        done
        printf '</lines></class>'
    done
    printf '</classes></coverage>\n'
} > "$1/synthetic/cobertura.xml"
for line in ${COVERAGE_TEST_MULTILINE:-}; do
    printf '/copy/hosty.sh:%s\n' "$line" >> "$HOSTY_COVERAGE_MULTILINE"
done
EOF_KCOV
chmod +x "$WORK/bin/kcov"

run_coverage() {
    PATH="$WORK/bin:$PATH" HOSTY_COVERAGE_DIR="$WORK/coverage" HOSTY_CI_LOG_DIR="$WORK/logs" \
        sh "$COVERAGE_ROOT/ci/coverage.sh" > "$WORK/result" 2>&1
}

COVERAGE_ROOT=$ROOT
export COVERAGE_TEST_TARGETS COVERAGE_TEST_LINES COVERAGE_TEST_MULTILINE
for COVERAGE_TEST_TARGETS in hosty.sh install.sh '' 'install.sh smoke.sh' 'hosty.sh smoke.sh'; do
    if run_coverage; then
        die "incomplete report passed ($COVERAGE_TEST_TARGETS)"
    fi
    assert_file_contains "$WORK/result" 'kcov reported no executable lines for'
done
COVERAGE_TEST_TARGETS='hosty.sh install.sh'
run_coverage || {
    cat "$WORK/result"
    die "a report covering both scripts should pass"
}
assert_file_contains "$WORK/result" 'total: 100.00% (2/2 lines), minimum 100%'
printf '%s\n' 'OK: coverage requires both measured scripts'

# Map kcov lines onto a synthetic script whose awk programs, loop terminator,
# empty case arm, quotes and heredoc exercise the report's source scanner.
COVERAGE_ROOT="$WORK/repo"
mkdir -p "$COVERAGE_ROOT/ci"
cp "$ROOT/ci/coverage.sh" "$ROOT/ci/lib.sh" "$COVERAGE_ROOT/ci/"
: > "$COVERAGE_ROOT/ci/smoke.sh"
: > "$COVERAGE_ROOT/ci/test-hosts-write.sh"
printf '%s\n' '#!/bin/sh' '' 'set -eu' > "$COVERAGE_ROOT/install.sh"
cat > "$COVERAGE_ROOT/hosty.sh" << 'EOF_SCRIPT'
#!/bin/sh

count=$(awk '
    { n++ }
    END { print n }
' "$0")
awk '
    BEGIN { exit }
'
while read -r line; do
    : "$line" # it's a comment
done < "$0"
case $count in
    0) ;;
    *) printf '%s\n' "don't" ;;
esac
cat << 'EOF_TEXT'
it's text
EOF_TEXT
EOF_SCRIPT
traced='3:0 4:0 5:0 7:1 8:0 10:1 11:1 12:0 13:1 14:0 15:1 17:1'

COVERAGE_TEST_LINES=$traced
COVERAGE_TEST_MULTILINE=6
run_coverage || {
    cat "$WORK/result"
    die "reported multi-line assignment should cover its awk program"
}
# Lines 12 (done < file) and 14 (empty case arm) never produce trace records.
assert_file_contains "$WORK/result" 'hosty.sh: 100.00% (10/10 lines)'

COVERAGE_TEST_MULTILINE=
if run_coverage; then
    die "unreported multi-line assignment should leave its awk program uncovered"
fi
assert_file_contains "$WORK/result" 'hosty.sh: 70.00% (7/10 lines)'
assert_file_contains "$WORK/result" 'ERROR: coverage 72.73% is below 100%'
assert_eq "$(cat "$WORK/coverage/hosty.sh.uncovered")" "3: count=\$(awk '
4:     { n++ }
5:     END { print n }" "uncovered lines should list the whole awk program"

COVERAGE_TEST_LINES=$(printf '%s\n' "$traced" | sed 's/ 7:1 / 7:0 /')
COVERAGE_TEST_MULTILINE=6
if run_coverage; then
    die "an unexecuted awk command should leave its program uncovered"
fi
assert_eq "$(cut -d: -f1 "$WORK/coverage/hosty.sh.uncovered" | tr '\n' ' ')" "7 8 " \
    "an unexecuted awk command and its program should be uncovered"

printf '%s\n' "count=\$(awk '" > "$COVERAGE_ROOT/hosty.sh"
COVERAGE_TEST_LINES=1:1
if run_coverage; then
    die "an unterminated quote should fail the report"
fi
assert_file_contains "$WORK/result" 'unterminated quote or heredoc'
printf '%s\n' 'OK: coverage maps awk programs and ignores untraceable lines'
