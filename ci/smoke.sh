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

has_terminal() {
    ( : < /dev/tty ) 2> /dev/null
}

cleanup() {
    if [ -f "$LOG_DIR/etc-hosts.pre-smoke" ]; then
        as_root cp "$LOG_DIR/etc-hosts.pre-smoke" /etc/hosts 2> /dev/null || true
    elif [ -f /etc/hosts ] && grep -qF -e "$MARKER" /etc/hosts 2> /dev/null; then
        as_root "$HOSTY" -r > "$LOG_DIR/cleanup-restore.out" 2>&1 || true
    fi
    as_root rm -rf /etc/hosty 2> /dev/null || true
    as_root rm -f /usr/local/bin/.hosty.* 2> /dev/null || true
}

# --- CLI and shell compatibility ----------------------------------------------

log "-- help / version / option parsing --"
help_out=$("$HOSTY" -h 2>&1) || true
assert_contains "$help_out" "usage: hosty" "help should show usage"
assert_contains "$help_out" "--debug" "help should list --debug"

version_out=$("$HOSTY" -v 2>&1)
expected_version=$(awk -F\" '/^VERSION=/ { print $2; exit }' "$HOSTY")
assert_eq "$version_out" "$expected_version" "version should match VERSION in hosty.sh"

if "$HOSTY" --unknown > "$LOG_DIR/unknown-long.out" 2>&1; then
    die "unknown long option should fail"
fi
assert_file_contains "$LOG_DIR/unknown-long.out" "unrecognized option: --unknown"

if "$HOSTY" -z > "$LOG_DIR/unknown-short.out" 2>&1; then
    die "unknown short option should fail"
fi
assert_file_contains "$LOG_DIR/unknown-short.out" "unrecognized option: -z"

log "-- sh syntax --"
sh -n "$HOSTY" "$INSTALL" "$ROOT/ci/smoke.sh" "$ROOT/ci/check-sources.sh" "$ROOT/ci/lib.sh"

if command -v dash > /dev/null 2>&1; then
    log "-- dash syntax and runtime --"
    dash -n "$HOSTY" "$INSTALL" "$ROOT/ci/smoke.sh" "$ROOT/ci/check-sources.sh" "$ROOT/ci/lib.sh"
    dash "$HOSTY" -h > /dev/null
    assert_eq "$(dash "$HOSTY" -v)" "$expected_version" "dash hosty -v should match"
fi

if command -v busybox > /dev/null 2>&1; then
    log "-- BusyBox ash syntax and runtime --"
    busybox ash -n "$HOSTY" "$INSTALL" "$ROOT/ci/smoke.sh" "$ROOT/ci/check-sources.sh" "$ROOT/ci/lib.sh"
    busybox ash "$HOSTY" -h > /dev/null
    assert_eq "$(busybox ash "$HOSTY" -v)" "$expected_version" "ash hosty -v should match"
fi

# --- fixtures -----------------------------------------------------------------

setup_direct_fixtures() {
    log "-- installing direct offline fixtures into /etc/hosty --"
    as_root mkdir -p /etc/hosty
    as_root cp "$FIXTURE_BLACKLIST" /etc/hosty/blacklist
    as_root cp "$FIXTURE_WHITELIST" /etc/hosty/whitelist
    as_root rm -f /etc/hosty/blacklist.sources /etc/hosty/whitelist.sources
}

setup_source_fixtures() {
    log "-- installing file:// source fixtures into /etc/hosty --"
    blacklist_source_list="$LOG_DIR/blacklist.sources.fixture"
    whitelist_source_list="$LOG_DIR/whitelist.sources.fixture"
    printf 'file://%s\n' "$FIXTURE_BLACKLIST" > "$blacklist_source_list"
    printf 'file://%s\n' "$FIXTURE_WHITELIST" > "$whitelist_source_list"

    as_root mkdir -p /etc/hosty
    as_root rm -f /etc/hosty/blacklist /etc/hosty/whitelist
    as_root cp "$blacklist_source_list" /etc/hosty/blacklist.sources
    as_root cp "$whitelist_source_list" /etc/hosty/whitelist.sources
}

assert_installed_workspace() {
    assert_installed_label=$1
    [ -x "$DEST_BIN" ] || die "hosty binary missing after $assert_installed_label"
    assert_eq "$("$DEST_BIN" -v)" "$expected_version" \
        "installed binary after $assert_installed_label should be workspace version"
}

assert_autorun_cron() {
    assert_autorun_label=$1
    if ! command -v crontab > /dev/null 2>&1; then
        log "crontab not present; skip autorun assert after $assert_autorun_label"
        return 0
    fi
    cron_out=$(as_root crontab -l 2> /dev/null || true)
    printf '%s\n' "$cron_out" | grep -qF -e '/usr/local/bin/hosty' ||
        die "crontab missing hosty entry after $assert_autorun_label"
}

uninstall_hosty() {
    uninstall_output=$1
    if [ -d /etc/hosty ]; then
        printf 'n\n' | as_root "$DEST_BIN" -u > "$uninstall_output" 2>&1
    else
        as_root "$DEST_BIN" -u > "$uninstall_output" 2>&1
    fi || {
        cat "$uninstall_output"
        die "hosty -u failed"
    }
    assert_file_contains "$uninstall_output" "hosty uninstalled"
    [ ! -f "$DEST_BIN" ] || die "hosty binary still present after uninstall"
}

run_debug_fixture() {
    run_debug_label=$1
    run_debug_output=$2
    run_debug_tmpdir=$(mktemp -d) || die "mktemp -d failed"

    log "-- $run_debug_label --"
    set +e
    TMPDIR="$run_debug_tmpdir" "$HOSTY" -di > "$run_debug_output" 2>&1
    run_debug_rc=$?
    set -e
    cat "$run_debug_output"
    [ "$run_debug_rc" -eq 0 ] || {
        rm -rf "$run_debug_tmpdir"
        die "$run_debug_label failed with exit $run_debug_rc"
    }

    assert_file_contains "$run_debug_output" "DEBUG MODE ON"
    run_debug_built=$(awk '/^building / { print $2 }' "$run_debug_output" | tail -n 1)
    [ -n "$run_debug_built" ] && [ -f "$run_debug_built" ] || {
        rm -rf "$run_debug_tmpdir"
        die "could not parse debug hosts path"
    }

    assert_no_extra_files "$run_debug_tmpdir" "$run_debug_built" \
        "temporary files leaked after $run_debug_label"
    assert_file_contains "$run_debug_built" "$MARKER"
    assert_file_contains "$run_debug_built" "0.0.0.0 ads.example.test"
    assert_file_contains "$run_debug_built" "0.0.0.0 malware.example.test"
    if grep -qE '^0\.0\.0\.0[[:space:]]+tracker\.example\.test$' "$run_debug_built"; then
        rm -rf "$run_debug_tmpdir"
        die "whitelisted domain tracker.example.test was blocked"
    fi

    run_debug_count=$(blocked_count_from "$run_debug_output")
    [ -n "$run_debug_count" ] || {
        rm -rf "$run_debug_tmpdir"
        die "could not parse blocked count"
    }
    assert_gt "$run_debug_count" 0 "expected at least one blocked domain"

    cp "$run_debug_built" "$LOG_DIR/$run_debug_label.hosts"
    rm -rf "$run_debug_tmpdir"
}

# --- offline behavior ----------------------------------------------------------

run_debug_offline() {
    setup_direct_fixtures
    run_debug_fixture "debug-direct" "$LOG_DIR/debug-direct.out"

    setup_source_fixtures
    run_debug_fixture "debug-sources" "$LOG_DIR/debug-sources.out"

    setup_direct_fixtures
}

run_system_offline() {
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.pre-smoke"

    log "-- system hosty -i (writes /etc/hosts) --"
    system_output="$LOG_DIR/system-i.out"
    as_root "$HOSTY" -i > "$system_output" 2>&1 || {
        cat "$system_output"
        die "hosty -i failed"
    }
    tail -n 20 "$system_output"
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    assert_mode /etc/hosts 644 "/etc/hosts should be world-readable after -i"

    log "-- system hosty -i again (idempotent rebuild) --"
    system_output="$LOG_DIR/system-i2.out"
    as_root "$HOSTY" -i > "$system_output" 2>&1 || {
        cat "$system_output"
        die "second hosty -i failed"
    }
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    assert_mode /etc/hosts 644 "/etc/hosts should stay 644 after second -i"
    marker_lines=$(grep -cF -e "$MARKER" /etc/hosts || true)
    [ "$marker_lines" -eq 1 ] || die "expected 1 marker line after rebuild, got $marker_lines"

    log "-- system hosty -r --"
    system_output="$LOG_DIR/system-r.out"
    as_root "$HOSTY" -r > "$system_output" 2>&1 || {
        cat "$system_output"
        die "hosty -r failed"
    }
    assert_file_not_contains /etc/hosts "$MARKER"
    assert_file_not_contains /etc/hosts "0.0.0.0 ads.example.test"

    # Empty original hosts section and empty whitelist exercise empty-file dedup.
    log "-- marker on line 1 with empty whitelist --"
    as_root sh -c "printf '%s\n0.0.0.0 pre-existing.example\n' '$MARKER' > /etc/hosts"
    as_root sh -c ': > /etc/hosty/whitelist'
    system_output="$LOG_DIR/system-marker1.out"
    as_root "$HOSTY" -i > "$system_output" 2>&1 || {
        cat "$system_output"
        die "hosty -i with marker on line 1 failed"
    }
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    assert_mode /etc/hosts 644 "/etc/hosts should be 644 after marker-on-line-1 -i"

    as_root "$HOSTY" -r > "$LOG_DIR/system-marker1-restore.out" 2>&1
    assert_file_not_contains /etc/hosts "$MARKER"
    assert_file_not_contains /etc/hosts "0.0.0.0 ads.example.test"

    as_root cp "$LOG_DIR/etc-hosts.pre-smoke" /etc/hosts
    setup_direct_fixtures
}

# --- network ------------------------------------------------------------------

run_debug_network() {
    log "-- hosty -d (default remote sources) --"
    network_output="$LOG_DIR/debug-network.out"
    set +e
    "$HOSTY" -d > "$network_output" 2>&1
    network_rc=$?
    set -e
    tail -n 50 "$network_output" || true
    [ "$network_rc" -eq 0 ] || die "hosty -d failed with exit $network_rc"

    assert_file_contains "$network_output" "downloading default sources"
    network_built=$(awk '/^building / { print $2 }' "$network_output" | tail -n 1)
    [ -n "$network_built" ] && [ -f "$network_built" ] || die "network debug hosts file missing"
    assert_file_contains "$network_built" "$MARKER"

    network_count=$(blocked_count_from "$network_output")
    [ -n "$network_count" ] || die "could not parse network blocked count"
    assert_gt "$network_count" 1000 "expected a large blocklist from defaults"
}

run_system_network() {
    log "-- system hosty (default remote sources) --"
    network_output="$LOG_DIR/system-network.out"
    as_root "$HOSTY" > "$network_output" 2>&1 || {
        tail -n 80 "$network_output"
        die "full hosty run failed"
    }
    assert_file_contains "$network_output" "downloading default sources"
    assert_file_contains /etc/hosts "$MARKER"
    assert_mode /etc/hosts 644 "/etc/hosts should be 644 after network run"

    network_count=$(blocked_count_from "$network_output")
    [ -n "$network_count" ] || die "could not parse full-run blocked count"
    assert_gt "$network_count" 1000 "expected substantial default blocklist"
    as_root "$HOSTY" -r > "$LOG_DIR/system-network-restore.out" 2>&1
}

# --- installer ----------------------------------------------------------------

run_install_tests() {
    log "-- installer tests (HOSTY_URL=workspace hosty.sh) --"
    command -v expect > /dev/null 2>&1 || die "expect is required for installer tests"

    # cronie/BusyBox may need this directory for root crontab writes.
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

    if ! has_terminal; then
        log "install without a controlling terminal"
        as_root env HOSTY_URL="$HOSTY" "$INSTALL" < /dev/null \
            > "$LOG_DIR/install-noninteractive.out" 2>&1 || {
            cat "$LOG_DIR/install-noninteractive.out"
            die "non-interactive install failed"
        }
        assert_installed_workspace "non-interactive install"
        if command -v crontab > /dev/null 2>&1; then
            assert_file_contains "$LOG_DIR/install-noninteractive.out" "no terminal available"
        fi
        as_root rm -f "$DEST_BIN"
    fi

    if [ "$(id -u)" -ne 0 ] && command -v sudo > /dev/null 2>&1; then
        log "install with sudo answering y/daily"
        expect "$ROOT/ci/expect/install-yes.exp" sudo -E env "HOSTY_URL=$HOSTY" "$INSTALL" \
            > "$LOG_DIR/install-sudo-yes.out" 2>&1 || {
            cat "$LOG_DIR/install-sudo-yes.out"
            die "sudo install failed"
        }
    else
        log "install as root answering y/daily"
        expect "$ROOT/ci/expect/install-yes.exp" "$INSTALL" \
            > "$LOG_DIR/install-root-yes.out" 2>&1 || {
            cat "$LOG_DIR/install-root-yes.out"
            die "root install failed"
        }
    fi
    assert_installed_workspace "privileged install"
    assert_autorun_cron "privileged install"
    assert_no_hosty_staging "staging left after privileged install"

    log "-- uninstall --"
    uninstall_hosty "$LOG_DIR/uninstall.out"
    assert_no_hosty_staging "staging left after uninstall"
}

assert_bad_payload_rejected() {
    bad_payload=$1
    bad_payload_label=$2
    bad_payload_output="$LOG_DIR/install-$bad_payload_label.out"

    set +e
    as_root env HOSTY_URL="$bad_payload" "$INSTALL" > "$bad_payload_output" 2>&1
    bad_payload_rc=$?
    set -e

    [ "$bad_payload_rc" -ne 0 ] || {
        cat "$bad_payload_output"
        die "$bad_payload_label payload should fail"
    }
    assert_file_contains "$bad_payload_output" "staged file does not look like a working hosty"
    [ -x "$DEST_BIN" ] || die "good hosty binary was removed after $bad_payload_label payload"
    assert_eq "$("$DEST_BIN" -v)" "$expected_version" \
        "good install must survive $bad_payload_label payload"
    assert_no_hosty_staging "staging left after $bad_payload_label payload"
}

run_install_negative_tests() {
    log "-- installer negative tests --"

    http_output="$LOG_DIR/install-http-reject.out"
    set +e
    as_root env HOSTY_URL="http://example.invalid/hosty.sh" "$INSTALL" > "$http_output" 2>&1
    http_rc=$?
    set -e
    [ "$http_rc" -ne 0 ] || die "http:// HOSTY_URL should fail"
    assert_file_contains "$http_output" "HOSTY_URL must be https://"
    assert_no_hosty_staging "staging left after HTTP rejection"

    as_root cp "$HOSTY" "$DEST_BIN"
    as_root chmod 755 "$DEST_BIN"

    empty_payload=$(mktemp) || die "mktemp failed"
    printf '%s\n' '#!/bin/sh' 'exit 0' > "$empty_payload"
    chmod 755 "$empty_payload"
    assert_bad_payload_rejected "$empty_payload" "empty-version"
    rm -f "$empty_payload"

    unrelated_payload=$(mktemp) || die "mktemp failed"
    cat > "$unrelated_payload" << 'EOF_PAYLOAD'
#!/bin/sh
case $1 in
    -v) printf '%s\n' '1.2.3' ;;
    -h) printf '%s\n' 'unrelated program' ;;
esac
exit 0
EOF_PAYLOAD
    chmod 755 "$unrelated_payload"
    assert_bad_payload_rejected "$unrelated_payload" "unrelated-program"
    rm -f "$unrelated_payload"

    as_root rm -f "$DEST_BIN"
}

run_production_install() {
    log "-- production install smoke (https://4st.li) --"
    command -v expect > /dev/null 2>&1 || die "expect required"
    as_root rm -f "$DEST_BIN"

    expect "$ROOT/ci/expect/install-n.exp" env HOSTY_URL= "$INSTALL" \
        > "$LOG_DIR/install-production.out" 2>&1 || {
        cat "$LOG_DIR/install-production.out"
        die "production install failed"
    }
    [ -x "$DEST_BIN" ] || die "production hosty binary missing"
    assert_no_hosty_staging "staging left after production install"
    as_root "$DEST_BIN" -v > "$LOG_DIR/production-version.out" 2>&1

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

# --- run ----------------------------------------------------------------------

can_as_root || die "this smoke suite needs root, passwordless sudo, or passwordless doas"
trap cleanup 0

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
