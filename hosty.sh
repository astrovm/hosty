#!/bin/sh

set -euf

VERSION="1.9.7"
RELEASE_DATE="29/jan/24"
PROJECT_URL="4st.li/hosty"
BLACKLIST_DEFAULT_SOURCE="https://4st.li/hosty/lists/blacklist.sources"
WHITELIST_DEFAULT_SOURCE="https://4st.li/hosty/lists/whitelist.sources"
BLOCK_IP="0.0.0.0"
INPUT_HOSTS="/etc/hosts"
OUTPUT_HOSTS="/etc/hosts"

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
checkDep awk
checkDep head
checkDep cat
checkDep mktemp
checkDep sort
checkDep grep

echo "======== hosty v$VERSION ($RELEASE_DATE) ========"
echo "========       $PROJECT_URL       ========"
echo

# avoid all system changes if debug mode is enabled
if [ "$DEBUG" = 1 ]; then
    AUTORUN=""
    UNINSTALL=""
    OUTPUT_HOSTS=$(mktemp)
    echo "******** DEBUG MODE ON ********"
    echo
fi

# check if running as root
if [ "$(id -u)" != 0 ] && [ "$DEBUG" != 1 ]; then
    echo "please run as root."
    exit 1
fi

# --uninstall option
if [ "$UNINSTALL" = 1 ]; then
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
        rm /etc/cron.daily/hosty
        echo
    fi

    if [ -f /etc/cron.weekly/hosty ]; then
        echo "removing /etc/cron.weekly/hosty..."
        rm /etc/cron.weekly/hosty
        echo
    fi

    if [ -f /etc/cron.monthly/hosty ]; then
        echo "removing /etc/cron.monthly/hosty..."
        rm /etc/cron.monthly/hosty
        echo
    fi

    previous_crontab=$(mktemp)
    if crontab -l 2>/dev/null >"$previous_crontab" && grep "/usr/local/bin/hosty" "$previous_crontab" >/dev/null 2>&1; then
        echo "removing from crontab..."
        new_crontab=$(mktemp)
        awk '!/\/usr\/local\/bin\/hosty/' "$previous_crontab" >"$new_crontab"
        crontab "$new_crontab"
        echo
    fi

    if [ -f /usr/local/bin/hosty ]; then
        echo "uninstalling hosty..."
        rm /usr/local/bin/hosty
        echo
    fi

    echo "hosty uninstalled."
    exit 0
fi

# copy original hosts file and handle --restore
user_hosts_file=$(mktemp)
user_hosts_linesnumber=$(awk '/^# [aA]d blocking hosts generated/ {counter=NR} END{print counter-1}' "$INPUT_HOSTS")

# if hosty has never been executed, don't restore anything
if [ "$user_hosts_linesnumber" -lt 0 ]; then
    if [ "$RESTORE" = 1 ]; then
        echo "there is nothing to restore."
        exit 0
    fi

    # if it's the first time running hosty, save the whole /etc/hosts file in the tmp var
    cat "$INPUT_HOSTS" >"$user_hosts_file"
else
    # copy original hosts lines
    head -n "$user_hosts_linesnumber" "$INPUT_HOSTS" >"$user_hosts_file"

    # if --restore is present, restore original hosts and exit
    if [ "$RESTORE" = 1 ]; then
        # remove empty lines from begin and end
        awk 'NR==FNR{if (NF) { if (!beg) beg=NR; end=NR } next} FNR>=beg && FNR<=end' "$user_hosts_file" "$user_hosts_file" >"$OUTPUT_HOSTS"
        echo "$OUTPUT_HOSTS restore completed."
        exit 0
    fi
fi

# cron options
if [ "$AUTORUN" = 1 ]; then
    echo "configuring autorun..."

    # check system compatibility
    checkDep crontab

    # remove old config
    if [ -f /etc/cron.daily/hosty ]; then
        echo
        echo "removing /etc/cron.daily/hosty..."
        rm /etc/cron.daily/hosty
    fi

    if [ -f /etc/cron.weekly/hosty ]; then
        echo
        echo "removing /etc/cron.weekly/hosty..."
        rm /etc/cron.weekly/hosty
    fi

    if [ -f /etc/cron.monthly/hosty ]; then
        echo
        echo "removing /etc/cron.monthly/hosty..."
        rm /etc/cron.monthly/hosty
    fi

    # if user have passed the --ignore-default-sources argument, autorun with that
    if [ "$IGNORE_DEFAULT_SOURCES" != 1 ]; then
        hosty_cmd="/usr/local/bin/hosty"
    else
        echo
        echo "autorunning with --ignore-default-sources..."
        hosty_cmd="/usr/local/bin/hosty -i"
    fi

    # ask user for autorun period
    echo
    echo "how often do you want to run hosty automatically?"
    echo "enter 'daily', 'weekly', 'monthly' or 'never':"
    read -r period

    # clean crontab from previous config
    previous_crontab=$(mktemp)
    (crontab -l 2>/dev/null || true) >"$previous_crontab"
    new_crontab=$(mktemp)
    awk '!/\/usr\/local\/bin\/hosty/' "$previous_crontab" >"$new_crontab"

    # check user answer
    if [ "$period" = "daily" ]; then
        echo "0 0 * * * $hosty_cmd" >>"$new_crontab"
        crontab "$new_crontab"
    elif [ "$period" = "weekly" ]; then
        echo "0 0 * * 0 $hosty_cmd" >>"$new_crontab"
        crontab "$new_crontab"
    elif [ "$period" = "monthly" ]; then
        echo "0 0 1 * * $hosty_cmd" >>"$new_crontab"
        crontab "$new_crontab"
    elif [ "$period" = "never" ]; then
        if grep "/usr/local/bin/hosty" "$previous_crontab" >/dev/null 2>&1; then
            crontab "$new_crontab"
        fi
    else
        echo
        echo "bad answer, exiting..."
        exit 1
    fi

    echo
    echo "done."
    exit 0
fi

# function to download sources
downloadFile() {
    tmp_downloadFile=$(mktemp)

    echo "downloading $1"
    if ! curl -sSL --retry 3 -o "$tmp_downloadFile" "$1"; then
        echo "error downloading $1"
        rm "$tmp_downloadFile"
        exit 1
    fi
}

blacklist_sources=$(mktemp)
whitelist_sources=$(mktemp)

# remove default sources if the user want that
if [ "$IGNORE_DEFAULT_SOURCES" != 1 ]; then
    echo "downloading default sources..."

    downloadFile "$BLACKLIST_DEFAULT_SOURCE"
    cat "$tmp_downloadFile" >>"$blacklist_sources"
    rm "$tmp_downloadFile"

    downloadFile "$WHITELIST_DEFAULT_SOURCE"
    cat "$tmp_downloadFile" >>"$whitelist_sources"
    rm "$tmp_downloadFile"
fi

# user custom blacklist sources
if [ -f /etc/hosty/blacklist.sources ]; then
    echo
    echo "adding custom blacklist sources..."
    cat /etc/hosty/blacklist.sources >>"$blacklist_sources"
fi

# user custom whitelist sources
if [ -f /etc/hosty/whitelist.sources ]; then
    echo
    echo "adding custom whitelist sources..."
    cat /etc/hosty/whitelist.sources >>"$whitelist_sources"
fi

echo
echo "downloading blacklists..."
blacklist_domains=$(mktemp)

# download blacklist sources and merge into one
while read -r line; do
    downloadFile "$line"
    cat "$tmp_downloadFile" >>"$blacklist_domains"
    rm "$tmp_downloadFile"
done <"$blacklist_sources"

if [ -f /etc/hosty/blacklist ]; then
    echo
    echo "applying user custom blacklist..."
    cat "/etc/hosty/blacklist" >>"$blacklist_domains"
fi

# take all domains of any text file
extractDomains() {
    echo
    echo "extracting domains..."
    tmp_domains=$(mktemp)
    # remove lines that don't start with a letter/number/: (ignoring whitespace)
    awk '/^\s*[a-zA-Z0-9:]/' "$1" >"$tmp_domains"
    cp "$tmp_domains" "$1"
    # remove '#' and everything that follows
    awk '{gsub(/#.*/,""); print}' "$1" >"$tmp_domains"
    cp "$tmp_domains" "$1"
    # replace with new lines everything that isn't letters, numbers, hyphens and dots
    awk '{gsub(/[^a-zA-Z0-9\.\-]/,"\n"); print}' "$1" >"$tmp_domains"
    cp "$tmp_domains" "$1"
    # remove lines that don't have a dot&letter
    awk '/\./ && /[a-zA-Z]/' "$1" >"$tmp_domains"
    cp "$tmp_domains" "$1"
    # remove lines that end/start with a hyphen/dot
    awk '!/^[\.\-]|[\.\-]$/' "$1" >"$tmp_domains"
    cp "$tmp_domains" "$1"
    # remove duplicates and sort
    awk '!x[$0]++' "$1" >"$tmp_domains"
    sort "$tmp_domains" >"$1"
    rm "$tmp_domains"
    # count extacted domains
    domains_counter=$(awk 'BEGIN{counter=0}{counter++;}END{print counter}' "$1")
    echo "$domains_counter domains extracted."
}

# extract domains from blacklist sources
extractDomains "$blacklist_domains"

echo
echo "downloading whitelists..."
whitelist_domains=$(mktemp)

# download whitelist sources and merge into one
while read -r line; do
    downloadFile "$line"
    cat "$tmp_downloadFile" >>"$whitelist_domains"
    rm "$tmp_downloadFile"
done <"$whitelist_sources"

if [ -f /etc/hosty/whitelist ]; then
    echo
    echo "applying user custom whitelist..."
    cat "/etc/hosty/whitelist" >>"$whitelist_domains"
fi

# whitelist sources and original hosts file domains
cat "$blacklist_sources" "$whitelist_sources" "$user_hosts_file" >>"$whitelist_domains"

# extract domains from whitelist sources
extractDomains "$whitelist_domains"

echo
echo "building $OUTPUT_HOSTS"
final_hosts_file=$(mktemp)

# remove empty lines from begin and end
awk 'NR==FNR{if (NF) { if (!beg) beg=NR; end=NR } next} FNR>=beg && FNR<=end' "$user_hosts_file" "$user_hosts_file" >"$final_hosts_file"

# add blank line at the end
{
    echo
    echo "# Ad blocking hosts generated $(date)"
    echo "# Don't write below this line. It will be lost if you run hosty again."
} >>"$final_hosts_file"

echo
echo "cleaning and de-duplicating..."

# applying the whitelist and dedup
awk -v ip="$BLOCK_IP" 'FNR==NR {arr[$1]++} FNR!=NR {if (!arr[$1]++) print ip, $1}' "$whitelist_domains" "$blacklist_domains" >>"$final_hosts_file"

# remove tmp files
rm "$blacklist_domains" "$whitelist_domains" "$user_hosts_file"

# count websites blocked
websites_blocked_counter=$(awk "/$BLOCK_IP/ {count++} END{print count}" "$final_hosts_file")

cat "$final_hosts_file" >"$OUTPUT_HOSTS"
rm "$final_hosts_file"

echo
echo "done, $websites_blocked_counter websites blocked."
echo
echo "you can always restore your original hosts file with this command:"
echo "$ sudo hosty -r (--restore)"
