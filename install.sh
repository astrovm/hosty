#!/bin/sh

set -euf

# check dependences
checkDep() {
    command -v "$1" >/dev/null 2>&1 || {
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

    REQUEST_SUDO=1
else
    REQUEST_SUDO=0
    echo "OK"
fi

echo
if [ -f /usr/local/bin/hosty ]; then
    echo "removing existing hosty..."
    if [ "$REQUEST_SUDO" = 1 ]; then
        sudo rm /usr/local/bin/hosty
    else
        rm /usr/local/bin/hosty
    fi
    echo
fi

echo "installing hosty..."
if [ "$REQUEST_SUDO" = 1 ]; then
    sudo curl -L --retry 3 -o /usr/local/bin/hosty https://4st.li/hosty/hosty.sh
else
    curl -L --retry 3 -o /usr/local/bin/hosty https://4st.li/hosty/hosty.sh
fi
echo

echo "fixing permissions..."
if [ "$REQUEST_SUDO" = 1 ]; then
    sudo chmod 755 /usr/local/bin/hosty
else
    chmod 755 /usr/local/bin/hosty
fi
echo

if command -v "crontab" >/dev/null 2>&1; then
    echo "do you want to automatically update your hosts file with the latest ads list? (recommended) y/n"
    read -r answer </dev/tty
    echo

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
        if [ "$REQUEST_SUDO" = 1 ]; then
            # shellcheck disable=SC2024
            sudo /usr/local/bin/hosty -a </dev/tty
        else
            /usr/local/bin/hosty -a </dev/tty
        fi
        exit 0
    elif [ "$answer" != "n" ] && [ "$answer" != "N" ] && [ "$answer" != "no" ] && [ "$answer" != "NO" ]; then
        echo "bad answer, exiting..."
        exit 1
    fi
fi

echo "done."
