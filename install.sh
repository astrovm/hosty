#!/bin/sh

echo

# Check dependences
command -v grep >/dev/null 2>&1 || { echo >&2 "Hosty requires 'grep' but it's not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "Hosty requires 'curl' but it's not installed."; exit 1; }
command -v chmod >/dev/null 2>&1 || { echo >&2 "Hosty requires 'chmod' but it's not installed."; exit 1; }
command -v bash >/dev/null 2>&1 || { echo >&2 "Hosty requires 'bash' but it's not installed."; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo >&2 "Hosty requires 'gpg' but it's not installed."; exit 1; }
command -v awk >/dev/null 2>&1 || { echo >&2 "Hosty requires 'awk' but it's not installed."; exit 1; }
command -v head >/dev/null 2>&1 || { echo >&2 "Hosty requires 'head' but it's not installed."; exit 1; }
command -v cat >/dev/null 2>&1 || { echo >&2 "Hosty requires 'cat' but it's not installed."; exit 1; }
command -v crontab >/dev/null 2>&1 || { echo >&2 "Hosty requires 'crontab' but it's not installed."; exit 1; }

# Define main function
MainHosty () {
    echo
    
    if [ -f /usr/local/bin/hosty ]; then
        echo "Removing existing hosty..."
        rm /usr/local/bin/hosty
        echo
    fi
    
    echo "Do you want to always run the latest version of hosty? (recommended) y/n"
    read answer < /dev/tty
    echo
    
    # Check user answer
    if [ "$answer" = "y" ]; then
        echo "Installing hosty..."
        curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/updater.sh
        echo
    elif [ "$answer" = "n" ]; then
        echo "Installing hosty..."
        curl -L -o /usr/local/bin/hosty https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
        echo
    else
        echo "Bad answer, exiting..."
        exit 1
    fi
    
    echo "Fixing permissions..."
    chmod 755 /usr/local/bin/hosty
    echo
    
    echo "Checking optional dependencies..."
    command -v zcat >/dev/null 2>&1 || { echo >&2 "Hosty can require 'zcat' if you want to use custom .zip sources, but it's not installed."; }
    command -v 7z >/dev/null 2>&1 || { echo >&2 "Hosty can require '7z' if you want to use custom .7z sources, but it's not installed."; }
    echo
    
    echo "Do you want to automatically update your hosts file with latest ads list? (recommended) y/n"
    read answer < /dev/tty
    echo
    
    # Check user answer
    if [ "$answer" = "y" ]; then
        /usr/local/bin/hosty --autorun < /dev/tty
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

if [ "$EUID" -ne 0 ]; then
    prompt=$(sudo -nv 2>&1)
    if [ $? -eq 0 ]; then
        echo "OK"
    elif echo $prompt | grep -q '^sudo:'; then
        echo
        echo "Requesting sudo..."
    else
        echo
        echo "You don't have sudo access, please fix that or run it from root."
        exit 1
    fi
    
    DECL=$(declare -f MainHosty)
    sudo bash -c "$DECL; MainHosty"
    exit 0
fi

echo "OK"
MainHosty
