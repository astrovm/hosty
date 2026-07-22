#!/bin/sh

set -euf

# check dependencies
checkDep() {
    command -v "$1" > /dev/null 2>&1 || {
        echo >&2 "installer requires '$1' but it's not installed."
        exit 1
    }
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

checkDep curl

echo "======== welcome to hosty installer ========"
echo "========        4st.li/hosty        ========"
echo
echo "checking if user has root access..."

# HOSTY_URL: https URL, file:// URL, or local path (CI uses the workspace copy).
# http:// is rejected — install is privileged and the source must be trusted.
hosty_url="${HOSTY_URL:-https://4st.li/hosty/hosty.sh}"
dest_dir=/usr/local/bin
dest="$dest_dir/hosty"

if [ "$(id -u)" != 0 ]; then
    echo
    if ! command -v sudo > /dev/null 2>&1; then
        echo "you don't have sudo access, please fix that or run from root."
        exit 1
    fi

    if sudo -n true 2> /dev/null; then
        echo "using already granted sudo access..."
    else
        echo "requesting sudo..."
        sudo -v
    fi

    request_sudo=1
else
    request_sudo=0
    echo "OK"
fi

run_priv() {
    if [ "$request_sudo" = 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

echo
echo "installing hosty..."

case "$hosty_url" in
    http://*)
        echo "HOSTY_URL must be https://, file://, or a local path (got http://)." >&2
        exit 1
        ;;
esac

# Stage into the destination directory, then mv into place so a failed
# download never leaves a missing or truncated /usr/local/bin/hosty.
run_priv mkdir -p "$dest_dir"
tmp=$(run_priv mktemp "$dest_dir/.hosty.XXXXXX")

cleanup_tmp() {
    run_priv rm -f "$tmp" 2> /dev/null || true
}

trap cleanup_tmp EXIT INT TERM

case "$hosty_url" in
    https://* | file://*)
        run_priv curl -fL --retry 3 -o "$tmp" "$hosty_url"
        ;;
    *)
        run_priv cp "$hosty_url" "$tmp"
        ;;
esac

echo
echo "fixing permissions..."
run_priv chmod 755 "$tmp"
run_priv mv -f "$tmp" "$dest"
trap - EXIT INT TERM

echo
if ! version=$("$dest" -v 2> /dev/null); then
    echo "installed file does not look like a working hosty binary." >&2
    exit 1
fi
echo "installed hosty v$version"
echo

if command -v crontab > /dev/null 2>&1; then
    echo "do you want to automatically update your hosts file with the latest ads list? (recommended) y/n"
    read -r answer < /dev/tty
    echo

    if is_yes "$answer"; then
        # Redirect applies to the privileged hosty process (needs a TTY under curl|sh).
        # shellcheck disable=SC2024
        run_priv "$dest" -a < /dev/tty
    elif ! is_no "$answer"; then
        echo "bad answer, exiting..."
        exit 1
    fi
fi

echo "done."
