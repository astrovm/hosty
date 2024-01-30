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
checkDep gpg
checkDep mktemp

# creating tmp files
astrokeys=$(mktemp)
hosty=$(mktemp)
signature=$(mktemp)

# download function
downloadFile() {
    if ! curl -sSL --retry 3 -o "$1" "$2"; then
        echo "error downloading $2"
        rm "$astrokeys" "$hosty" "$signature"
        exit 1
    fi
}

# download files
downloadFile "$astrokeys" https://keybase.io/astrolince/pgp_keys.asc
downloadFile "$hosty" https://4st.li/hosty/hosty.sh
downloadFile "$signature" https://4st.li/hosty/hosty.sh.sig

# verify signature
gpg --dearmor "$astrokeys" >/dev/null 2>&1

# if there is a problem, kill the program
if ! gpg --no-default-keyring --keyring "$astrokeys.gpg" --verify "$signature" "$hosty" >/dev/null 2>&1; then
    rm "$astrokeys" "$hosty" "$signature" "$astrokeys.gpg"
    echo "there is a problem with the signature, probably hosty repository was compromised, no changes were made to your system."
    exit 1
fi

rm "$astrokeys" "$signature" "$astrokeys.gpg"
# shellcheck source=/dev/null
. "$hosty"
rm "$hosty"
