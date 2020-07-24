#!/bin/sh

# Check dependences
CheckDep() {
    command -v "$1" >/dev/null 2>&1 || {
        echo >&2 "Hosty requires '$1' but it's not installed."
        exit 1
    }
}

CheckDep bash
CheckDep curl
CheckDep gpg

# Creating tmp files
astrokeys=$(mktemp)
hosty=$(mktemp)
signature=$(mktemp)

# Download function
downloadFiles() {
    if ! curl -H 'Cache-Control: no-cache' -fsSL -o "$1" "$2"; then
        echo "Error downloading $2"
        rm "$astrokeys" "$hosty" "$signature"
        exit 1
    fi
}

# Download files
downloadFiles "$astrokeys" https://keybase.io/astrolince/pgp_keys.asc
downloadFiles "$hosty" https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh
downloadFiles "$signature" https://raw.githubusercontent.com/astrolince/hosty/master/hosty.sh.sig

# Verify signature
gpg --dearmor "$astrokeys" >/dev/null 2>&1

# If there is a problem, kill the program
if ! gpg --no-default-keyring --keyring "$astrokeys.gpg" --verify "$signature" "$hosty" >/dev/null 2>&1; then
    rm "$astrokeys" "$hosty" "$signature" "$astrokeys.gpg"
    echo "There is a problem with the signature, probably hosty repository was compromised, no changes were made to your system."
    exit 1
fi

rm "$astrokeys" "$signature" "$astrokeys.gpg"
bash "$hosty" "$*"
rm "$hosty"
