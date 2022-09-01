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

# start script
echo "======== welcome to hosty installer ========"
echo "========    astrolince.com/hosty    ========"
echo

# check root
echo "checking if user has root access..."
echo

if [ "$(id -u)" != 0 ]; then
    echo "you don't have root access, run the installer with sudo or from root."
    exit 1
fi

if [ -f /usr/local/bin/hosty ]; then
    echo "removing existing hosty..."
    rm /usr/local/bin/hosty
    echo
fi

echo "do you want to always run the latest version of hosty? (recommended) y/n"
read -r answer </dev/tty
echo

# check user answer
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

echo "do you want to automatically update your hosts file with latest ads list? (recommended) y/n"
read -r answer </dev/tty
echo

# check user answer
if [ "$answer" = "y" ]; then
    /usr/local/bin/hosty --autorun </dev/tty
    exit 0
elif [ "$answer" != "n" ]; then
    echo "bad answer, exiting..."
    exit 1
fi

echo "done."
