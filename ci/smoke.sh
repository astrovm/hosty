#!/bin/sh
# Offline-first functional smoke tests for hosty.
# RUN_NETWORK=1              also exercise default remote sources
# RUN_PRODUCTION_INSTALL=1   install from https://4st.li (main/schedule)
# Note: do not use set -f (noglob) — globs are intentional below.
set -eu

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
HOSTY="$ROOT/hosty.sh"
INSTALL="$ROOT/install.sh"
FIXTURE_BLACKLIST="$ROOT/ci/fixtures/blacklist"
FIXTURE_WHITELIST="$ROOT/ci/fixtures/whitelist"
LOG_DIR=${HOSTY_CI_LOG_DIR:-$ROOT/ci-logs}
RUN_NETWORK=${RUN_NETWORK:-0}
RUN_PRODUCTION_INSTALL=${RUN_PRODUCTION_INSTALL:-0}
MARKER="# Ad blocking hosts generated"
DEST_BIN=/usr/local/bin/hosty

mkdir -p "$LOG_DIR"
export HOSTY_CI_LOG_DIR="$LOG_DIR"

log "== hosty CI smoke (network=$RUN_NETWORK production_install=$RUN_PRODUCTION_INSTALL) =="
log "repo: $ROOT"
log "logs: $LOG_DIR"

chmod +x "$HOSTY" "$INSTALL" \
    "$ROOT/ci/expect/install-n.exp" \
    "$ROOT/ci/expect/install-yes.exp"

# --- cleanup -----------------------------------------------------------------
# Prefer the pre-smoke /etc/hosts snapshot when present (marker-on-line-1 tests
# overwrite the real file). Otherwise restore via hosty -r if a marker remains.
cleanup() {
    if [ -f "$LOG_DIR/etc-hosts.pre-smoke" ]; then
        as_root cp "$LOG_DIR/etc-hosts.pre-smoke" /etc/hosts 2> /dev/null || true
    elif [ -f /etc/hosts ] && grep -qF "$MARKER" /etc/hosts 2> /dev/null; then
        as_root "$HOSTY" -r > "$LOG_DIR/cleanup-restore.out" 2>&1 || true
    fi
    as_root rm -rf /etc/hosty 2> /dev/null || true
    as_root rm -f /usr/local/bin/.hosty.* 2> /dev/null || true
}

# --- CLI ---------------------------------------------------------------------
log "-- help / version --"
help_out=$("$HOSTY" -h 2>&1) || true
assert_contains "$help_out" "usage: hosty" "help should show usage"
assert_contains "$help_out" "--debug" "help should list --debug"

version_out=$("$HOSTY" -v 2>&1)
expected_version=$(awk -F\" '/^VERSION=/ {print $2; exit}' "$HOSTY")
assert_eq "$version_out" "$expected_version" "version should match VERSION in hosty.sh"

if command -v dash > /dev/null 2>&1 && dash -c 'exit 0' 2> /dev/null; then
    log "-- dash -n + dash help/version --"
    dash -n "$HOSTY"
    dash -n "$INSTALL"
    dash "$HOSTY" -h > /dev/null
    assert_eq "$(dash "$HOSTY" -v)" "$expected_version" "dash hosty -v should match"
else
    log "-- dash not available; skipping POSIX shell runtime checks --"
fi

log "-- sh -n --"
sh -n "$HOSTY"
sh -n "$INSTALL"

# --- fixtures / system helpers -----------------------------------------------
setup_fixtures() {
    log "-- installing offline fixtures into /etc/hosty --"
    as_root mkdir -p /etc/hosty
    as_root cp "$FIXTURE_BLACKLIST" /etc/hosty/blacklist
    as_root cp "$FIXTURE_WHITELIST" /etc/hosty/whitelist
    as_root rm -f /etc/hosty/blacklist.sources /etc/hosty/whitelist.sources
}

assert_installed_workspace() {
    label=$1
    [ -x "$DEST_BIN" ] || die "hosty binary missing after $label"
    assert_eq "$("$DEST_BIN" -v)" "$expected_version" \
        "installed binary after $label should be workspace version"
}

assert_autorun_cron() {
    label=$1
    if ! command -v crontab > /dev/null 2>&1; then
        log "crontab not present; skip autorun assert after $label"
        return 0
    fi
    cron_out=$(as_root crontab -l 2> /dev/null || true)
    printf '%s\n' "$cron_out" | grep -qF '/usr/local/bin/hosty' ||
        die "crontab missing hosty entry after $label"
}

uninstall_hosty() {
    out=$1
    if [ -d /etc/hosty ]; then
        printf 'n\n' | as_root "$DEST_BIN" -u > "$out" 2>&1
    else
        as_root "$DEST_BIN" -u > "$out" 2>&1
    fi || {
        cat "$out"
        die "hosty -u failed"
    }
    assert_file_contains "$out" "hosty uninstalled"
    [ ! -f "$DEST_BIN" ] || die "hosty binary still present after uninstall"
}

# --- offline debug -----------------------------------------------------------
run_debug_offline() {
    log "-- hosty -di (offline fixtures, private TMPDIR) --"
    tmpdir=$(mktemp -d) || die "mktemp -d failed"
    out="$LOG_DIR/debug-di.out"
    set +e
    TMPDIR="$tmpdir" "$HOSTY" -di > "$out" 2>&1
    rc=$?
    set -e
    cat "$out"
    [ "$rc" -eq 0 ] || {
        rm -rf "$tmpdir"
        die "hosty -di failed with exit $rc"
    }

    assert_file_contains "$out" "DEBUG MODE ON"
    built=$(awk '/^building / {print $2}' "$out" | tail -n 1)
    [ -n "$built" ] && [ -f "$built" ] || {
        rm -rf "$tmpdir"
        die "could not parse debug hosts path"
    }

    # Tracked temps must be cleaned; debug OUTPUT_HOSTS is intentionally kept.
    assert_no_extra_files "$tmpdir" "$built" \
        "leaked temp files after -di (TEMPS tracking broken?)"

    cp "$built" "$LOG_DIR/debug-di.hosts"

    assert_file_contains "$built" "$MARKER"
    assert_file_contains "$built" "0.0.0.0 ads.example.test"
    assert_file_contains "$built" "0.0.0.0 malware.example.test"
    if grep -qE '^0\.0\.0\.0[[:space:]]+tracker\.example\.test$' "$built"; then
        rm -rf "$tmpdir"
        die "whitelisted domain tracker.example.test was blocked"
    fi

    count=$(blocked_count_from "$out")
    [ -n "$count" ] || {
        rm -rf "$tmpdir"
        die "could not parse blocked count from offline debug run"
    }
    assert_gt "$count" 0 "expected at least one blocked domain, got '$count'"
    log "offline debug blocked count: $count"

    # Over-cleanup regression: debug hosts must still exist after exit.
    [ -f "$built" ] || {
        rm -rf "$tmpdir"
        die "debug hosts file was deleted after exit"
    }
    log "debug hosts kept after EXIT: $built"

    rm -rf "$tmpdir"
}

# --- offline system write ----------------------------------------------------
run_system_offline() {
    # Snapshot real hosts before any mutation (marker-on-line-1 overwrites it).
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.pre-smoke"

    log "-- system hosty -i (offline fixtures, writes /etc/hosts) --"
    out="$LOG_DIR/system-i.out"
    as_root "$HOSTY" -i > "$out" 2>&1 || {
        cat "$out"
        die "hosty -i failed"
    }
    tail -n 20 "$out"
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.after-i"

    # Mode must stay world-readable (historical CI failure: 0600 from mktemp+mv).
    assert_mode /etc/hosts 644 "/etc/hosts should be world-readable after -i"
    log "/etc/hosts mode after -i: $(file_mode /etc/hosts)"

    # Idempotent rebuild on an already hosty-managed hosts file.
    log "-- system hosty -i again (idempotent rebuild) --"
    out="$LOG_DIR/system-i2.out"
    as_root "$HOSTY" -i > "$out" 2>&1 || {
        cat "$out"
        die "second hosty -i failed"
    }
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    assert_mode /etc/hosts 644 "/etc/hosts should stay 644 after second -i"
    marker_lines=$(grep -cF "$MARKER" /etc/hosts || true)
    # Exactly one hosty block header expected after rebuild.
    [ "$marker_lines" -eq 1 ] || die "expected 1 marker line after rebuild, got $marker_lines"

    log "-- system hosty -r (restore original user hosts) --"
    out="$LOG_DIR/system-r.out"
    as_root "$HOSTY" -r > "$out" 2>&1 || {
        cat "$out"
        die "hosty -r failed"
    }
    cat "$out"
    assert_file_not_contains /etc/hosts "$MARKER"
    assert_file_not_contains /etc/hosts "0.0.0.0 ads.example.test"

    # Marker-on-line-1: empty user section (head -n 0 / empty restore base).
    # Uses a disposable hosts body; real hosts restored from pre-smoke snapshot after.
    log "-- system hosty -i with marker on line 1 --"
    as_root sh -c "printf '%s\n0.0.0.0 pre-existing.example\n' '$MARKER' > /etc/hosts"
    out="$LOG_DIR/system-i-marker1.out"
    as_root "$HOSTY" -i > "$out" 2>&1 || {
        cat "$out"
        die "hosty -i with marker on line 1 failed"
    }
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    assert_mode /etc/hosts 644 "/etc/hosts should be 644 after marker-on-line-1 -i"
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.after-marker1"

    log "-- system hosty -r after marker-on-line-1 --"
    out="$LOG_DIR/system-r-marker1.out"
    as_root "$HOSTY" -r > "$out" 2>&1 || {
        cat "$out"
        die "hosty -r after marker-on-line-1 failed"
    }
    assert_file_not_contains /etc/hosts "$MARKER"
    assert_file_not_contains /etc/hosts "0.0.0.0 ads.example.test"

    # Put back the real pre-smoke hosts for the rest of the suite / machine.
    as_root cp "$LOG_DIR/etc-hosts.pre-smoke" /etc/hosts
    log "restored pre-smoke /etc/hosts snapshot"
}

# --- network -----------------------------------------------------------------
run_debug_network() {
    log "-- hosty -d (default remote sources) --"
    out="$LOG_DIR/debug-d.out"
    set +e
    "$HOSTY" -d > "$out" 2>&1
    rc=$?
    set -e
    tail -n 50 "$out" || true
    [ "$rc" -eq 0 ] || die "hosty -d failed with exit $rc"

    assert_file_contains "$out" "DEBUG MODE ON"
    assert_file_contains "$out" "downloading default sources"
    assert_file_contains "$out" "downloading blacklists"
    built=$(awk '/^building / {print $2}' "$out" | tail -n 1)
    [ -n "$built" ] && [ -f "$built" ] || die "debug hosts file missing after -d"
    cp "$built" "$LOG_DIR/debug-d.hosts"
    assert_file_contains "$built" "$MARKER"
    assert_file_contains "$built" "0.0.0.0 "

    count=$(blocked_count_from "$out")
    [ -n "$count" ] || die "could not parse blocked count from network debug run"
    assert_gt "$count" 1000 "expected a large blocklist from defaults, got '$count'"
    log "network debug blocked count: $count"
}

run_system_network() {
    log "-- system hosty (default remote sources) --"
    out="$LOG_DIR/system-full.out"
    as_root "$HOSTY" > "$out" 2>&1 || {
        tail -n 80 "$out"
        die "full hosty run failed"
    }
    tail -n 20 "$out"
    assert_file_contains "$out" "downloading default sources"
    assert_file_contains /etc/hosts "$MARKER"
    assert_mode /etc/hosts 644 "/etc/hosts should be 644 after network full run"

    count=$(blocked_count_from "$out")
    [ -n "$count" ] || die "could not parse blocked count from full run"
    assert_gt "$count" 1000 "expected substantial blocklist, got '$count'"
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.after-full"
    as_root "$HOSTY" -r > "$LOG_DIR/system-full-restore.out" 2>&1
}

# --- installer ---------------------------------------------------------------
run_install_tests() {
    log "-- installer tests (HOSTY_URL=workspace hosty.sh) --"
    command -v expect > /dev/null 2>&1 || die "expect is required for installer tests"

    # cronie/busybox may need the spool dir for crontab writes during -a
    as_root mkdir -p /var/spool/cron/crontabs 2> /dev/null || true

    export HOSTY_URL="$HOSTY"
    as_root rm -f "$DEST_BIN"

    log "install answering n"
    expect "$ROOT/ci/expect/install-n.exp" "$INSTALL" > "$LOG_DIR/install-n.out" 2>&1 || {
        cat "$LOG_DIR/install-n.out"
        die "install-n failed"
    }
    assert_installed_workspace "install-n"
    assert_no_hosty_staging "staging left after install-n"
    as_root rm -f "$DEST_BIN"

    log "install via cat | sh answering y/daily"
    expect "$ROOT/ci/expect/install-yes.exp" sh -c "cat '$INSTALL' | sh" \
        > "$LOG_DIR/install-cat-yes.out" 2>&1 || {
        cat "$LOG_DIR/install-cat-yes.out"
        die "install via cat | sh failed"
    }
    assert_installed_workspace "cat|sh install"
    assert_autorun_cron "cat|sh install"
    assert_no_hosty_staging "staging left after cat|sh install"
    as_root rm -f "$DEST_BIN"

    if [ "$(id -u)" -ne 0 ] && command -v sudo > /dev/null 2>&1; then
        log "install with sudo answering y/daily"
        expect "$ROOT/ci/expect/install-yes.exp" sudo -E env "HOSTY_URL=$HOSTY" "$INSTALL" \
            > "$LOG_DIR/install-sudo-yes.out" 2>&1 || {
            cat "$LOG_DIR/install-sudo-yes.out"
            die "sudo install failed"
        }
        assert_installed_workspace "sudo install"
        assert_autorun_cron "sudo install"
        assert_no_hosty_staging "staging left after sudo install"
    else
        log "install as root answering y/daily"
        expect "$ROOT/ci/expect/install-yes.exp" "$INSTALL" \
            > "$LOG_DIR/install-root-yes.out" 2>&1 || {
            cat "$LOG_DIR/install-root-yes.out"
            die "root install failed"
        }
        assert_installed_workspace "root install"
        assert_autorun_cron "root install"
        assert_no_hosty_staging "staging left after root install"
    fi

    log "-- uninstall --"
    uninstall_hosty "$LOG_DIR/uninstall.out"
    assert_no_hosty_staging "staging left after uninstall"
}

# Reject http://, reject non-hosty payload without wiping a good install.
run_install_negative_tests() {
    log "-- installer negative tests --"

    # http:// is never allowed (privileged install source must be trusted).
    log "reject HOSTY_URL=http://"
    out="$LOG_DIR/install-http-reject.out"
    set +e
    as_root env HOSTY_URL="http://example.invalid/hosty.sh" "$INSTALL" \
        > "$out" 2>&1
    rc=$?
    set -e
    [ "$rc" -ne 0 ] || {
        cat "$out"
        die "http:// HOSTY_URL should fail"
    }
    assert_file_contains "$out" "HOSTY_URL must be https://"
    assert_no_hosty_staging "staging left after http reject"
    log "http:// HOSTY_URL rejected (exit $rc)"

    # Seed a known-good binary, then try to replace it with a non-hosty payload.
    log "bad payload must not replace a good install"
    as_root cp "$HOSTY" "$DEST_BIN"
    as_root chmod 755 "$DEST_BIN"
    good_v=$("$DEST_BIN" -v)
    assert_eq "$good_v" "$expected_version" "seeded good install version"

    bad=$(mktemp) || die "mktemp failed"
    # Exits non-zero for any invocation so staged -v verification fails.
    printf '%s\n' '#!/bin/sh' 'exit 1' > "$bad"
    chmod 755 "$bad"

    out="$LOG_DIR/install-bad-payload.out"
    set +e
    as_root env HOSTY_URL="$bad" "$INSTALL" > "$out" 2>&1
    rc=$?
    set -e
    rm -f "$bad"

    [ "$rc" -ne 0 ] || {
        cat "$out"
        die "bad payload install should fail"
    }
    assert_file_contains "$out" "staged file does not look like a working hosty"
    [ -x "$DEST_BIN" ] || die "good hosty binary was removed after bad payload"
    assert_eq "$("$DEST_BIN" -v)" "$good_v" \
        "good install must survive bad payload"
    assert_no_hosty_staging "staging left after bad payload"
    log "good install preserved after bad payload (exit $rc)"

    # Leave system clean for any later steps / cleanup.
    as_root rm -f "$DEST_BIN"
}

run_production_install() {
    log "-- production install smoke (https://4st.li) --"
    command -v expect > /dev/null 2>&1 || die "expect required"
    as_root rm -f "$DEST_BIN"

    # Empty HOSTY_URL falls back to the production URL inside install.sh
    expect "$ROOT/ci/expect/install-n.exp" env HOSTY_URL= "$INSTALL" \
        > "$LOG_DIR/install-production.out" 2>&1 || {
        cat "$LOG_DIR/install-production.out"
        die "production install failed"
    }
    [ -x "$DEST_BIN" ] || die "production hosty binary missing"
    assert_no_hosty_staging "staging left after production install"
    as_root "$DEST_BIN" -v > "$LOG_DIR/production-version.out" 2>&1
    cat "$LOG_DIR/production-version.out"

    # Must leave the system clean and must fail the job if uninstall breaks
    if [ -d /etc/hosty ]; then
        printf 'y\n' | as_root "$DEST_BIN" -u > "$LOG_DIR/production-uninstall.out" 2>&1
    else
        as_root "$DEST_BIN" -u > "$LOG_DIR/production-uninstall.out" 2>&1
    fi || {
        cat "$LOG_DIR/production-uninstall.out"
        die "production uninstall failed"
    }
    assert_file_contains "$LOG_DIR/production-uninstall.out" "hosty uninstalled"
    [ ! -f "$DEST_BIN" ] || die "production hosty still present after uninstall"
}

# --- run ---------------------------------------------------------------------
can_as_root || die "this smoke suite needs root or passwordless sudo"

setup_fixtures
trap cleanup EXIT

run_debug_offline
run_system_offline
run_install_tests
run_install_negative_tests

if [ "$RUN_NETWORK" = 1 ]; then
    run_debug_network
    run_system_network
fi

if [ "$RUN_PRODUCTION_INSTALL" = 1 ]; then
    run_production_install
fi

log
log "OK: all smoke checks passed"
