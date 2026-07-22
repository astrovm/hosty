#!/bin/sh

set -euf

# check dependences
checkDep() {
    command -v "$1" > /dev/null 2>&1 || {
        echo >&2 "hosty requires '$1' but it's not installed."
        exit 1
    }
}

checkDep curl

echo "======== welcome to hosty installer ========"
echo "========        4st.li/hosty        ========"
echo
echo "checking if user has root access..."

if [ "$(id -u)" != 0 ]; then
    echo
    if ! prompt=$(sudo -nv 2>&1); then
        if ! echo "$prompt" | grep -q '^sudo:'; then
            echo "you don't have sudo access, please fix that or run from root."
            exit 1
        fi

        echo "requesting sudo..."
    else
        echo "using already granted sudo access..."
    fi

    request_sudo=1
else
    request_sudo=0
    echo "OK"
fi

echo
if [ -f /usr/local/bin/hosty ]; then
    echo "removing existing hosty..."
    if [ "$request_sudo" = 1 ]; then
        sudo rm /usr/local/bin/hosty
    else
        rm /usr/local/bin/hosty
    fi
    echo
fi

# HOSTY_URL: https URL, file:// URL, or local path (CI uses the workspace copy).
# http:// is rejected — install is privileged and the source must be trusted.
hosty_url="${HOSTY_URL:-https://4st.li/hosty/hosty.sh}"
dest=/usr/local/bin/hosty

run_priv() {
    if [ "$request_sudo" = 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

echo "installing hosty..."
case "$hosty_url" in
    http://*)
        echo "HOSTY_URL must be https://, file://, or a local path (got http://)." >&2
        exit 1
        ;;
    https://* | file://*)
        run_priv curl -fL --retry 3 -o "$dest" "$hosty_url"
        ;;
    *)
        run_priv cp "$hosty_url" "$dest"
        ;;
esac
echo

echo "fixing permissions..."
run_priv chmod 755 "$dest"
echo

if command -v "crontab" > /dev/null 2>&1; then
    echo "do you want to automatically update your hosts file with the latest ads list? (recommended) y/n"
    read -r answer < /dev/tty
    echo

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
        if [ "$request_sudo" = 1 ]; then
            # shellcheck disable=SC2024
            sudo /usr/local/bin/hosty -a < /dev/tty
        else
            /usr/local/bin/hosty -a < /dev/tty
        fi
        exit 0
    elif [ "$answer" != "n" ] && [ "$answer" != "N" ] && [ "$answer" != "no" ] && [ "$answer" != "NO" ]; then
        echo "bad answer, exiting..."
        exit 1
    fi
fi

echo "done."
