#!/bin/sh
# Exercise report validation without running the system-changing smoke suite.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0
mkdir -p "$WORK/bin"
cat > "$WORK/bin/kcov" << 'EOF_KCOV'
#!/bin/sh
set -eu
while [ "${1#--}" != "$1" ]; do shift; done
mkdir -p "$1/synthetic"
{
    printf '<coverage><classes>'
    for target in $COVERAGE_TEST_TARGETS; do
        printf '<class filename="%s"><lines><line number="3" hits="1"/></lines></class>' "$target"
    done
    printf '</classes></coverage>\n'
} > "$1/synthetic/cobertura.xml"
EOF_KCOV
chmod +x "$WORK/bin/kcov"
for targets in hosty.sh install.sh '' 'install.sh smoke.sh' 'hosty.sh smoke.sh'; do
    if PATH="$WORK/bin:$PATH" COVERAGE_TEST_TARGETS="$targets" \
        HOSTY_COVERAGE_DIR="$WORK/coverage" HOSTY_CI_LOG_DIR="$WORK/logs" \
        sh "$ROOT/ci/coverage.sh" > "$WORK/result" 2>&1; then
        printf 'ERROR: incomplete report passed (%s)\n' "$targets" >&2
        exit 1
    fi
    grep -q 'kcov reported no executable lines for' "$WORK/result"
done
PATH="$WORK/bin:$PATH" COVERAGE_TEST_TARGETS='hosty.sh install.sh' \
    HOSTY_COVERAGE_DIR="$WORK/coverage" HOSTY_CI_LOG_DIR="$WORK/logs" \
    sh "$ROOT/ci/coverage.sh" > "$WORK/result" 2>&1
printf '%s\n' 'OK: coverage requires both measured scripts'
