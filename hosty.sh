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
LOOKUP=0
LOOKUP_HOSTS=""
WORK_DIR=""
REPLY=""

usage() {
    cat << 'EOF_USAGE'
usage: hosty [-airdluhv]
       hosty -l <host> [<host> ...]

options:
  -a, --autorun                 set up automatic updates with crontab
  -i, --ignore-default-sources  ignore the default source lists
  -r, --restore                 restore the hosts file
  -d, --debug                   build the hosts file without changing the system
  -l, --lookup <host> ...       look up which source lists contain the given hosts
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
        l) LOOKUP=1 ;;
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
            -l | --lookup) LOOKUP=1 ;;
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
                if [ "$LOOKUP" -eq 1 ]; then
                    while [ "$#" -gt 0 ]; do
                        LOOKUP_HOSTS="$LOOKUP_HOSTS $1"
                        shift
                    done
                else
                    [ "$#" -eq 0 ] || fail "unexpected argument: $1"
                fi
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
            *)
                if [ "$LOOKUP" -eq 1 ]; then
                    LOOKUP_HOSTS="$LOOKUP_HOSTS $1"
                else
                    fail "unexpected argument: $1"
                fi
                ;;
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

# Parse hostnames from hosts-style files and plain domain lists into one-per-line output.
extract_domains_from() {
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
    ' "$1"
}

# Extract, sort, and de-duplicate domains in-place; print a count.
extract_domains() {
    extract_domains_file=$1
    extract_domains_raw="$WORK_DIR/domains.raw"
    extract_domains_sorted="$WORK_DIR/domains.sorted"

    printf '\nextracting domains...\n'
    extract_domains_from "$extract_domains_file" > "$extract_domains_raw"
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

# Extract the user portion of the hosts file (above hosty's marker).
extract_user_hosts() {
    extract_user_hosts_target=$1
    extract_user_hosts_line=$(awk '
        /^# [aA]d blocking hosts generated/ { marker = NR }
        END {
            if (!marker) print -1
            else print marker - 1
        }
    ' "$INPUT_HOSTS")
    if [ "$extract_user_hosts_line" -lt 0 ]; then
        cat "$INPUT_HOSTS" > "$extract_user_hosts_target"
    elif [ "$extract_user_hosts_line" -gt 0 ]; then
        head -n "$extract_user_hosts_line" "$INPUT_HOSTS" > "$extract_user_hosts_target"
    else
        : > "$extract_user_hosts_target"
    fi
}

parse_args "$@"

for dependency in curl awk head cat mktemp sort grep dirname chmod mv rm id date; do
    check_dep "$dependency"
done

printf '======== hosty v%s (%s) ========\n' "$VERSION" "$RELEASE_DATE"
printf '========       %s       ========\n\n' "$PROJECT_URL"

if [ "$LOOKUP" -eq 1 ]; then
    LOOKUP_HOSTS=$(printf '%s' "$LOOKUP_HOSTS" | awk '{$1=$1}1')
    [ -n "$LOOKUP_HOSTS" ] || fail "--lookup requires at least one hostname."
elif [ "$DEBUG" -eq 1 ]; then
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

# ---- Lookup mode ----
if [ "$LOOKUP" -eq 1 ]; then
    blacklist_sources="$WORK_DIR/blacklist.sources"
    whitelist_sources="$WORK_DIR/whitelist.sources"
    lookup_results="$WORK_DIR/lookup.results"
    : > "$blacklist_sources"
    : > "$whitelist_sources"
    : > "$lookup_results"

    # Detect the repo's lists/ directory next to the script.
    script_dir=$(cd "$(dirname "$0")" && pwd)
    lists_dir="$script_dir/lists"

    if [ "$IGNORE_DEFAULT_SOURCES" -eq 0 ]; then
        if [ -f "$lists_dir/blacklist.sources" ]; then
            printf 'using local sources from %s\n' "$lists_dir"
            cat "$lists_dir/blacklist.sources" > "$blacklist_sources"
            cat "$lists_dir/whitelist.sources" > "$whitelist_sources"
        else
            printf 'downloading default sources...\n'
            download_required "$BLACKLIST_DEFAULT_SOURCE" "$blacklist_sources"
            download_required "$WHITELIST_DEFAULT_SOURCE" "$whitelist_sources"
        fi
    fi

    if [ -f /etc/hosty/blacklist.sources ]; then
        printf '\nadding custom blacklist sources...\n'
        cat /etc/hosty/blacklist.sources >> "$blacklist_sources"
    fi

    if [ -f /etc/hosty/whitelist.sources ]; then
        printf '\nadding custom whitelist sources...\n'
        cat /etc/hosty/whitelist.sources >> "$whitelist_sources"
    fi

    lookup_record() {
        printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$lookup_results"
    }

    # Download a remote list, extract domains, and record matches.
    lookup_in_list() {
        lookup_list_type=$1
        lookup_list_url=$2
        lookup_list_file="$WORK_DIR/lookup_download"
        if ! download_optional "$lookup_list_url" "$lookup_list_file"; then
            return
        fi

        lookup_list_domains="$WORK_DIR/lookup_domains"
        extract_domains_from "$lookup_list_file" > "$lookup_list_domains"

        for lookup_host in $LOOKUP_HOSTS; do
            if grep -qxF "$lookup_host" "$lookup_list_domains"; then
                lookup_record "$lookup_list_type" "$lookup_host" "$lookup_list_url"
            fi
        done
    }

    # Search a local file for matching hosts.
    lookup_in_local() {
        lookup_local_type=$1
        lookup_local_file=$2
        lookup_local_domains="$WORK_DIR/lookup_local_domains"
        extract_domains_from "$lookup_local_file" > "$lookup_local_domains"
        for lookup_host in $LOOKUP_HOSTS; do
            if grep -qxF "$lookup_host" "$lookup_local_domains"; then
                lookup_record "$lookup_local_type" "$lookup_host" "$lookup_local_file"
            fi
        done
    }

    printf '\ndownloading and searching blacklists...\n'
    while IFS= read -r lookup_source_url || [ -n "$lookup_source_url" ]; do
        case $lookup_source_url in
            '' | \#*) continue ;;
        esac
        lookup_in_list "blacklist" "$lookup_source_url"
    done < "$blacklist_sources"

    if [ -f "$lists_dir/blacklist" ] && [ -s "$lists_dir/blacklist" ]; then
        printf 'searching %s...\n' "$lists_dir/blacklist"
        lookup_in_local "blacklist" "$lists_dir/blacklist"
    fi

    if [ -f /etc/hosty/blacklist ]; then
        printf 'searching user custom blacklist...\n'
        lookup_in_local "blacklist" "/etc/hosty/blacklist"
    fi

    printf 'downloading and searching whitelists...\n'
    while IFS= read -r lookup_source_url || [ -n "$lookup_source_url" ]; do
        case $lookup_source_url in
            '' | \#*) continue ;;
        esac
        lookup_in_list "whitelist" "$lookup_source_url"
    done < "$whitelist_sources"

    if [ -f "$lists_dir/whitelist" ] && [ -s "$lists_dir/whitelist" ]; then
        printf 'searching %s...\n' "$lists_dir/whitelist"
        lookup_in_local "whitelist" "$lists_dir/whitelist"
    fi

    if [ -f /etc/hosty/whitelist ]; then
        printf 'searching user custom whitelist...\n'
        lookup_in_local "whitelist" "/etc/hosty/whitelist"
    fi

    printf 'searching %s...\n' "$INPUT_HOSTS"
    lookup_user_hosts="$WORK_DIR/lookup_user_hosts"
    extract_user_hosts "$lookup_user_hosts"
    lookup_user_domains="$WORK_DIR/lookup_user_domains"
    extract_domains_from "$lookup_user_hosts" > "$lookup_user_domains"

    for lookup_host in $LOOKUP_HOSTS; do
        if grep -qxF "$lookup_host" "$lookup_user_domains"; then
            lookup_record "hosts" "$lookup_host" "$INPUT_HOSTS"
        fi
    done

    # ---- Print results ----
    printf '\n'
    awk -F'\t' -v all_hosts="$LOOKUP_HOSTS" '
    BEGIN {
        n = split(all_hosts, arr)
        for (i = 1; i <= n; i++) {
            host = arr[i]
            if (!(host in order)) {
                order[host] = ++total
                hosts[total] = host
            }
        }
    }
    {
        type = $1; host = $2; source = $3
        idx = order[host]
        if (type == "blacklist") {
            bl_count[idx]++
            bl_list[idx, bl_count[idx]] = source
        } else if (type == "whitelist") {
            wl_count[idx]++
            wl_list[idx, wl_count[idx]] = source
        } else {
            hf_count[idx]++
            hf_list[idx, hf_count[idx]] = source
        }
    }
    END {
        header = "======== lookup results ========"
        printf "%s\n", header
        for (i = 1; i <= total; i++) {
            host = hosts[i]
            bc = bl_count[i] + 0
            wc = wl_count[i] + 0
            hc = hf_count[i] + 0
            printf "\n  %s\n", host
            if (hc > 0) {
                printf "    found in hosts file:\n"
                for (j = 1; j <= hc; j++)
                    printf "      - %s\n", hf_list[i, j]
            }
            if (bc > 0) {
                printf "    found in %d %s:\n", bc, (bc == 1 ? "blacklist" : "blacklists")
                for (j = 1; j <= bc; j++)
                    printf "      - %s\n", bl_list[i, j]
            }
            if (wc > 0) {
                printf "    found in %d %s:\n", wc, (wc == 1 ? "whitelist" : "whitelists")
                for (j = 1; j <= wc; j++)
                    printf "      - %s\n", wl_list[i, j]
            }
            if (bc == 0 && wc == 0 && hc == 0)
                printf "    not found in any list.\n"
        }
        printf "\n%s\n", header
    }
    ' "$lookup_results"

    printf '\ndone.\n'
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
