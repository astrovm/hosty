#!/bin/bash

# Add ad-blocking hosts files in this array
HOSTS_URLS=( "https://raw.githubusercontent.com/astrolince/hosty/master/hostyhosts.txt"
             "https://raw.githubusercontent.com/StevenBlack/hosts/master/data/StevenBlack/hosts"
             "https://www.malwaredomainlist.com/hostslist/hosts.txt"
             "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Dead/hosts"
             "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
             "https://someonewhocares.org/hosts/zero/hosts"
             "http://winhelp2002.mvps.org/hosts.txt"
             "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&mimetype=plaintext&useip=0.0.0.0"
             "https://raw.githubusercontent.com/mitchellkrogza/Badd-Boyz-Hosts/master/hosts"
             "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
             "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
             "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
             "https://raw.githubusercontent.com/azet12/KADhosts/master/KADhosts.txt"
             "https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt"
             "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
             "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" )

# Set IP to redirect
IP="0.0.0.0"

# Local /etc/hosty and ~/.hosty hosts file urls list
if [ -f /etc/hosty ]; then
    while read -r line
    do
        HOSTS_URLS+=("$line")
    done < /etc/hosty
fi

if [ -f ~/.hosty ]; then
    while read -r line
    do
        HOSTS_URLS+=("$line")
    done < ~/.hosty
fi

# Check if gsed exists (for macOS)
sedFunc() {
    if hash gsed 2>/dev/null; then
        gsed "$@"
    else
        sed "$@"
    fi
}

# Function to download hosts files
downloadHosts() {
    wget --no-cache -nv -O $downloaded_hosts $1
    if [ $? != 0 ]; then
        return $?
    fi
    if [[ $1 == *.zip ]]; then
        zcat "$downloaded_hosts" > "$tmp_zcat"
        cat "$tmp_zcat" > "$downloaded_hosts"
        if [ $? != 0 ]; then
            return $?
        fi
    elif [[ $1 == *.7z ]]; then
        7z e -so -bd "$downloaded_hosts" 2>/dev/null > $1
        if [ $? != 0 ]; then
            return $?
        fi
    fi
    return 0
}

original_hosts_file=$(mktemp)
lines_original_hosts_counter=$(sedFunc -n '/^# Ad blocking hosts generated/=' /etc/hosts)

# If it's the first time running hosty, save the whole /etc/hosts file in the tmp var
if [ -z $lines_original_hosts_counter ]; then
    if [ "$1" == "--restore" ]; then
        echo "There is nothing to restore."
        exit 0
    fi
    cat /etc/hosts > $original_hosts_file
else
    let lines_original_hosts_counter-=1
    head -n $lines_original_hosts_counter /etc/hosts > $original_hosts_file
    if [ "$1" == "--restore" ]; then
        sudo bash -c "cat $original_hosts_file > /etc/hosts"
        echo "/etc/hosts restore completed."
        exit 0
    fi
fi

tmp_zcat=$(mktemp)
tmp_hosts=$(mktemp)

downloaded_hosts=$(mktemp)
user_whitelist=$(mktemp)

final_hosts_file=$(mktemp)

echo "Downloading ad-blocking files..."

# Obtain various hosts files and merge into one
for i in "${HOSTS_URLS[@]}"
do
    downloadHosts $i
    if [ $? != 0 ]; then
        echo "Error downloading $i"
    else
        sedFunc -e '/^[[:space:]]*\(127\.0\.0\.1\|0\.0\.0\.0\|255\.255\.255\.0\)[[:space:]]/!d' -e 's/[[:space:]]\+/ /g' $downloaded_hosts | awk '$2~/^[^# ]/ {print $2}' >> $tmp_hosts
    fi
done

echo
echo "Excluding localhost and similar domains..."
sedFunc -e '/^\(localhost\|localhost\.localdomain\|local\|broadcasthost\|ip6-localhost\|ip6-loopback\|ip6-localnet\|ip6-mcastprefix\|ip6-allnodes\|ip6-allrouters\)$/d' -i $tmp_hosts

if [ "$1" != "--all" ] && [ "$2" != "--all" ]; then
    echo
    echo "Applying recommended whitelist (Run hosty --all to avoid this step)..."
    sedFunc -e '/\(smarturl\.it\|da\.feedsportal\.com\|any\.gs\|pixel\.everesttech\.net\|www\.googleadservices\.com\|maxcdn\.com\|static\.addtoany\.com\|addthis\.com\|googletagmanager\.com\|addthiscdn\.com\|sharethis\.com\|twitter\.com\|pinterest\.com\|ojrq\.net\|rpxnow\.com\|google-analytics\.com\|shorte\.st\|adf\.ly\|www\.linkbucks\.com\|static\.linkbucks\.com\)$/d' -i $tmp_hosts
fi

echo
echo "Applying user blacklist..."
if [ -f /etc/hosts.blacklist ]; then
    cat "/etc/hosts.blacklist" >> $tmp_hosts
fi

if [ -f ~/.hosty.blacklist ]; then
    cat "~/.hosty.blacklist" >> $tmp_hosts
fi

echo
echo "Applying user whitelist..."
if [ -f /etc/hosts.whitelist ]; then
    cat "/etc/hosts.whitelist" >> $user_whitelist
fi

if [ -f ~/.hosty.whitelist ]; then
    cat "~/.hosty.whitelist" >> $user_whitelist
fi

echo
echo "Cleaning and de-duplicating..."

# Here we take the urls from the original hosts file and we add them to the whitelist to ensure that these urls behave like the user expects
awk '/^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' $original_hosts_file >> $user_whitelist

# Applying the whitelist and dedup
awk -v ip=$IP 'FNR==NR {arr[$1]++} FNR!=NR {if (!arr[$1]++) print ip, $1}' $user_whitelist $tmp_hosts > $downloaded_hosts

echo
echo "Building /etc/hosts..."
cat $original_hosts_file > $final_hosts_file

echo "# Ad blocking hosts generated $(date)" >> $final_hosts_file
echo "# Don't write below this line. It will be lost if you run hosty again." >> $final_hosts_file
cat $downloaded_hosts >> $final_hosts_file

websites_blocked_counter=$(grep -c "$IP" $final_hosts_file)

if [ "$1" != "--debug" ] && [ "$2" != "--debug" ]; then
    sudo bash -c "cat $final_hosts_file > /etc/hosts"
else
    echo
    echo "You can see the results in $final_hosts_file"
fi

echo
echo "Done, $websites_blocked_counter websites blocked."
echo
echo "You can always restore your original hosts file with this command:"
echo "  $ sudo hosty --restore"
