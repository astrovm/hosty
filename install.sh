#!/bin/sh

set -euf

HOSTY_URL=${HOSTY_URL:-https://4st.li/hosty/hosty.sh}
DEST_DIR=/usr/local/bin
DEST="$DEST_DIR/hosty"
PRIVILEGE_TOOL=""
DOWNLOAD_TMP=""
STAGED_TMP=""

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

check_dep() {
    command -v "$1" > /dev/null 2>&1 || fail "installer requires '$1', but it is not installed."
}

is_yes() {
    case $1 in
        y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}

is_no() {
    case $1 in
        n | N | no | NO) return 0 ;;
        *) return 1 ;;
    esac
}

run_privileged() {
    if [ -n "$PRIVILEGE_TOOL" ]; then
        "$PRIVILEGE_TOOL" "$@"
    else
        "$@"
    fi
}

cleanup() {
    if [ -n "$DOWNLOAD_TMP" ]; then
        rm -f "$DOWNLOAD_TMP"
    fi
    if [ -n "$STAGED_TMP" ]; then
        run_privileged rm -f "$STAGED_TMP" 2> /dev/null || true
    fi
}

check_dep curl
check_dep mktemp

printf '======== welcome to hosty installer ========\n'
printf '========        4st.li/hosty        ========\n\n'

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo > /dev/null 2>&1; then
        PRIVILEGE_TOOL=sudo
    elif command -v doas > /dev/null 2>&1; then
        PRIVILEGE_TOOL=doas
    else
        fail "run this installer as root, or install and configure sudo or doas."
    fi
    printf 'using %s for privileged operations.\n' "$PRIVILEGE_TOOL"
else
    printf 'running as root.\n'
fi

DOWNLOAD_TMP=$(mktemp) || exit 1
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

printf '\ndownloading hosty...\n'
case $HOSTY_URL in
    https://* | file://*)
        curl -fsSL --retry 3 -o "$DOWNLOAD_TMP" "$HOSTY_URL"
        ;;
    *://*)
        fail "HOSTY_URL must be https://, file://, or a local path."
        ;;
    *)
        cp "$HOSTY_URL" "$DOWNLOAD_TMP"
        ;;
esac

chmod 755 "$DOWNLOAD_TMP"
if ! version=$("$DOWNLOAD_TMP" -v 2> /dev/null); then
    fail "staged file does not look like a working hosty binary."
fi

printf '\ninstalling hosty...\n'
run_privileged mkdir -p "$DEST_DIR"
STAGED_TMP=$(run_privileged mktemp "$DEST_DIR/.hosty.XXXXXX") || exit 1
run_privileged cp "$DOWNLOAD_TMP" "$STAGED_TMP"
run_privileged chmod 755 "$STAGED_TMP"
run_privileged mv -f "$STAGED_TMP" "$DEST"
STAGED_TMP=""

printf 'installed hosty v%s\n\n' "$version"

if command -v crontab > /dev/null 2>&1; then
    if [ -r /dev/tty ]; then
        printf 'configure automatic hosts-file updates now? y/n\n'
        IFS= read -r answer < /dev/tty || fail "failed to read input."
        printf '\n'

        if is_yes "$answer"; then
            run_privileged "$DEST" -a < /dev/tty
        elif ! is_no "$answer"; then
            fail "bad answer."
        fi
    else
        printf 'no terminal available; run hosty -a as root to configure automatic updates.\n'
    fi
fi

trap - 0 INT TERM
rm -f "$DOWNLOAD_TMP"
DOWNLOAD_TMP=""
printf 'done.\n'
