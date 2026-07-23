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
REPLY=""

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
            --*) fail "unrecognized option: $1" ;;
            -?*)
                parse_options=${1#-}
                while [ -n "$parse_options" ]; do
                    parse_option=${parse_options%"${parse_options#?}"}
                    parse_options=${parse_options#?}
                    set_short_option "$parse_option"
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
    if (: < /dev/tty) 2> /dev/null && IFS= read -r REPLY < /dev/tty; then
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
    for remove_cron_period in daily weekly monthly; do
        remove_cron_file="/etc/cron.$remove_cron_period/hosty"
        if [ -f "$remove_cron_file" ]; then
            printf 'removing %s...\n\n' "$remove_cron_file"
            rm -f "$remove_cron_file"
        fi
    done
}

# Stage complete content first. Prefer an in-place write for an existing file to
# preserve ownership and metadata; fall back to rename when needed.
install_hosts_file() {
    install_hosts_source=$1
    install_hosts_destination=$OUTPUT_HOSTS
    install_hosts_directory=$(dirname "$install_hosts_destination")
    install_hosts_staged=$(mktemp "$install_hosts_directory/.hosty.XXXXXX" 2> /dev/null) ||
        install_hosts_staged=$(mktemp) || exit 1

    cat "$install_hosts_source" > "$install_hosts_staged"

    if [ -f "$install_hosts_destination" ] &&
        cat "$install_hosts_staged" > "$install_hosts_destination" 2> /dev/null; then
        chmod 644 "$install_hosts_destination" 2> /dev/null || true
        rm -f "$install_hosts_staged"
        return 0
    fi

    if chmod 644 "$install_hosts_staged" 2> /dev/null &&
        mv -f "$install_hosts_staged" "$install_hosts_destination" 2> /dev/null; then
        return 0
    fi

    # A busy mount may reject rename while still permitting an in-place write.
    if cat "$install_hosts_staged" > "$install_hosts_destination" 2> /dev/null; then
        chmod 644 "$install_hosts_destination" 2> /dev/null || true
        rm -f "$install_hosts_staged"
        return 0
    fi

    fail "failed to write $install_hosts_destination; recovery copy kept at $install_hosts_staged"
}

download_required() {
    download_required_url=$1
    download_required_target=$2
    printf 'downloading %s\n' "$download_required_url"
    if ! curl -fsSL --retry 3 -o "$download_required_target" "$download_required_url"; then
        fail "error downloading $download_required_url"
    fi
}

download_optional() {
    download_optional_url=$1
    download_optional_target=$2
    printf 'downloading %s\n' "$download_optional_url"
    if ! curl -fsSL --retry 1 --max-time 10 -o "$download_optional_target" "$download_optional_url"; then
        printf 'error downloading %s\n' "$download_optional_url" >&2
        rm -f "$download_optional_target"
        return 1
    fi
}

download_sources_into() {
    download_sources_file=$1
    download_sources_target=$2
    download_sources_temp="$WORK_DIR/download"

    while IFS= read -r download_sources_url || [ -n "$download_sources_url" ]; do
        case $download_sources_url in
            '' | \#*) continue ;;
        esac
        if download_optional "$download_sources_url" "$download_sources_temp"; then
            cat "$download_sources_temp" >> "$download_sources_target"
        fi
    done < "$download_sources_file"
}

# Extract hostnames from hosts-style files and plain domain lists.
extract_domains() {
    extract_domains_file=$1
    extract_domains_raw="$WORK_DIR/domains.raw"
    extract_domains_sorted="$WORK_DIR/domains.sorted"

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
    ' "$extract_domains_file" > "$extract_domains_raw"
    sort -u "$extract_domains_raw" > "$extract_domains_sorted"
    cat "$extract_domains_sorted" > "$extract_domains_file"
    extract_domains_count=$(awk 'END { print NR + 0 }' "$extract_domains_file")
    printf '%s domains extracted.\n' "$extract_domains_count"
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

append_blocked_domains() {
    append_blocked_allow_file=$1
    append_blocked_deny_file=$2
    append_blocked_output=$3

    awk -v ip="$BLOCK_IP" -v allow_file="$append_blocked_allow_file" '
        BEGIN {
            while ((getline domain < allow_file) > 0)
                seen[domain] = 1
            close(allow_file)
        }
        !seen[$1] {
            seen[$1] = 1
            print ip, $1
        }
    ' "$append_blocked_deny_file" >> "$append_blocked_output"
}

parse_args "$@"

for dependency in curl awk head cat mktemp sort grep dirname chmod mv rm id date; do
    check_dep "$dependency"
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
        grep -F -e "$INSTALL_PATH" "$previous_crontab" > /dev/null 2>&1; then
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
            if grep -F -e "$INSTALL_PATH" "$previous_crontab" > /dev/null 2>&1; then
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
append_blocked_domains "$whitelist_domains" "$blacklist_domains" "$final_hosts_file"

websites_blocked=$(awk -v ip="$BLOCK_IP" '$1 == ip { count++ } END { print count + 0 }' "$final_hosts_file")
install_hosts_file "$final_hosts_file"

printf '\ndone, %s websites blocked.\n\n' "$websites_blocked"
printf 'to restore the original hosts file, run hosty -r as root.\n'
