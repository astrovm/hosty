#!/bin/sh

echo

# Check dependences
CheckDep() {
    command -v "$1" >/dev/null 2>&1 || {
        echo >&2 "Hosty requires '$1' but it's not installed."
        exit 1
    }
}

CheckDep curl

# Define main function
MainHosty() {
    echo

    if [ -f /usr/local/bin/hosty ]; then
        echo "Removing existing hosty..."
        $1 rm /usr/local/bin/hosty
        echo
    fi

    echo "Do you want to always run the latest version of hosty? (recommended) y/n"
    read -r answer </dev/tty
    echo

    # Check user answer
    if [ "$answer" = "y" ]; then
        echo "Installing hosty..."
        $1 curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/updater.sh
        echo
    elif [ "$answer" = "n" ]; then
        echo "Installing hosty..."
        $1 curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
        echo
    else
        echo "Bad answer, exiting..."
        exit 1
    fi

    echo "Fixing permissions..."
    $1 chmod 755 /usr/local/bin/hosty
    echo

    echo "Do you want to automatically update your hosts file with latest ads list? (recommended) y/n"
    read -r answer </dev/tty
    echo

    # Check user answer
    if [ "$answer" = "y" ]; then
        $1 /usr/local/bin/hosty --autorun </dev/tty
        exit 0
    elif [ "$answer" != "n" ]; then
        echo "Bad answer, exiting..."
        exit 1
    fi

    echo "Done."
}

# Start script
echo "======== Welcome to hosty installer ========"
echo "========    astrolince.com/hosty    ========"
echo

# Check root and exec main function as it
echo "Checking if user has root access..."

if [ "$(id -u)" != 0 ]; then
    echo

    if ! prompt=$(sudo -nv 2>&1); then
        if ! echo "$prompt" | grep -q '^sudo:'; then
            echo "You don't have sudo access, please fix that or run it from root."
            exit 1
        fi

        echo "Requesting sudo..."
    else
        echo "Using already granted sudo access..."
    fi

    MainHosty sudo
    exit 0
fi

echo "OK"
MainHosty
