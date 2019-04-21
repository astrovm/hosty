#!/bin/bash

# Add ad-blocking hosts files in this array
HOSTS=( "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" )

# Set IP to redirect
IP="0.0.0.0"

# Local /etc/hosty and ~/.hosty hosts file urls list
if [ -f /etc/hosty ]; then
    while read -r line
    do
        HOSTS+=("$line")
    done < /etc/hosty
fi

if [ -f ~/.hosty ]; then
    while read -r line
    do
        HOSTS+=("$line")
    done < ~/.hosty
fi

# Check if gsed exists (for macOS)
gnused() {
    if hash gsed 2>/dev/null; then
        gsed "$@"
    else
        sed "$@"
    fi
}

# Function to download hosts files
dwn() {
    wget --no-cache -nv -O $aux $1
    if [ $? != 0 ]; then
        return $?
    fi
    if [[ $1 == *.zip ]]; then
        zcat "$aux" > "$tmp"
        cat "$tmp" > "$aux"
        if [ $? != 0 ]; then
            return $?
        fi
    elif [[ $1 == *.7z ]]; then
        7z e -so -bd "$aux" 2>/dev/null > $1
        if [ $? != 0 ]; then
            return $?
        fi
    fi
    return 0
}

original_hosts_file=$(mktemp)
ln=$(gnused -n '/^# Ad blocking hosts generated/=' /etc/hosts)

if [ -z $ln ]; then
    if [ "$1" == "--restore" ]; then
        echo "There is nothing to restore."
        exit 0
    fi
    cat /etc/hosts > $original_hosts_file
else
    let ln-=1
    head -n $ln /etc/hosts > $original_hosts_file
    if [ "$1" == "--restore" ]; then
        sudo bash -c "cat $original_hosts_file > /etc/hosts"
        echo "/etc/hosts restore completed."
        exit 0
    fi
fi

host=$(mktemp)
aux=$(mktemp)
tmp=$(mktemp)
white=$(mktemp)

echo "Downloading ad-blocking files..."
# Obtain various hosts files and merge into one
for i in "${HOSTS[@]}"
do
    dwn $i
    if [ $? != 0 ]; then
        echo "Error downloading $i"
    else
        gnused -e '/^[[:space:]]*\(127\.0\.0\.1\|0\.0\.0\.0\|255\.255\.255\.0\)[[:space:]]/!d' -e 's/[[:space:]]\+/ /g' $aux | awk '$2~/^[^# ]/ {print $2}' >> $host
    fi
done

echo
echo "Excluding localhost and similar domains..."
gnused -e '/^\(localhost\|localhost\.localdomain\|local\|broadcasthost\|ip6-localhost\|ip6-loopback\|ip6-localnet\|ip6-mcastprefix\|ip6-allnodes\|ip6-allrouters\)$/d' -i $host

if [ "$1" != "--all" ] && [ "$2" != "--all" ]; then
    echo
    echo "Applying recommended whitelist (Run hosty --all to avoid this step)..."
    gnused -e '/\(smarturl\.it\|da\.feedsportal\.com\|any\.gs\|pixel\.everesttech\.net\|www\.googleadservices\.com\|maxcdn\.com\|static\.addtoany\.com\|addthis\.com\|googletagmanager\.com\|addthiscdn\.com\|sharethis\.com\|twitter\.com\|pinterest\.com\|ojrq\.net\|rpxnow\.com\|google-analytics\.com\|shorte\.st\|adf\.ly\|www\.linkbucks\.com\|static\.linkbucks\.com\)$/d' -i $host
fi

echo
echo "Applying user blacklist..."
if [ -f /etc/hosts.blacklist ]; then
    cat "/etc/hosts.blacklist" >> $host
fi

if [ -f ~/.hosty.blacklist ]; then
    cat "~/.hosty.blacklist" >> $host
fi

echo
echo "Applying user whitelist, cleaning and de-duplicating..."
if [ -f /etc/hosts.whitelist ]; then
    cat "/etc/hosts.whitelist" >> $white
fi

if [ -f ~/.hosty.whitelist ]; then
    cat "~/.hosty.whitelist" >> $white
fi

awk '/^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' $original_hosts_file >> $white
awk -v ip=$IP 'FNR==NR {arr[$1]++} FNR!=NR {if (!arr[$1]++) print ip, $1}' $white $host > $aux

echo
echo "Building /etc/hosts..."
cat $original_hosts_file > $host

echo "# Ad blocking hosts generated $(date)" >> $host
echo "# Don't write below this line. It will be lost if you run hosty again." >> $host
cat $aux >> $host

ln=$(grep -c "$IP" $host)

if [ "$1" != "--debug" ] && [ "$2" != "--debug" ]; then
    sudo bash -c "cat $host > /etc/hosts"
else
    echo
    echo "You can see the results in $host"
fi

echo
echo "Done, $ln websites blocked."
echo
echo "You can always restore your original hosts file with this command:"
echo "  $ sudo hosty --restore"
