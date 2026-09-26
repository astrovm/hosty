#!/bin/sh
# Measure line coverage of hosty.sh and install.sh while running the offline
# smoke suite under kcov. Needs root (or passwordless sudo/doas), kcov, and
# python3. Fails when coverage is below HOSTY_COVERAGE_MIN percent.
#
# kcov traces shell scripts through bash DEBUG traps, so the measured copies run
# under bash instead of /bin/sh. The suite runs from a temporary copy of the
# repository whose hosty.sh and install.sh use a #!/bin/bash shebang; every
# copy of hosty the suite installs or runs is merged back into hosty.sh.
set -eu

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
LOG_DIR=${HOSTY_CI_LOG_DIR:-$ROOT/ci-logs}
COVERAGE_DIR=${HOSTY_COVERAGE_DIR:-$ROOT/coverage}
COVERAGE_MIN=${HOSTY_COVERAGE_MIN:-70}

command -v kcov > /dev/null 2>&1 || die "kcov is required for coverage"
command -v python3 > /dev/null 2>&1 || die "python3 is required for coverage"
command -v bash > /dev/null 2>&1 || die "bash is required for coverage"

WORK=$(mktemp -d) || die "mktemp -d failed"
cleanup() {
    rm -rf "$WORK"
}
trap cleanup 0

COPY="$WORK/repo"
mkdir -p "$COPY"
(cd "$ROOT" && tar -cf - --exclude=./.git --exclude=./ci-logs --exclude=./coverage .) |
    (cd "$COPY" && tar -xf -)
# DEBUG emits one trace record per command; PS4 output can interleave multi-line
# awk arguments from child processes. kcov's DEBUG helper unsets BASH_ENV, so
# install the same trap explicitly in each measured copy, without shifting lines.
HOSTY_COVERAGE_HELPER="$WORK/trace.sh"
export HOSTY_COVERAGE_HELPER
cat > "$HOSTY_COVERAGE_HELPER" << 'EOF_TRACE'
set -o functrace
trap 'printf "kcov@%s@%s@\n" "$BASH_SOURCE" "$LINENO" >&"$KCOV_BASH_XTRACEFD"' DEBUG
EOF_TRACE
for coverage_script in hosty.sh install.sh; do
    [ -z "$(sed -n '2p' "$ROOT/$coverage_script")" ] ||
        die "$coverage_script must have a blank second line for coverage instrumentation"
    # Expand the tracing variables in the measured shell, not while copying.
    # shellcheck disable=SC2016
    sed '1s|^#!/bin/sh$|#!/bin/bash|; 2c\
[ -z "${BASH_VERSION:-}" ] || . "$HOSTY_COVERAGE_HELPER"
' "$ROOT/$coverage_script" > "$COPY/$coverage_script"
    chmod 755 "$COPY/$coverage_script"
done

rm -rf "$COVERAGE_DIR"
mkdir -p "$LOG_DIR"
log "== hosty coverage (kcov) =="
HOSTY_CI_LOG_DIR="$LOG_DIR" kcov --bash-method=DEBUG --exclude-line=HOSTY_COVERAGE_HELPER \
    --include-pattern=/hosty.sh,/install.sh,/bin/hosty,/clean-test/hosty,/modes-test/hosty,/default-test/hosty \
    "$COVERAGE_DIR" "$COPY/ci/smoke.sh" || die "smoke suite failed under kcov"

python3 - "$COVERAGE_DIR" "$ROOT" "$COVERAGE_MIN" << 'EOF_PY'
import glob
import os
import sys
import xml.etree.ElementTree as ET

coverage_dir, root, minimum = sys.argv[1], sys.argv[2], float(sys.argv[3])
reports = [
    path
    for path in glob.glob(os.path.join(coverage_dir, "*", "cobertura.xml"))
    if os.path.basename(os.path.dirname(path)) != "kcov-merged"
]
if not reports:
    sys.exit("ERROR: kcov produced no report")

lines = {"hosty.sh": {}, "install.sh": {}}
for report in reports:
    for cls in ET.parse(report).getroot().iter("class"):
        name = os.path.basename(cls.get("filename"))
        target = "install.sh" if name == "install.sh" else "hosty.sh"
        for line in cls.iter("line"):
            number = int(line.get("number"))
            hits = int(line.get("hits"))
            lines[target][number] = max(lines[target].get(number, 0), hits)

total = covered = 0
for name, hits in sorted(lines.items()):
    if not hits:
        sys.exit(f"ERROR: kcov reported no executable lines for {name}")
    file_total = len(hits)
    file_covered = sum(1 for value in hits.values() if value > 0)
    total += file_total
    covered += file_covered
    percent = 100.0 * file_covered / file_total if file_total else 0.0
    print(f"{name}: {percent:.2f}% ({file_covered}/{file_total} lines)")
    with open(os.path.join(coverage_dir, f"{name}.uncovered"), "w") as output:
        source = open(os.path.join(root, name)).read().split("\n")
        for number in sorted(n for n, value in hits.items() if value == 0):
            output.write(f"{number}: {source[number - 1]}\n")

percent = 100.0 * covered / total if total else 0.0
print(f"total: {percent:.2f}% ({covered}/{total} lines), minimum {minimum:g}%")
if percent < minimum:
    sys.exit(f"ERROR: coverage {percent:.2f}% is below {minimum:g}%")
EOF_PY
