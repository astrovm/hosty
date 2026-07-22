#!/bin/sh
# Health-check project and lists/*.sources URLs.
# Project (4st.li) URLs must succeed. Third-party list URLs may flake; the job
# fails only if more than MAX_THIRD_PARTY_FAILURE_PCT of them fail.
set -euf

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
LOG_DIR=${HOSTY_CI_LOG_DIR:-$ROOT/ci-logs}
MAX_THIRD_PARTY_FAILURE_PCT=${MAX_THIRD_PARTY_FAILURE_PCT:-25}
mkdir -p "$LOG_DIR"
report="$LOG_DIR/source-check.txt"
: > "$report"
: > "$LOG_DIR/source-check.err"

project_failures=0
third_checked=0
third_failures=0

check_url() {
    url=$1
    # Prefer HEAD; some hosts reject it, so fall back to a ranged GET.
    if curl -fsSIL --retry 2 --max-time 20 -o /dev/null "$url" 2>> "$LOG_DIR/source-check.err"; then
        log "OK   $url" | tee -a "$report"
        return 0
    fi
    if curl -fsSL --retry 2 --max-time 20 -r 0-0 -o /dev/null "$url" 2>> "$LOG_DIR/source-check.err"; then
        log "OK   $url (GET range)" | tee -a "$report"
        return 0
    fi
    log "FAIL $url" | tee -a "$report"
    return 1
}

log "== checking project URLs (must pass) =="
for url in \
    "https://4st.li/hosty/lists/blacklist.sources" \
    "https://4st.li/hosty/lists/whitelist.sources" \
    "https://4st.li/hosty/hosty.sh" \
    "https://4st.li/hosty/install.sh"; do
    if ! check_url "$url"; then
        project_failures=$((project_failures + 1))
    fi
done

log "== checking lists/*.sources entries (third-party, soft threshold) =="
for list in "$ROOT"/lists/*.sources; do
    [ -f "$list" ] || continue
    log "-- $(basename "$list") --" | tee -a "$report"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            '' | \#*) continue ;;
        esac
        third_checked=$((third_checked + 1))
        if ! check_url "$line"; then
            third_failures=$((third_failures + 1))
        fi
    done < "$list"
done

log
log "project_failures=$project_failures third_checked=$third_checked third_failures=$third_failures"

if [ "$project_failures" -gt 0 ]; then
    die "$project_failures project URL(s) failed (see $report)"
fi

if [ "$third_checked" -gt 0 ]; then
    # Integer percent: failures * 100 / checked
    pct=$((third_failures * 100 / third_checked))
    log "third-party failure rate: ${pct}% (max allowed ${MAX_THIRD_PARTY_FAILURE_PCT}%)"
    if [ "$pct" -gt "$MAX_THIRD_PARTY_FAILURE_PCT" ]; then
        die "too many third-party source failures: ${pct}% > ${MAX_THIRD_PARTY_FAILURE_PCT}%"
    fi
fi

log "source URL health checks passed"
