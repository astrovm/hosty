#!/bin/sh

set -euf

VERSION="1.10.1"
RELEASE_DATE="23/jul/26"
PROJECT_URL="4st.li/hosty"
BLACKLIST_DEFAULT_SOURCE="https://4st.li/hosty/lists/blacklist.sources"
WHITELIST_DEFAULT_SOURCE="https://4st.li/hosty/lists/whitelist.sources"
BLOCK_IP="0.0.0.0"
INPUT_HOSTS="/etc/hosts"
OUTPUT_HOSTS="/etc/hosts"
INSTALL_PATH="/usr/local/bin/hosty"

AUTORUN=0
IGNORE_DEFAULT_SOURCES=0
RESTORE=0
DEBUG=0
UNINSTALL=0
WORK_DIR=""

usage() {
    cat << 'EOF_USAGE'
usage: hosty [-airduhv]

options:
  -a, --autorun                 set up automatic updates with crontab
  -i, --ignore-default-sources  ignore the default source lists
  -r, --restore                 restore the hosts file
  -d, --debug                   build the hosts file without changing the system
  -u, --uninstall               uninstall hosty from the system
  -h, --help                    show this help
  -v, --version                 show the version
EOF_USAGE
}

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

set_short_option() {
    case $1 in
        a) AUTORUN=1 ;;
        i) IGNORE_DEFAULT_SOURCES=1 ;;
        r) RESTORE=1 ;;
        d) DEBUG=1 ;;
        u) UNINSTALL=1 ;;
        h)
            usage
            exit 0
            ;;
        v)
            printf '%s\n' "$VERSION"
            exit 0
            ;;
        *) fail "unrecognized option: -$1" ;;
    esac
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case $1 in
            -a | --autorun) AUTORUN=1 ;;
            -i | --ignore-default-sources) IGNORE_DEFAULT_SOURCES=1 ;;
            -r | --restore) RESTORE=1 ;;
            -d | --debug) DEBUG=1 ;;
            -u | --uninstall) UNINSTALL=1 ;;
            -h | --help)
                usage
                exit 0
                ;;
            -v | --version)
                printf '%s\n' "$VERSION"
                exit 0
                ;;
            --)
                shift
                [ "$#" -eq 0 ] || fail "unexpected argument: $1"
                break
                ;;
            -?*)
                _options=${1#-}
                while [ -n "$_options" ]; do
                    _option=${_options%"${_options#?}"}
                    _options=${_options#?}
                    set_short_option "$_option"
                done
                ;;
            *) fail "unexpected argument: $1" ;;
        esac
        shift
    done
}

check_dep() {
    command -v "$1" > /dev/null 2>&1 || fail "hosty requires '$1', but it is not installed."
}

is_yes() {
    case $1 in
        y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}

is_no() {
    case $1 in
        n | N | no | NO) return 0 ;;
        *) return 1 ;;
    esac
}

read_reply() {
    if IFS= read -r REPLY; then
        return 0
    fi
    if [ -r /dev/tty ] && IFS= read -r REPLY < /dev/tty; then
        return 0
    fi
    fail "failed to read input."
}

cleanup() {
    if [ -n "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

remove_legacy_cron_scripts() {
    for _period in daily weekly monthly; do
        _file="/etc/cron.$_period/hosty"
        if [ -f "$_file" ]; then
            printf 'removing %s...\n\n' "$_file"
            rm -f "$_file"
        fi
    done
}

# Publish a complete hosts file without exposing a partially written file.
# Existing files are overwritten in place first to preserve ownership and metadata.
install_hosts_file() {
    _source=$1
    _destination=$OUTPUT_HOSTS
    _directory=$(dirname "$_destination")
    _staged=$(mktemp "$_directory/.hosty.XXXXXX" 2> /dev/null) || _staged=$(mktemp) || exit 1

    cat "$_source" > "$_staged"

    if [ -f "$_destination" ] && cat "$_staged" > "$_destination" 2> /dev/null; then
        chmod 644 "$_destination" 2> /dev/null || true
        rm -f "$_staged"
        return 0
    fi

    if chmod 644 "$_staged" 2> /dev/null && mv -f "$_staged" "$_destination" 2> /dev/null; then
        return 0
    fi

    # A busy mount may reject rename while still permitting an in-place write.
    if cat "$_staged" > "$_destination" 2> /dev/null; then
        chmod 644 "$_destination" 2> /dev/null || true
        rm -f "$_staged"
        return 0
    fi

    fail "failed to write $_destination; recovery copy kept at $_staged"
}

download_required() {
    _url=$1
    _destination=$2
    printf 'downloading %s\n' "$_url"
    if ! curl -fsSL --retry 3 -o "$_destination" "$_url"; then
        fail "error downloading $_url"
    fi
}

download_optional() {
    _url=$1
    _destination=$2
    printf 'downloading %s\n' "$_url"
    if ! curl -fsSL --retry 1 --max-time 10 -o "$_destination" "$_url"; then
        printf 'error downloading %s\n' "$_url" >&2
        rm -f "$_destination"
        return 1
    fi
}

download_sources_into() {
    _sources=$1
    _destination=$2
    _download="$WORK_DIR/download"

    while IFS= read -r _url || [ -n "$_url" ]; do
        case $_url in
            '' | \#*) continue ;;
        esac
        if download_optional "$_url" "$_download"; then
            cat "$_download" >> "$_destination"
        fi
    done < "$_sources"
}

# Extract valid-looking hostnames from hosts files, domain lists, and filter lists.
extract_domains() {
    _file=$1
    _raw="$WORK_DIR/domains.raw"
    _sorted="$WORK_DIR/domains.sorted"

    printf '\nextracting domains...\n'
    awk '
        /^[[:space:]]*[a-zA-Z0-9:]/ {
            line = $0
            sub(/#.*/, "", line)
            gsub(/[^a-zA-Z0-9.-]/, "\n", line)
            count = split(line, parts, "\n")
            for (i = 1; i <= count; i++) {
                domain = parts[i]
                if (domain ~ /\./ && domain ~ /[a-zA-Z]/ &&
                    domain !~ /^[.-]/ && domain !~ /[.-]$/)
                    print domain
            }
        }
    ' "$_file" > "$_raw"
    sort -u "$_raw" > "$_sorted"
    cat "$_sorted" > "$_file"
    _count=$(awk 'END { print NR + 0 }' "$_file")
    printf '%s domains extracted.\n' "$_count"
}

trim_empty_lines() {
    awk 'NR == FNR {
        if (NF) {
            if (!first) first = NR
            last = NR
        }
        next
    }
    FNR >= first && FNR <= last' "$1" "$1"
}

parse_args "$@"

for _dependency in curl awk head cat mktemp sort grep dirname chmod mv rm; do
    check_dep "$_dependency"
done

printf '======== hosty v%s (%s) ========\n' "$VERSION" "$RELEASE_DATE"
printf '========       %s       ========\n\n' "$PROJECT_URL"

if [ "$DEBUG" -eq 1 ]; then
    AUTORUN=0
    UNINSTALL=0
    OUTPUT_HOSTS=$(mktemp) || exit 1
    printf '%s\n\n' '******** DEBUG MODE ON ********'
elif [ "$(id -u)" -ne 0 ]; then
    fail "hosty must run as root; use sudo, doas, or a root shell."
fi

WORK_DIR=$(mktemp -d) || exit 1
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "$UNINSTALL" -eq 1 ]; then
    if [ -d /etc/hosty ]; then
        printf 'do you want to remove /etc/hosty configs directory? y/n\n'
        read_reply
        printf '\n'

        if is_yes "$REPLY"; then
            printf 'removing hosty configs directory...\n\n'
            rm -rf /etc/hosty
        elif ! is_no "$REPLY"; then
            fail "bad answer."
        fi
    fi

    remove_legacy_cron_scripts

    previous_crontab="$WORK_DIR/crontab.previous"
    if command -v crontab > /dev/null 2>&1 &&
        crontab -l 2> /dev/null > "$previous_crontab" &&
        grep -F "$INSTALL_PATH" "$previous_crontab" > /dev/null 2>&1; then
        printf 'removing hosty from crontab...\n\n'
        new_crontab="$WORK_DIR/crontab.new"
        awk -v path="$INSTALL_PATH" 'index($0, path) == 0' "$previous_crontab" > "$new_crontab"
        crontab "$new_crontab"
    fi

    if [ -f "$INSTALL_PATH" ]; then
        printf 'uninstalling hosty...\n\n'
        rm -f "$INSTALL_PATH"
    fi

    printf 'hosty uninstalled.\n'
    exit 0
fi

user_hosts_file="$WORK_DIR/hosts.original"
user_hosts_line_number=$(awk '
    /^# [aA]d blocking hosts generated/ { marker = NR }
    END {
        if (!marker) print -1
        else print marker - 1
    }
' "$INPUT_HOSTS")

if [ "$user_hosts_line_number" -lt 0 ]; then
    if [ "$RESTORE" -eq 1 ]; then
        printf 'there is nothing to restore.\n'
        exit 0
    fi
    cat "$INPUT_HOSTS" > "$user_hosts_file"
else
    if [ "$user_hosts_line_number" -gt 0 ]; then
        head -n "$user_hosts_line_number" "$INPUT_HOSTS" > "$user_hosts_file"
    else
        : > "$user_hosts_file"
    fi

    if [ "$RESTORE" -eq 1 ]; then
        restored_hosts="$WORK_DIR/hosts.restored"
        trim_empty_lines "$user_hosts_file" > "$restored_hosts"
        install_hosts_file "$restored_hosts"
        printf '%s restore completed.\n' "$OUTPUT_HOSTS"
        exit 0
    fi
fi

if [ "$AUTORUN" -eq 1 ]; then
    check_dep crontab
    printf 'configuring autorun...\n'
    remove_legacy_cron_scripts

    if [ "$IGNORE_DEFAULT_SOURCES" -eq 1 ]; then
        hosty_command="$INSTALL_PATH -i"
        printf '\nautorunning with --ignore-default-sources...\n'
    else
        hosty_command=$INSTALL_PATH
    fi

    printf '\nhow often do you want to run hosty automatically?\n'
    printf "enter 'daily', 'weekly', 'monthly' or 'never':\n"
    read_reply

    previous_crontab="$WORK_DIR/crontab.previous"
    (crontab -l 2> /dev/null || true) > "$previous_crontab"
    new_crontab="$WORK_DIR/crontab.new"
    awk -v path="$INSTALL_PATH" 'index($0, path) == 0' "$previous_crontab" > "$new_crontab"

    case $REPLY in
        daily) printf '0 0 * * * %s\n' "$hosty_command" >> "$new_crontab" ;;
        weekly) printf '0 0 * * 0 %s\n' "$hosty_command" >> "$new_crontab" ;;
        monthly) printf '0 0 1 * * %s\n' "$hosty_command" >> "$new_crontab" ;;
        never)
            if grep -F "$INSTALL_PATH" "$previous_crontab" > /dev/null 2>&1; then
                crontab "$new_crontab"
            fi
            printf '\ndone.\n'
            exit 0
            ;;
        *) fail "bad answer." ;;
    esac

    crontab "$new_crontab"
    printf '\ndone.\n'
    exit 0
fi

blacklist_sources="$WORK_DIR/blacklist.sources"
whitelist_sources="$WORK_DIR/whitelist.sources"
blacklist_domains="$WORK_DIR/blacklist.domains"
whitelist_domains="$WORK_DIR/whitelist.domains"
: > "$blacklist_sources"
: > "$whitelist_sources"
: > "$blacklist_domains"
: > "$whitelist_domains"

if [ "$IGNORE_DEFAULT_SOURCES" -eq 0 ]; then
    printf 'downloading default sources...\n'
    download_required "$BLACKLIST_DEFAULT_SOURCE" "$blacklist_sources"
    download_required "$WHITELIST_DEFAULT_SOURCE" "$whitelist_sources"
fi

if [ -f /etc/hosty/blacklist.sources ]; then
    printf '\nadding custom blacklist sources...\n'
    cat /etc/hosty/blacklist.sources >> "$blacklist_sources"
fi

if [ -f /etc/hosty/whitelist.sources ]; then
    printf '\nadding custom whitelist sources...\n'
    cat /etc/hosty/whitelist.sources >> "$whitelist_sources"
fi

printf '\ndownloading blacklists...\n'
download_sources_into "$blacklist_sources" "$blacklist_domains"

if [ -f /etc/hosty/blacklist ]; then
    printf '\napplying user custom blacklist...\n'
    cat /etc/hosty/blacklist >> "$blacklist_domains"
fi
extract_domains "$blacklist_domains"

printf '\ndownloading whitelists...\n'
download_sources_into "$whitelist_sources" "$whitelist_domains"

if [ -f /etc/hosty/whitelist ]; then
    printf '\napplying user custom whitelist...\n'
    cat /etc/hosty/whitelist >> "$whitelist_domains"
fi

# Source URLs and existing hosts entries must never become blocked domains.
cat "$blacklist_sources" "$whitelist_sources" "$user_hosts_file" >> "$whitelist_domains"
extract_domains "$whitelist_domains"

printf '\nbuilding %s\n' "$OUTPUT_HOSTS"
final_hosts_file="$WORK_DIR/hosts.final"
trim_empty_lines "$user_hosts_file" > "$final_hosts_file"
{
    printf '\n'
    printf '# Ad blocking hosts generated %s\n' "$(date)"
    printf "%s\n" "# Don't write below this line. It will be lost if you run hosty again."
} >> "$final_hosts_file"

printf '\ncleaning and de-duplicating...\n'
awk -v ip="$BLOCK_IP" '
    FNR == NR { seen[$1] = 1; next }
    !seen[$1] { seen[$1] = 1; print ip, $1 }
' "$whitelist_domains" "$blacklist_domains" >> "$final_hosts_file"

websites_blocked=$(awk -v ip="$BLOCK_IP" '$1 == ip { count++ } END { print count + 0 }' "$final_hosts_file")
install_hosts_file "$final_hosts_file"

printf '\ndone, %s websites blocked.\n\n' "$websites_blocked"
printf 'to restore the original hosts file, run hosty -r as root.\n'
