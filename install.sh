#!/bin/bash

if [ -f /usr/local/bin/hosty ]; then
    echo "Removing existing hosty..."
    sudo rm /usr/local/bin/hosty
    echo
fi

echo "Installing hosty..."
sudo wget -c https://github.com/astrolince/hosty/raw/master/hosty -O /usr/local/bin/hosty
echo

echo "Fixing permissions..."
sudo chmod 755 /usr/local/bin/hosty
echo

echo "Done."
