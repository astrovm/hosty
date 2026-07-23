#!/bin/sh
# Preserve local Hosty state while running the destructive smoke-test core.
set -eu

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
CORE="$ROOT/ci/smoke-core"
DEST_BIN=/usr/local/bin/hosty
STATE_DIR=""
SYSTEM_STATE_SAVED=0
HOSTY_CONFIG_PRESENT=0
HOSTY_BINARY_PRESENT=0
ROOT_CRONTAB_PRESENT=0
CRON_SPOOL_DIR_PRESENT=0
CRON_SPOOL_PARENT_PRESENT=0

snapshot_system_state() {
    for snapshot_staging_file in /usr/local/bin/.hosty.*; do
        if [ -f "$snapshot_staging_file" ] || [ -L "$snapshot_staging_file" ]; then
            die "remove existing staging file before running smoke: $snapshot_staging_file"
        fi
    done

    as_root cp /etc/hosts "$STATE_DIR/etc-hosts" ||
        die "could not back up /etc/hosts"

    if [ -d /etc/hosty ] || [ -L /etc/hosty ]; then
        as_root cp -PRp /etc/hosty "$STATE_DIR/hosty-config" ||
            die "could not back up /etc/hosty"
        HOSTY_CONFIG_PRESENT=1
    fi

    if [ -f "$DEST_BIN" ] || [ -L "$DEST_BIN" ]; then
        as_root cp -Pp "$DEST_BIN" "$STATE_DIR/hosty-bin" ||
            die "could not back up $DEST_BIN"
        HOSTY_BINARY_PRESENT=1
    fi

    if command -v crontab > /dev/null 2>&1 &&
        as_root crontab -l > "$STATE_DIR/root-crontab" 2> /dev/null; then
        ROOT_CRONTAB_PRESENT=1
    fi

    if [ -d /var/spool/cron ]; then
        CRON_SPOOL_PARENT_PRESENT=1
    fi
    if [ -d /var/spool/cron/crontabs ]; then
        CRON_SPOOL_DIR_PRESENT=1
    fi

    SYSTEM_STATE_SAVED=1
}

cleanup() {
    cleanup_status=$?
    cleanup_failed=0
    trap - 0 INT TERM

    if [ "$SYSTEM_STATE_SAVED" -eq 1 ]; then
        if ! as_root cp "$STATE_DIR/etc-hosts" /etc/hosts 2> /dev/null; then
            cleanup_failed=1
        fi

        if ! as_root rm -rf /etc/hosty 2> /dev/null; then
            cleanup_failed=1
        fi
        if [ "$HOSTY_CONFIG_PRESENT" -eq 1 ] &&
            ! as_root cp -PRp "$STATE_DIR/hosty-config" /etc/hosty 2> /dev/null; then
            cleanup_failed=1
        fi

        if ! as_root rm -f "$DEST_BIN" 2> /dev/null; then
            cleanup_failed=1
        fi
        if [ "$HOSTY_BINARY_PRESENT" -eq 1 ] &&
            ! as_root cp -Pp "$STATE_DIR/hosty-bin" "$DEST_BIN" 2> /dev/null; then
            cleanup_failed=1
        fi

        if command -v crontab > /dev/null 2>&1; then
            if [ "$ROOT_CRONTAB_PRESENT" -eq 1 ]; then
                if ! as_root crontab "$STATE_DIR/root-crontab" 2> /dev/null; then
                    cleanup_failed=1
                fi
            else
                as_root crontab -r 2> /dev/null || true
            fi
        fi

        if [ "$CRON_SPOOL_DIR_PRESENT" -eq 0 ] &&
            [ -d /var/spool/cron/crontabs ] &&
            ! as_root rmdir /var/spool/cron/crontabs 2> /dev/null; then
            cleanup_failed=1
        fi
        if [ "$CRON_SPOOL_PARENT_PRESENT" -eq 0 ] &&
            [ -d /var/spool/cron ] &&
            ! as_root rmdir /var/spool/cron 2> /dev/null; then
            cleanup_failed=1
        fi

        as_root rm -f /usr/local/bin/.hosty.* 2> /dev/null || true
    fi

    if [ -n "$STATE_DIR" ]; then
        as_root rm -rf "$STATE_DIR" 2> /dev/null || cleanup_failed=1
    fi

    if [ "$cleanup_failed" -ne 0 ]; then
        printf 'ERROR: failed to restore the pre-smoke system state.\n' >&2
        [ "$cleanup_status" -ne 0 ] || cleanup_status=1
    fi

    exit "$cleanup_status"
}

can_as_root || die "this smoke suite needs root, passwordless sudo, or passwordless doas"
[ -f "$CORE" ] || die "smoke core is missing: $CORE"

STATE_DIR=$(mktemp -d) || die "mktemp -d failed"
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
snapshot_system_state

sh "$CORE" "$@"
