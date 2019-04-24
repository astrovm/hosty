#!/bin/bash

echo "======== Welcome to hosty installer ========"
echo "========    astrolince.com/hosty    ========"
echo

command -v sudo >/dev/null 2>&1 || { echo >&2 "The installer requires 'sudo' but it's not installed."; exit 1; }
command -v grep >/dev/null 2>&1 || { echo >&2 "The installer requires 'grep' but it's not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "The installer requires 'curl' but it's not installed."; exit 1; }
command -v chmod >/dev/null 2>&1 || { echo >&2 "The installer requires 'chmod' but it's not installed."; exit 1; }

# Checking sudo
echo "Checking if user has sudo access..."

prompt=$(sudo -nv 2>&1)

if [ $? -eq 0 ]; then
	echo "OK"
	echo
elif echo $prompt | grep -q '^sudo:'; then
	echo
	echo "Requesting sudo..."
	sudo -v
	echo
else
	echo
	echo "You don't have sudo access, please fix that or run it from root."
	exit 1
fi

if [ -f /usr/local/bin/hosty ]; then
    echo "Removing existing hosty..."
    sudo rm /usr/local/bin/hosty
    echo
fi

echo "Installing hosty..."
sudo curl -L -o /usr/local/bin/hosty https://github.com/astrolince/hosty/raw/master/hosty
echo

echo "Fixing permissions..."
sudo chmod 755 /usr/local/bin/hosty
echo

echo "Checking dependencies..."
command -v wget >/dev/null 2>&1 || { echo >&2 "Hosty requires 'wget' but it's not installed."; }
command -v awk >/dev/null 2>&1 || { echo >&2 "Hosty requires 'awk' but it's not installed."; }
command -v sed >/dev/null 2>&1 || { echo >&2 "Hosty requires 'sed' but it's not installed."; }
command -v head >/dev/null 2>&1 || { echo >&2 "Hosty requires 'head' but it's not installed."; }
command -v cat >/dev/null 2>&1 || { echo >&2 "Hosty requires 'cat' but it's not installed."; }
command -v zcat >/dev/null 2>&1 || { echo >&2 "Hosty can require 'zcat' but it's not installed."; }
command -v 7z >/dev/null 2>&1 || { echo >&2 "Hosty can require '7z' but it's not installed."; }
echo

echo "Done."
