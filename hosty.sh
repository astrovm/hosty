#!/bin/sh

set -euf

# @getoptions
parser_definition() {
    setup REST help:usage -- "usage: hosty [-airduhv]" ''
    msg -- 'options:'
    flag AUTORUN -a --autorun -- "set up autorun with cronie"
    flag IGNORE_DEFAULT_SOURCES -i --ignore-default-sources -- "ignore default sources"
    flag RESTORE -r --restore -- "restore the hosts file"
    flag DEBUG -d --debug -- "run in debug mode"
    flag UNINSTALL -u --uninstall -- "uninstall hosty from the system"
    disp :usage -h --help
    disp VERSION -v --version
}
# @end

# @gengetoptions parser -i parser_definition parse
# Generated by getoptions (BEGIN)
# URL: https://github.com/ko1nksm/getoptions (v3.3.0)
AUTORUN=''
IGNORE_DEFAULT_SOURCES=''
RESTORE=''
DEBUG=''
UNINSTALL=''
REST=''
parse() {
    OPTIND=$(($# + 1))
    while OPTARG= && [ $# -gt 0 ]; do
        case $1 in
        --?*=*)
            OPTARG=$1
            shift
            eval 'set -- "${OPTARG%%\=*}" "${OPTARG#*\=}"' ${1+'"$@"'}
            ;;
        --no-* | --without-*) unset OPTARG ;;
        -[airduhv]?*)
            OPTARG=$1
            shift
            eval 'set -- "${OPTARG%"${OPTARG#??}"}" -"${OPTARG#??}"' ${1+'"$@"'}
            OPTARG=
            ;;
        esac
        case $1 in
        '-a' | '--autorun')
            [ "${OPTARG:-}" ] && OPTARG=${OPTARG#*\=} && set "noarg" "$1" && break
            eval '[ ${OPTARG+x} ] &&:' && OPTARG='1' || OPTARG=''
            AUTORUN="$OPTARG"
            ;;
        '-i' | '--ignore-default-sources')
            [ "${OPTARG:-}" ] && OPTARG=${OPTARG#*\=} && set "noarg" "$1" && break
            eval '[ ${OPTARG+x} ] &&:' && OPTARG='1' || OPTARG=''
            IGNORE_DEFAULT_SOURCES="$OPTARG"
            ;;
        '-r' | '--restore')
            [ "${OPTARG:-}" ] && OPTARG=${OPTARG#*\=} && set "noarg" "$1" && break
            eval '[ ${OPTARG+x} ] &&:' && OPTARG='1' || OPTARG=''
            RESTORE="$OPTARG"
            ;;
        '-d' | '--debug')
            [ "${OPTARG:-}" ] && OPTARG=${OPTARG#*\=} && set "noarg" "$1" && break
            eval '[ ${OPTARG+x} ] &&:' && OPTARG='1' || OPTARG=''
            DEBUG="$OPTARG"
            ;;
        '-u' | '--uninstall')
            [ "${OPTARG:-}" ] && OPTARG=${OPTARG#*\=} && set "noarg" "$1" && break
            eval '[ ${OPTARG+x} ] &&:' && OPTARG='1' || OPTARG=''
            UNINSTALL="$OPTARG"
            ;;
        '-h' | '--help')
            usage
            exit 0
            ;;
        '-v' | '--version')
            echo "${VERSION}"
            exit 0
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                REST="${REST} \"\${$((OPTIND - $#))}\""
                shift
            done
            break
            ;;
        [-]?*)
            set "unknown" "$1"
            break
            ;;
        *)
            REST="${REST} \"\${$((OPTIND - $#))}\""
            ;;
        esac
        shift
    done
    [ $# -eq 0 ] && {
        OPTIND=1
        unset OPTARG
        return 0
    }
    case $1 in
    unknown) set "unrecognized option: $2" "$@" ;;
    noarg) set "does not allow an argument: $2" "$@" ;;
    required) set "requires an argument: $2" "$@" ;;
    pattern:*) set "does not match the pattern (${1#*:}): $2" "$@" ;;
    notcmd) set "not a command: $2" "$@" ;;
    *) set "validation error ($1): $2" "$@" ;;
    esac
    echo "$1" >&2
    exit 1
}
usage() {
    cat <<'GETOPTIONSHERE'
usage: hosty [-airduhv]

options:
  -a, --autorun                 set up autorun with cronie
  -i, --ignore-default-sources  ignore default sources
  -r, --restore                 restore the hosts file
  -d, --debug                   run in debug mode
  -u, --uninstall               uninstall hosty from the system
  -h, --help
  -v, --version
GETOPTIONSHERE
}
# Generated by getoptions (END)
# @end

parse "$@"
eval "set -- $REST"

# check dependences
checkDep() {
    command -v "$1" >/dev/null 2>&1 || {
        echo >&2 "hosty requires '$1' but it's not installed."
        exit 1
    }
}

checkDep curl
checkDep gawk
checkDep head
checkDep cat
checkDep mktemp
checkDep printf

VERSION="1.8.2"
RELEASE_DATE="31/Aug/22"
PROJECT_URL="astrolince.com/hosty"
BLACKLIST_DEFAULT_SOURCE="https://raw.githubusercontent.com/astrolince/hosty/master/lists/blacklist.sources"
WHITELIST_DEFAULT_SOURCE="https://raw.githubusercontent.com/astrolince/hosty/master/lists/whitelist.sources"
BLOCK_IP="0.0.0.0"
INPUT_HOSTS="/etc/hosts"
OUTPUT_HOSTS="/etc/hosts"

echo "======== hosty v$VERSION ($RELEASE_DATE) ========"
echo "========   $PROJECT_URL   ========"
echo

# avoid all system changes if debug mode is enabled
if [ "$DEBUG" ]; then
    AUTORUN=""
    RESTORE=""
    UNINSTALL=""
    OUTPUT_HOSTS=$(mktemp)
    echo "******** DEBUG MODE ON ********"
    echo
fi

# check if running as root
if [ "$(id -u)" != 0 ] && [ ! "$DEBUG" ]; then
    echo "please run as root."
    exit 1
fi

# --uninstall option
if [ "$UNINSTALL" ]; then
    if [ -d /etc/hosty ]; then
        # ask user to remove hosty config
        echo "do you want to remove /etc/hosty configs directory? y/n"
        read -r answer
        echo

        if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
            echo "removing hosty configs directory..."
            rm -R /etc/hosty
            echo
        elif [ "$answer" != "n" ] && [ "$answer" != "N" ] && [ "$answer" != "no" ] && [ "$answer" != "NO" ]; then
            echo "bad answer, exiting..."
            exit 1
        fi
    fi

    # remove autorun config
    if [ -f /etc/cron.daily/hosty ]; then
        echo "removing /etc/cron.daily/hosty..."
        echo
        rm /etc/cron.daily/hosty
    fi

    if [ -f /etc/cron.weekly/hosty ]; then
        echo "removing /etc/cron.weekly/hosty..."
        echo
        rm /etc/cron.weekly/hosty
    fi

    if [ -f /etc/cron.monthly/hosty ]; then
        echo "removing /etc/cron.monthly/hosty..."
        echo
        rm /etc/cron.monthly/hosty
    fi

    echo "uninstalling hosty..."
    rm /usr/local/bin/hosty

    echo
    echo "hosty uninstalled."
    exit 0
fi

# copy original hosts file and handle --restore
user_hosts_file=$(mktemp)
user_hosts_linesnumber=$(gawk '/^# [aA]d blocking hosts generated/ {counter=NR} END{print counter-1}' "$INPUT_HOSTS")

# if hosty has never been executed, don't restore anything
if [ "$user_hosts_linesnumber" -lt 0 ]; then
    if [ "$RESTORE" ]; then
        echo "there is nothing to restore."
        exit 0
    fi

    # if it's the first time running hosty, save the whole /etc/hosts file in the tmp var
    cat "$INPUT_HOSTS" >"$user_hosts_file"
else
    # Copy original hosts lines
    head -n "$user_hosts_linesnumber" "$INPUT_HOSTS" >"$user_hosts_file"

    # If --restore is present, restore original hosts and exit
    if [ "$RESTORE" ]; then
        # Remove empty lines from begin and end
        gawk 'NR==FNR{if (NF) { if (!beg) beg=NR; end=NR } next} FNR>=beg && FNR<=end' "$user_hosts_file" "$user_hosts_file" >"$OUTPUT_HOSTS"
        echo "/etc/hosts restore completed."
        exit 0
    fi
fi

# Cron options
if [ "$AUTORUN" ]; then
    echo "Configuring autorun..."

    # Check system compatibility
    checkDep crontab
    if [ ! -d /etc/cron.daily ] || [ ! -d /etc/cron.weekly ] || [ ! -d /etc/cron.monthly ]; then
        echo
        echo "Hosty doesn't know how to autorun in your operating system, you need to configure that by yourself."
        exit 1
    fi

    # Ask user for autorun period
    echo
    echo "How often do you want to run hosty automatically?"
    echo "Enter 'daily', 'weekly', 'monthly' or 'never':"
    read -r period

    # Check user answer
    if [ "$period" != "daily" ] && [ "$period" != "weekly" ] && [ "$period" != "monthly" ] && [ "$period" != "never" ]; then
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

        # Stop here if the user has chosen 'never'
        if [ "$period" = "never" ]; then
            echo
            echo "Done."
            exit 0
        fi

        # Set cron file with user choice
        cron_file="/etc/cron.$period/hosty"

        # Create the file
        echo
        echo "Creating $cron_file..."
        echo '#!/bin/sh' >"$cron_file"

        # If user have passed the --ignore-default-sources argument, autorun with that
        if [ ! "$IGNORE_DEFAULT_SOURCES" ]; then
            echo '/usr/local/bin/hosty' >>"$cron_file"
        else
            echo
            echo "Config hosty with --ignore-default-sources..."
            echo '/usr/local/bin/hosty --ignore-default-sources' >>"$cron_file"
        fi

        # Set permissions
        chmod 755 "$cron_file"

        echo
        echo "Done."
        exit 0
    fi
fi

# function to download sources
downloadFile() {
    tmp_downloadFile=$(mktemp)

    echo "downloading $1..."
    if ! curl -fsSL -o "$tmp_downloadFile" "$1"; then
        return $?
    fi

    return 0
}

blacklist_sources=$(mktemp)
whitelist_sources=$(mktemp)

# Remove default sources if the user want that
if [ ! "$IGNORE_DEFAULT_SOURCES" ]; then
    echo "downloading default sources..."

    if ! downloadFile "$BLACKLIST_DEFAULT_SOURCE"; then
        echo "Error downloading $BLACKLIST_DEFAULT_SOURCE"
        rm "$tmp_downloadFile"
        exit 1
    fi

    cat "$tmp_downloadFile" >>"$blacklist_sources"
    rm "$tmp_downloadFile"

    if ! downloadFile "$WHITELIST_DEFAULT_SOURCE"; then
        echo "Error downloading $WHITELIST_DEFAULT_SOURCE"
        rm "$tmp_downloadFile"
        exit 1
    fi

    cat "$tmp_downloadFile" >>"$whitelist_sources"
    rm "$tmp_downloadFile"
fi

# User custom blacklist sources
if [ -f /etc/hosty/blacklist.sources ]; then
    echo
    echo "Adding custom blacklist sources..."
    cat /etc/hosty/blacklist.sources >>"$blacklist_sources"
fi

# User custom whitelist sources
if [ -f /etc/hosty/whitelist.sources ]; then
    echo
    echo "Adding custom whitelist sources..."
    cat /etc/hosty/whitelist.sources >>"$whitelist_sources"
fi

echo
echo "downloading blacklists..."
blacklist_domains=$(mktemp)

# Download blacklist sources and merge into one

while read -r line; do
    if ! downloadFile "$line"; then
        echo "Error downloading $line"
        rm "$tmp_downloadFile"
        break
    fi

    cat "$tmp_downloadFile" >>"$blacklist_domains"
    rm "$tmp_downloadFile"
done <"$blacklist_sources"

if [ -f /etc/hosty/blacklist ]; then
    echo
    echo "Applying user custom blacklist..."
    cat "/etc/hosty/blacklist" >>"$blacklist_domains"
fi

# Take all domains of any text file
extractDomains() {
    echo
    echo "extracting domains..."
    # Remove whitespace at beginning of the line
    printf '%s\n' "$(gawk '{gsub(/^[[:space:]]*/,""); print}' "$1")" >"$1"
    # Remove lines that start with '!'
    printf '%s\n' "$(gawk '!/^!/' "$1")" >"$1"
    # Remove '#' and everything that follows
    printf '%s\n' "$(gawk '{gsub(/#.*/,""); print}' "$1")" >"$1"
    # Replace with new lines everything that isn't letters, numbers, hyphens and dots
    printf '%s\n' "$(gawk '{gsub(/[^a-zA-Z0-9\.\-]/,"\n"); print}' "$1")" >"$1"
    # Remove lines that don't have dots
    printf '%s\n' "$(gawk '/\./' "$1")" >"$1"
    # Remove lines that don't start with a letter or number
    printf '%s\n' "$(gawk '/^[a-zA-Z0-9]/' "$1")" >"$1"
    # Remove lines that end with a dot
    printf '%s\n' "$(gawk '!/\.$/' "$1")" >"$1"
    # Removing important system ips
    printf '%s\n' "$(gawk '!/^(127\.0\.0\.1|255\.255\.255\.255|0\.0\.0\.0|255\.255\.255\.0|localhost\.localdomain)$/' "$1")" >"$1"
    # Remove duplicates
    printf '%s\n' "$(gawk '!x[$0]++' "$1")" >"$1"

    # Count extacted domains
    domains_counter=$(gawk 'BEGIN{counter=0}{counter++;}END{print counter}' "$1")
    echo "$domains_counter domains extracted."

    return 0
}

# Extract domains from blacklist sources
extractDomains "$blacklist_domains"

echo
echo "downloading whitelists..."
whitelist_domains=$(mktemp)

# Download whitelist sources and merge into one
while read -r line; do
    if ! downloadFile "$line"; then
        echo "Error downloading $line"
        rm "$tmp_downloadFile"
        break
    fi

    cat "$tmp_downloadFile" >>"$whitelist_domains"
    rm "$tmp_downloadFile"
done <"$whitelist_sources"

if [ -f /etc/hosty/whitelist ]; then
    echo
    echo "Applying user custom whitelist..."
    cat "/etc/hosty/whitelist" >>"$whitelist_domains"
fi

# Extract domains from whitelist sources
extractDomains "$whitelist_domains"

echo
echo "building $OUTPUT_HOSTS..."
final_hosts_file=$(mktemp)

# Remove empty lines from begin and end
gawk 'NR==FNR{if (NF) { if (!beg) beg=NR; end=NR } next} FNR>=beg && FNR<=end' "$user_hosts_file" "$user_hosts_file" >"$final_hosts_file"

# Add blank line at the end
{
    echo
    echo "# Ad blocking hosts generated $(date)"
    echo "# Don't write below this line. It will be lost if you run hosty again."
} >>"$final_hosts_file"

echo
echo "cleaning and de-duplicating..."

# Here we take the urls from the original hosts file and we add them to the whitelist to ensure that these urls behave like the user expects
gawk '/^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' "$user_hosts_file" >>"$whitelist_domains"

# Applying the whitelist and dedup
gawk -v ip=$BLOCK_IP 'FNR==NR {arr[$1]++} FNR!=NR {if (!arr[$1]++) print ip, $1}' "$whitelist_domains" "$blacklist_domains" >>"$final_hosts_file"

# Remove tmp files
rm "$blacklist_domains" "$whitelist_domains" "$user_hosts_file"

# Count websites blocked
websites_blocked_counter=$(gawk "/$BLOCK_IP/ {count++} END{print count}" "$final_hosts_file")

cat "$final_hosts_file" >"$OUTPUT_HOSTS"
rm "$final_hosts_file"

echo
echo "done, $websites_blocked_counter websites blocked."
echo
echo "you can always restore your original hosts file with this command:"
echo "$ sudo hosty -r (--restore)"
