#!/bin/sh
# Measure line coverage of hosty.sh and install.sh while running the offline
# smoke suite under kcov. Needs root (or passwordless sudo/doas), kcov, and
# python3. Fails when coverage is below HOSTY_COVERAGE_MIN percent.
#
# kcov traces shell scripts through bash DEBUG traps, so the measured copies run
# under bash instead of /bin/sh. The suite runs from a temporary copy of the
# repository whose hosty.sh and install.sh use a #!/bin/bash shebang; every
# copy of hosty the suite installs or runs is merged back into hosty.sh.
#
# Multi-line single-quoted strings are awk programs: bash reports each awk
# command on a single line, so the report gives the whole program that line's
# coverage. Terminator lines such as `done < file` and empty case arms never
# produce a trace record and are not counted.
set -eu

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
LOG_DIR=${HOSTY_CI_LOG_DIR:-$ROOT/ci-logs}
COVERAGE_DIR=${HOSTY_COVERAGE_DIR:-$ROOT/coverage}
COVERAGE_MIN=${HOSTY_COVERAGE_MIN:-100}

command -v kcov > /dev/null 2>&1 || die "kcov is required for coverage"
command -v python3 > /dev/null 2>&1 || die "python3 is required for coverage"
command -v bash > /dev/null 2>&1 || die "bash is required for coverage"

WORK=$(mktemp -d) || die "mktemp -d failed"
cleanup() {
    rm -rf "$WORK"
}
trap cleanup 0
# Smoke tests that drop root privileges run measured copies from here.
chmod 755 "$WORK"

COPY="$WORK/repo"
mkdir -p "$COPY"
(cd "$ROOT" && tar -cf - --exclude=./.git --exclude=./ci-logs --exclude=./coverage .) |
    (cd "$COPY" && tar -xf -)
# DEBUG emits one trace record per command; PS4 output can interleave multi-line
# awk arguments from child processes. kcov's DEBUG helper unsets BASH_ENV, so
# install the same trap explicitly in each measured copy, without shifting lines.
# Bash reports a multi-line assignment such as x=$(awk '...') on its last line,
# which kcov does not treat as executable, so also log where multi-line commands
# are reported; readable and writable by smoke tests that drop root privileges.
HOSTY_COVERAGE_HELPER="$WORK/trace.sh"
HOSTY_COVERAGE_MULTILINE="$WORK/multiline.log"
export HOSTY_COVERAGE_HELPER HOSTY_COVERAGE_MULTILINE
cat > "$HOSTY_COVERAGE_HELPER" << 'EOF_TRACE'
set -o functrace
HOSTY_COVERAGE_NEWLINE='
'
# Keep the trap on one line: LINENO advances inside a multi-line trap body.
trap 'printf "kcov@%s@%s@\n" "$BASH_SOURCE" "$LINENO" >&"$KCOV_BASH_XTRACEFD"; case $BASH_COMMAND in *"$HOSTY_COVERAGE_NEWLINE"*) printf "%s:%s\n" "$BASH_SOURCE" "$LINENO" >> "$HOSTY_COVERAGE_MULTILINE" ;; esac' DEBUG
EOF_TRACE
: > "$HOSTY_COVERAGE_MULTILINE"
chmod 666 "$HOSTY_COVERAGE_MULTILINE"
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
COVERAGE_INCLUDE=/hosty.sh,/install.sh,/bin/hosty,/clean-test/hosty,/modes-test/hosty
COVERAGE_INCLUDE=$COVERAGE_INCLUDE,/default-test/hosty,/unprivileged-test/hosty,/hosts-writer/hosty
HOSTY_CI_LOG_DIR="$LOG_DIR" kcov --bash-method=DEBUG --exclude-line=HOSTY_COVERAGE_HELPER \
    --include-pattern="$COVERAGE_INCLUDE" \
    "$COVERAGE_DIR" "$COPY/ci/smoke.sh" || die "smoke suite failed under kcov"
kcov --bash-method=DEBUG --exclude-line=HOSTY_COVERAGE_HELPER \
    --include-pattern="$COVERAGE_INCLUDE" \
    "$COVERAGE_DIR" "$COPY/ci/test-hosts-write.sh" || die "hosts-file writer tests failed under kcov"

python3 - "$COVERAGE_DIR" "$ROOT" "$COVERAGE_MIN" "$HOSTY_COVERAGE_MULTILINE" << 'EOF_PY'
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

coverage_dir, root, minimum, multiline_log = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]

# Lines bash never reports through DEBUG traps: compound-command terminators
# (including their redirections) and case arms without a command.
UNTRACEABLE = re.compile(r"^\s*(?:(?:done|fi|esac|\})(?:\s.*)?|[^)]*\)\s*;;)\s*$")
HEREDOC = re.compile(r"""<<-?\s*(['"]?)(\w+)\1""")


def quoted_spans(source):
    """Return (first, last) line numbers of single-quoted strings spanning lines.

    Such strings are programs for other interpreters (awk). Bash reports the
    whole command on one of its lines, so every line of the span shares that
    line's coverage.
    """
    spans = []
    single_start = None
    in_double = False
    heredoc = None
    for number, text in enumerate(source, 1):
        if heredoc is not None:
            if text.lstrip("\t") == heredoc:
                heredoc = None
            continue
        pending_heredoc = None
        index = 0
        while index < len(text):
            char = text[index]
            if single_start is not None:
                if char == "'":
                    if single_start != number:
                        spans.append((single_start, number))
                    single_start = None
            elif char == "\\":
                index += 1
            elif in_double:
                in_double = char != '"'
            elif char == "'":
                single_start = number
            elif char == '"':
                in_double = True
            elif char == "#" and (index == 0 or text[index - 1] in " \t;|&("):
                break
            elif text.startswith("<<", index):
                match = HEREDOC.match(text, index)
                if match:
                    pending_heredoc = match.group(2)
                    index = match.end()
                    continue
            index += 1
        if pending_heredoc is not None:
            heredoc = pending_heredoc
    if single_start is not None or in_double or heredoc is not None:
        sys.exit("ERROR: unterminated quote or heredoc while mapping coverage")
    return spans


reports = [
    path
    for path in glob.glob(os.path.join(coverage_dir, "*", "cobertura.xml"))
    if os.path.basename(os.path.dirname(path)) != "kcov-merged"
]
if not reports:
    sys.exit("ERROR: kcov produced no report")

def target_of(path):
    name = os.path.basename(path)
    if name not in {"install.sh", "hosty.sh", "hosty"}:
        return None
    return "install.sh" if name == "install.sh" else "hosty.sh"


multiline_ends = {"hosty.sh": set(), "install.sh": set()}
with open(multiline_log) as log:
    for record in log:
        path, _, number = record.rstrip("\n").rpartition(":")
        target = target_of(path)
        if target:
            multiline_ends[target].add(int(number))

lines = {"hosty.sh": {}, "install.sh": {}}
for report in reports:
    for cls in ET.parse(report).getroot().iter("class"):
        target = target_of(cls.get("filename"))
        if not target:
            continue
        for line in cls.iter("line"):
            number = int(line.get("number"))
            hits = int(line.get("hits"))
            lines[target][number] = max(lines[target].get(number, 0), hits)

total = covered = 0
for name, hits in sorted(lines.items()):
    if not hits:
        sys.exit(f"ERROR: kcov reported no executable lines for {name}")
    with open(os.path.join(root, name)) as script:
        source = script.read().split("\n")
    # Test harnesses may append a driver after a copy of the measured script.
    for number in [n for n in hits if n > len(source)]:
        del hits[number]
    for first, last in quoted_spans(source):
        span = range(first, last + 1)
        span_hits = max(hits.get(number, 0) for number in span)
        if last in multiline_ends[name]:
            span_hits = max(span_hits, 1)
        for number in span:
            if number in hits:
                hits[number] = span_hits
    for number in list(hits):
        if UNTRACEABLE.match(source[number - 1]):
            del hits[number]
    file_total = len(hits)
    file_covered = sum(1 for value in hits.values() if value > 0)
    total += file_total
    covered += file_covered
    percent = 100.0 * file_covered / file_total if file_total else 0.0
    print(f"{name}: {percent:.2f}% ({file_covered}/{file_total} lines)")
    with open(os.path.join(coverage_dir, f"{name}.uncovered"), "w") as output:
        for number in sorted(n for n, value in hits.items() if value == 0):
            output.write(f"{number}: {source[number - 1]}\n")

percent = 100.0 * covered / total if total else 0.0
print(f"total: {percent:.2f}% ({covered}/{total} lines), minimum {minimum:g}%")
if percent < minimum:
    sys.exit(f"ERROR: coverage {percent:.2f}% is below {minimum:g}%")
EOF_PY
