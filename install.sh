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

    REQUEST_SUDO=1
else
    REQUEST_SUDO=0
    echo "OK"
fi

echo
if [ -f /usr/local/bin/hosty ]; then
    echo "removing existing hosty..."
    if [ "$REQUEST_SUDO" ]; then
        sudo rm /usr/local/bin/hosty
    else
        rm /usr/local/bin/hosty
    fi
    echo
fi

echo "do you want to always run the latest version of hosty? (recommended) y/n"
read -r answer </dev/tty
echo

if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
    echo "installing hosty..."
    if [ "$REQUEST_SUDO" ]; then
        sudo curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/updater.sh
    else
        curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/updater.sh
    fi
    echo
elif [ "$answer" = "n" ] || [ "$answer" = "N" ] || [ "$answer" = "no" ] || [ "$answer" = "NO" ]; then
    echo "installing hosty..."
    if [ "$REQUEST_SUDO" ]; then
        sudo curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
    else
        curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
    fi
    echo
else
    echo "bad answer, exiting..."
    exit 1
fi

echo "fixing permissions..."
if [ "$REQUEST_SUDO" ]; then
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
        if [ "$REQUEST_SUDO" ]; then
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
