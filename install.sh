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

# define main function
mainHosty() {
    if [ -f /usr/local/bin/hosty ]; then
        echo "removing existing hosty..."
        rm /usr/local/bin/hosty
        echo
    fi

    echo "do you want to always run the latest version of hosty? (recommended) y/n"
    read -r answer </dev/tty
    echo

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
        echo "installing hosty..."
        curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/updater.sh
        echo
    elif [ "$answer" = "n" ] || [ "$answer" = "N" ] || [ "$answer" = "no" ] || [ "$answer" = "NO" ]; then
        echo "installing hosty..."
        curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
        echo
    else
        echo "bad answer, exiting..."
        exit 1
    fi

    echo "fixing permissions..."
    chmod 755 /usr/local/bin/hosty
    echo

    if command -v "crontab" >/dev/null 2>&1; then
        echo "do you want to automatically update your hosts file with the latest ads list? (recommended) y/n"
        read -r answer </dev/tty
        echo

        # check user answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
            /usr/local/bin/hosty -a </dev/tty
            exit 0
        elif [ "$answer" != "n" ] && [ "$answer" != "N" ] && [ "$answer" != "no" ] && [ "$answer" != "NO" ]; then
            echo "bad answer, exiting..."
            exit 1
        fi
    fi

    echo "done."
}

echo "======== welcome to hosty installer ========"
echo "========    astrolince.com/hosty    ========"
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

    mainHosty sudo
    exit 0
fi

echo "OK"
mainHosty
