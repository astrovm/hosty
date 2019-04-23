#!/bin/bash

prompt=$(sudo -nv 2>&1)
if [ $? -eq 0 ]; then
  # exit code of sudo-command is 0
  echo "has_sudo__pass_set"
elif echo $prompt | grep -q '^sudo:'; then
  echo "has_sudo__needs_pass"
else
  echo "no_sudo"
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
