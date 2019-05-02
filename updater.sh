#!/bin/bash

# Creating tmp files
astrokeys=$(mktemp)
hosty=$(mktemp)
signature=$(mktemp)

# Download function
downloadFiles() {
    curl -H 'Cache-Control: no-cache' -fsSL -o $1 $2

    if [ $? != 0 ]; then
        echo "Error downloading $2"
        rm $astrokeys $hosty $signature
        exit 1
    fi
}

# Download files
downloadFiles "$astrokeys" https://keybase.io/astrolince/pgp_keys.asc
downloadFiles "$hosty" https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
downloadFiles "$signature" https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh.sig

# Verify signature
gpg --dearmor "$astrokeys" >/dev/null 2>&1
gpg --no-default-keyring --keyring "$astrokeys.gpg" --verify "$signature" "$hosty" >/dev/null 2>&1

# If there is a problem, kill the program
if [ $? -eq 0 ]
then
    rm $astrokeys $signature
    bash <(cat $hosty) $*
    rm $hosty
else
    rm $astrokeys $hosty $signature
    echo "There is a problem with the signature, probably hosty repository was compromised, no changes were made to your system."
    exit 1
fi
