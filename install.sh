#!/bin/bash

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
	exit 0
fi

if [ -f /usr/local/bin/hosty ]; then
    echo "Removing existing hosty..."
    sudo rm /usr/local/bin/hosty
    echo
fi

echo "Installing hosty..."
sudo wget -c https://github.com/astrolince/hosty/raw/master/hosty -O /usr/local/bin/hosty

echo "Fixing permissions..."
sudo chmod 755 /usr/local/bin/hosty
echo

echo "Done."
