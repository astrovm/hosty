#!/bin/sh
# Offline-first functional smoke tests for hosty (intended for PR CI).
# Set RUN_NETWORK=1 to also exercise the default remote sources path.
# Set RUN_PRODUCTION_INSTALL=1 to install from https://4st.li (schedule/main).
set -euf

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

mkdir -p "$LOG_DIR"
export HOSTY_CI_LOG_DIR="$LOG_DIR"

log "== hosty CI smoke (network=$RUN_NETWORK production_install=$RUN_PRODUCTION_INSTALL) =="
log "repo: $ROOT"
log "logs: $LOG_DIR"

[ -x "$HOSTY" ] || chmod +x "$HOSTY"
[ -x "$INSTALL" ] || chmod +x "$INSTALL"
chmod +x "$ROOT/ci/expect/"*.exp 2> /dev/null || true

# --- CLI asserts -------------------------------------------------------------
log "-- help / version --"
help_out=$("$HOSTY" -h 2>&1) || true
assert_contains "$help_out" "usage: hosty" "help should show usage"
assert_contains "$help_out" "--debug" "help should list --debug"

version_out=$("$HOSTY" -v 2>&1)
expected_version=$(awk -F\" '/^VERSION=/ {print $2; exit}' "$HOSTY")
assert_eq "$version_out" "$expected_version" "version should match VERSION in hosty.sh"

# POSIX shell execution (when dash is available)
if command -v dash > /dev/null 2>&1; then
    log "-- dash -n + dash help/version --"
    dash -n "$HOSTY"
    dash -n "$INSTALL"
    dash "$HOSTY" -h > /dev/null
    dash_ver=$(dash "$HOSTY" -v)
    assert_eq "$dash_ver" "$expected_version" "dash hosty -v should match"
else
    log "-- dash not installed; skipping POSIX shell runtime checks --"
fi

# sh -n syntax
log "-- sh -n --"
sh -n "$HOSTY"
sh -n "$INSTALL"

setup_fixtures() {
    log "-- installing offline fixtures into /etc/hosty --"
    as_root mkdir -p /etc/hosty
    as_root cp "$FIXTURE_BLACKLIST" /etc/hosty/blacklist
    as_root cp "$FIXTURE_WHITELIST" /etc/hosty/whitelist
    # Ensure we do not pull remote custom sources accidentally
    as_root rm -f /etc/hosty/blacklist.sources /etc/hosty/whitelist.sources
}

teardown_fixtures() {
    as_root rm -rf /etc/hosty 2> /dev/null || true
}

run_debug_offline() {
    log "-- hosty -di (offline fixtures) --"
    out="$LOG_DIR/debug-di.out"
    # Debug mode does not need root
    set +e
    "$HOSTY" -di > "$out" 2>&1
    rc=$?
    set -e
    cat "$out"
    [ "$rc" -eq 0 ] || die "hosty -di failed with exit $rc"

    assert_file_contains "$out" "DEBUG MODE ON"
    assert_file_contains "$out" "building "
    built=$(awk '/^building / {print $2}' "$out" | tail -n 1)
    [ -n "$built" ] || die "could not parse debug hosts path from output"
    [ -f "$built" ] || die "debug hosts file missing: $built"
    cp "$built" "$LOG_DIR/debug-di.hosts"

    assert_file_contains "$built" "$MARKER"
    assert_file_contains "$built" "0.0.0.0 ads.example.test"
    assert_file_contains "$built" "0.0.0.0 malware.example.test"
    # whitelisted tracker must not appear as a block entry
    if grep -qE '^0\.0\.0\.0[[:space:]]+tracker\.example\.test$' "$built"; then
        die "whitelisted domain tracker.example.test was blocked"
    fi

    count=$(awk '/^done, / {
      for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit }
    }' "$out")
    [ -n "$count" ] || die "could not parse blocked count from: $(grep '^done,' "$out" || true)"
    assert_gt "$count" 0 "expected at least one blocked domain, got '$count'"
    log "offline debug blocked count: $count"
}

run_debug_network() {
    log "-- hosty -d (default remote sources) --"
    out="$LOG_DIR/debug-d.out"
    set +e
    "$HOSTY" -d > "$out" 2>&1
    rc=$?
    set -e
    # Keep log even on failure; print tail for Actions UI
    tail -n 50 "$out" || true
    [ "$rc" -eq 0 ] || die "hosty -d failed with exit $rc"

    assert_file_contains "$out" "DEBUG MODE ON"
    built=$(awk '/^building / {print $2}' "$out" | tail -n 1)
    [ -n "$built" ] && [ -f "$built" ] || die "debug hosts file missing after -d"
    cp "$built" "$LOG_DIR/debug-d.hosts"
    assert_file_contains "$built" "$MARKER"
    assert_file_contains "$built" "0.0.0.0 "
    count=$(awk '/^done, / {
      for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit }
    }' "$out")
    [ -n "$count" ] || die "could not parse blocked count from network debug run"
    assert_gt "$count" 100 "expected a substantial blocklist from defaults, got '$count'"
    log "network debug blocked count: $count"
}

run_system_offline() {
    log "-- system hosty -i (offline fixtures, writes /etc/hosts) --"
    can_as_root || die "root/passwordless sudo required for system tests"
    out="$LOG_DIR/system-i.out"
    as_root "$HOSTY" -i > "$out" 2>&1 || {
        cat "$out"
        die "hosty -i failed"
    }
    tail -n 20 "$out"
    assert_file_contains /etc/hosts "$MARKER"
    assert_file_contains /etc/hosts "0.0.0.0 ads.example.test"
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.after-i"

    log "-- system hosty -r (restore) --"
    out="$LOG_DIR/system-r.out"
    as_root "$HOSTY" -r > "$out" 2>&1 || {
        cat "$out"
        die "hosty -r failed"
    }
    cat "$out"
    assert_file_not_contains /etc/hosts "$MARKER"
    assert_file_not_contains /etc/hosts "0.0.0.0 ads.example.test"
}

run_system_network() {
    log "-- system hosty (default remote sources) --"
    can_as_root || die "root/passwordless sudo required for system tests"
    out="$LOG_DIR/system-full.out"
    as_root "$HOSTY" > "$out" 2>&1 || {
        tail -n 80 "$out"
        die "full hosty run failed"
    }
    tail -n 20 "$out"
    assert_file_contains /etc/hosts "$MARKER"
    count=$(awk '/^done, / {
      for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit }
    }' "$out")
    [ -n "$count" ] || die "could not parse blocked count from full run"
    assert_gt "$count" 100 "expected substantial blocklist, got '$count'"
    as_root cp /etc/hosts "$LOG_DIR/etc-hosts.after-full"
    as_root "$HOSTY" -r > "$LOG_DIR/system-full-restore.out" 2>&1
}

run_install_tests() {
    log "-- installer tests (HOSTY_URL=workspace hosty.sh) --"
    can_as_root || die "root/passwordless sudo required for install tests"
    command -v expect > /dev/null 2>&1 || die "expect is required for installer tests"

    export HOSTY_URL="$HOSTY"

    # Clean slate for install target
    as_root rm -f /usr/local/bin/hosty

    log "install answering n"
    expect "$ROOT/ci/expect/install-n.exp" "$INSTALL" > "$LOG_DIR/install-n.out" 2>&1 || {
        cat "$LOG_DIR/install-n.out"
        die "install-n failed"
    }
    [ -x /usr/local/bin/hosty ] || die "hosty binary missing after install-n"
    # Ensure it is the workspace copy (version match)
    installed_ver=$(/usr/local/bin/hosty -v)
    assert_eq "$installed_ver" "$expected_version" "installed binary should be workspace version"

    as_root rm -f /usr/local/bin/hosty

    log "install via cat | sh answering y/daily"
    # expect scripts tolerate missing autorun prompts when crontab is absent
    expect "$ROOT/ci/expect/install-yes.exp" sh -c "cat '$INSTALL' | sh" \
        > "$LOG_DIR/install-cat-yes.out" 2>&1 || {
        cat "$LOG_DIR/install-cat-yes.out"
        die "install via cat | sh failed"
    }
    [ -x /usr/local/bin/hosty ] || die "hosty binary missing after cat|sh install"

    as_root rm -f /usr/local/bin/hosty

    if [ "$(id -u)" -ne 0 ] && command -v sudo > /dev/null 2>&1; then
        log "install with sudo answering y/daily"
        expect "$ROOT/ci/expect/install-yes.exp" sudo -E env "HOSTY_URL=$HOSTY" "$INSTALL" \
            > "$LOG_DIR/install-sudo-yes.out" 2>&1 || {
            cat "$LOG_DIR/install-sudo-yes.out"
            die "sudo install failed"
        }
        [ -x /usr/local/bin/hosty ] || die "hosty binary missing after sudo install"
    else
        log "install as root answering y/daily"
        expect "$ROOT/ci/expect/install-yes.exp" "$INSTALL" \
            > "$LOG_DIR/install-root-yes.out" 2>&1 || {
            cat "$LOG_DIR/install-root-yes.out"
            die "root install failed"
        }
        [ -x /usr/local/bin/hosty ] || die "hosty binary missing after root install"
    fi

    log "-- uninstall --"
    # Uninstall may prompt about /etc/hosty; answer n via pipe when configs exist
    if [ -d /etc/hosty ]; then
        printf 'n\n' | as_root /usr/local/bin/hosty -u > "$LOG_DIR/uninstall.out" 2>&1 || {
            cat "$LOG_DIR/uninstall.out"
            die "hosty -u failed"
        }
    else
        as_root /usr/local/bin/hosty -u > "$LOG_DIR/uninstall.out" 2>&1 || {
            cat "$LOG_DIR/uninstall.out"
            die "hosty -u failed"
        }
    fi
    assert_file_contains "$LOG_DIR/uninstall.out" "hosty uninstalled"
    [ ! -f /usr/local/bin/hosty ] || die "hosty binary still present after uninstall"
}

run_production_install() {
    log "-- production install smoke (https://4st.li) --"
    can_as_root || die "root required"
    command -v expect > /dev/null 2>&1 || die "expect required"
    as_root rm -f /usr/local/bin/hosty
    # Empty HOSTY_URL falls back to the production URL inside install.sh
    expect "$ROOT/ci/expect/install-n.exp" env HOSTY_URL= "$INSTALL" \
        > "$LOG_DIR/install-production.out" 2>&1 || {
        cat "$LOG_DIR/install-production.out"
        die "production install failed"
    }
    [ -x /usr/local/bin/hosty ] || die "production hosty binary missing"
    as_root /usr/local/bin/hosty -v > "$LOG_DIR/production-version.out" 2>&1
    cat "$LOG_DIR/production-version.out"
    # Leave system clean
    if [ -d /etc/hosty ]; then
        printf 'y\n' | as_root /usr/local/bin/hosty -u > "$LOG_DIR/production-uninstall.out" 2>&1 || true
    else
        as_root /usr/local/bin/hosty -u > "$LOG_DIR/production-uninstall.out" 2>&1 || true
    fi
}

# --- run ---------------------------------------------------------------------
if can_as_root; then
    setup_fixtures
else
    die "this smoke suite requires root or passwordless sudo (GitHub Actions runners provide it)"
fi

run_debug_offline
run_system_offline
run_install_tests

if [ "$RUN_NETWORK" = 1 ]; then
    # Fixtures still present; full default run should merge remote lists
    run_debug_network
    run_system_network
fi

if [ "$RUN_PRODUCTION_INSTALL" = 1 ]; then
    run_production_install
fi

teardown_fixtures

log
log "OK: all smoke checks passed"
