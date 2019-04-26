#!/bin/bash

echo "======== hosty v1.5.0 (26/Apr/19) ========"
echo "========   astrolince.com/hosty   ========"
echo

# We'll block every domain that is inside these files
BLACKLIST_SOURCES=( "https://mirror1.malwaredomains.com/files/domains.hosts"
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

# We'll unblock every domain that is inside these files
WHITELIST_SOURCES=( "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt"
                    "https://raw.githubusercontent.com/brave/adblock-lists/master/brave-unbreak.txt"
                    "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt"
                    "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/referral-sites.txt"
                    "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/optional-list.txt" )

# Set IP to redirect
IP="0.0.0.0"

# Check if running as root
if [ "$1" != "--debug" ] && [ "$2" != "--debug" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi

    # --uninstall option
    if [ "$1" == "--uninstall" ]; then
        if [ -d /etc/hosty ]; then
            # Ask user to remove hosty config
            echo "Do you want to remove /etc/hosty configs directory? y/n"
            read answer
            echo

            # Check user answer
            if [ "$answer" == "y" ]; then
                echo "Removing hosty configs directory..."
                sudo rm -R /etc/hosty
                echo
            elif [ "$answer" != "n" ]; then
                echo "Bad answer, exiting..."
                exit 1
            fi
        fi

        # Remove autorun config
        if [ -f /etc/cron.daily/hosty ]; then
            echo "Removing /etc/cron.daily/hosty..."
            echo
            rm /etc/cron.daily/hosty
        fi

        if [ -f /etc/cron.weekly/hosty ]; then
            echo "Removing /etc/cron.weekly/hosty..."
            echo
            rm /etc/cron.weekly/hosty
        fi

        if [ -f /etc/cron.monthly/hosty ]; then
            echo "Removing /etc/cron.monthly/hosty..."
            echo
            rm /etc/cron.monthly/hosty
        fi

        echo "Uninstalling hosty..."
        sudo rm /usr/local/bin/hosty

        echo
        echo "Hosty uninstalled."

        exit 0
    fi
else
    echo "******** DEBUG MODE ON ********"
    echo
fi

# Copy original hosts file and handle --restore
user_hosts_file=$(mktemp)
user_hosts_linesnumber=$(sed -n '/^# Ad blocking hosts generated/=' /etc/hosts)

# If hosty has never been executed, don't restore anything
if [ -z $user_hosts_linesnumber ]; then
    if [ "$1" == "--restore" ]; then
        echo "There is nothing to restore."
        exit 0
    fi
    # If it's the first time running hosty, save the whole /etc/hosts file in the tmp var
    cat /etc/hosts > $user_hosts_file
else
    # Copy original hosts lines
    let user_hosts_linesnumber-=1
    head -n $user_hosts_linesnumber /etc/hosts > $user_hosts_file

    # If --restore is present, restore original hosts and exit
    if [ "$1" == "--restore" ]; then
        cat $user_hosts_file > /etc/hosts
        echo "/etc/hosts restore completed."
        exit 0
    fi
fi

# Cron options
if [ "$1" == "--autorun" ] || [ "$2" == "--autorun" ]; then
    echo "Configuring autorun..."

    # Ask user for autorun period
    echo
    echo "Enter 'daily', 'weekly' or 'monthly':"
    read period

    # Check user answer
    if [ "$period" != "daily" ] && [ "$period" != "weekly" ] && [ "$period" != "monthly" ]; then
        echo
        echo "Bad answer, exiting..."
        exit 1
    else
        # Remove previous config
        if [ -f /etc/cron.daily/hosty ]; then
            echo
            echo "Removing /etc/cron.daily/hosty..."
            rm /etc/cron.daily/hosty
        fi

        if [ -f /etc/cron.weekly/hosty ]; then
            echo
            echo "Removing /etc/cron.weekly/hosty..."
            rm /etc/cron.weekly/hosty
        fi

        if [ -f /etc/cron.monthly/hosty ]; then
            echo
            echo "Removing /etc/cron.monthly/hosty..."
            rm /etc/cron.monthly/hosty
        fi

        # Set cron file with user choice
        cron_file="/etc/cron.$period/hosty"

        # Create the file
        echo
        echo "Creating $cron_file..."
        echo '#!/bin/sh' > $cron_file

        # If user have passed the --ignore-default-sources argument, autorun with that
        if [ "$1" != "--ignore-default-sources" ] && [ "$2" != "--ignore-default-sources" ]; then
            echo '/usr/local/bin/hosty' >> $cron_file
        else
            echo
            echo "Config hosty with --ignore-default-sources..."
            echo '/usr/local/bin/hosty --ignore-default-sources' >> $cron_file
        fi

        # Set permissions
        chmod 755 $cron_file

        echo
        echo "Done."
        exit 0
    fi
fi

# Remove default sources if the user want that
if [ "$1" == "--ignore-default-sources" ] || [ "$2" == "--ignore-default-sources" ]; then
    BLACKLIST_SOURCES=()
    WHITELIST_SOURCES=()
fi

# User custom blacklists sources
if [ -f /etc/hosty/blacklist.sources ]; then
    while read -r line
    do
        BLACKLIST_SOURCES+=("$line")
    done < /etc/hosty/blacklist.sources
fi

## DEPRECATED
if [ -f /etc/hosty ]; then
    while read -r line
    do
        BLACKLIST_SOURCES+=("$line")
    done < /etc/hosty
fi
if [ -f ~/.hosty ]; then
    while read -r line
    do
        BLACKLIST_SOURCES+=("$line")
    done < ~/.hosty
fi
if [ -f /etc/hosty/hosts ]; then
    while read -r line
    do
        BLACKLIST_SOURCES+=("$line")
    done < /etc/hosty/hosts
fi
##

# User custom whitelist sources
if [ -f /etc/hosty/whitelist.sources ]; then
    while read -r line
    do
        WHITELIST_SOURCES+=("$line")
    done < /etc/hosty/whitelist.sources
fi

# Function to download sources
downloadFile() {
    echo "Downloading $1..."
    curl -L -s -S -o $downloaded_files $1

    if [ $? != 0 ]; then
        return $?
    fi

    if [[ $1 == *.zip ]]; then
        tmp_zcat=$(mktemp)
        zcat "$downloaded_files" > "$tmp_zcat"
        cat "$tmp_zcat" > "$downloaded_files"

        if [ $? != 0 ]; then
            return $?
        fi
    elif [[ $1 == *.7z ]]; then
        7z e -so -bd "$downloaded_files" 2>/dev/null > $1

        if [ $? != 0 ]; then
            return $?
        fi
    fi

    return 0
}

# Take all domains of any text file
extractDomains() {
    echo
    echo "Extracting domains..."
    # Remove whitespace at beginning of the line
    sed -e 's/^[[:space:]]*//g' -i $1
    # Remove lines that start with '!'
    sed -e '/^!/d' -i $1
    # Remove '#' and everything that follows
    sed -e 's/#.*//g' -i $1
    # Replace with new lines everything that isn't letters, numbers, hyphens and dots
    sed -e 's/[^a-zA-Z0-9\.\-]/\n/g' -i $1
    # Remove lines that don't have dots
    sed -e '/\./!d' -i $1
    # Remove lines that don't start with a letter or number
    sed -e '/^[a-zA-Z0-9]/!d' -i $1
    # Remove lines that end with a dot
    sed -e '/\.$/d' -i $1
    # Removing important system ips
    sed -e '/^\(127\.0\.0\.1\|255\.255\.255\.255\|0\.0\.0\.0\|255\.255\.255\.0\|localhost\.localdomain\)$/d' -i $1

    # Count extacted domains
    domains_counter=$(awk 'BEGIN{counter=0}{counter++;}END{print counter}' $1)
    echo "$domains_counter domains extracted."

    return 0
}

downloaded_files=$(mktemp)

blacklist_domains=$(mktemp)
whitelist_domains=$(mktemp)

final_hosts_file=$(mktemp)

echo "Downloading blacklists..."

# Download blacklist sources and merge into one
for i in "${BLACKLIST_SOURCES[@]}"
do
    downloadFile $i
    if [ $? != 0 ]; then
        echo "Error downloading $i"
    else
        cat $downloaded_files >> $blacklist_domains
    fi
done

# Extract domains from blacklist sources
extractDomains $blacklist_domains

echo
echo "Downloading whitelists..."

# Download whitelist sources and merge into one
for i in "${WHITELIST_SOURCES[@]}"
do
    downloadFile $i
    if [ $? != 0 ]; then
        echo "Error downloading $i"
    else
        cat $downloaded_files >> $whitelist_domains
    fi
done

# Extract domains from whitelist sources
extractDomains $whitelist_domains

echo
echo "Applying user custom blacklist..."
if [ -f /etc/hosty/blacklist ]; then
    cat "/etc/hosty/blacklist" >> $blacklist_domains
fi

# DEPRECATED
if [ -f /etc/hosts.blacklist ]; then
    cat "/etc/hosts.blacklist" >> $blacklist_domains
fi
if [ -f ~/.hosty.blacklist ]; then
    cat "~/.hosty.blacklist" >> $blacklist_domains
fi
##

echo
echo "Applying user custom whitelist..."
if [ -f /etc/hosty/whitelist ]; then
    cat "/etc/hosty/whitelist" >> $whitelist_domains
fi

# DEPRECATED
if [ -f /etc/hosts.whitelist ]; then
    cat "/etc/hosts.whitelist" >> $whitelist_domains
fi
if [ -f ~/.hosty.whitelist ]; then
    cat "~/.hosty.whitelist" >> $whitelist_domains
fi
##

echo
echo "Building /etc/hosts..."
cat $user_hosts_file > $final_hosts_file
echo "# Ad blocking hosts generated $(date)" >> $final_hosts_file
echo "# Don't write below this line. It will be lost if you run hosty again." >> $final_hosts_file

echo
echo "Cleaning and de-duplicating..."

# Here we take the urls from the original hosts file and we add them to the whitelist to ensure that these urls behave like the user expects
awk '/^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' $user_hosts_file >> $whitelist_domains

# Applying the whitelist and dedup
awk -v ip=$IP 'FNR==NR {arr[$1]++} FNR!=NR {if (!arr[$1]++) print ip, $1}' $whitelist_domains $blacklist_domains >> $final_hosts_file

# Count websites blocked
websites_blocked_counter=$(grep -c "$IP" $final_hosts_file)

if [ "$1" != "--debug" ] && [ "$2" != "--debug" ]; then
    cat $final_hosts_file > /etc/hosts
else
    echo
    echo "You can see the results in $final_hosts_file"
fi

echo
echo "Done, $websites_blocked_counter websites blocked."
echo
echo "You can always restore your original hosts file with this command:"
echo "  $ sudo hosty --restore"
