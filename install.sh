#!/bin/sh

set -euf

HOSTY_URL=${HOSTY_URL:-https://4st.li/hosty/hosty.sh}
DEST_DIR=/usr/local/bin
DEST="$DEST_DIR/hosty"
PRIVILEGE_TOOL=""
DOWNLOAD_TMP=""
STAGED_TMP=""
HOSTY_VERSION=""

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

check_dep() {
    command -v "$1" > /dev/null 2>&1 || fail "installer requires '$1', but it is not installed."
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

has_terminal() {
    (: < /dev/tty) 2> /dev/null
}

privilege_tool_works() {
    privilege_tool_works_command=$1

    if "$privilege_tool_works_command" -n true 2> /dev/null; then
        return 0
    fi

    has_terminal || return 1
    "$privilege_tool_works_command" true < /dev/tty
}

select_privilege_tool() {
    for select_privilege_candidate in sudo doas; do
        command -v "$select_privilege_candidate" > /dev/null 2>&1 || continue
        if privilege_tool_works "$select_privilege_candidate"; then
            PRIVILEGE_TOOL=$select_privilege_candidate
            return 0
        fi
    done
    return 1
}

is_version() {
    is_version_value=$1
    is_version_major=${is_version_value%%.*}
    is_version_rest=${is_version_value#*.}
    [ "$is_version_rest" != "$is_version_value" ] || return 1

    is_version_minor=${is_version_rest%%.*}
    is_version_patch=${is_version_rest#*.}
    [ "$is_version_patch" != "$is_version_rest" ] || return 1

    case $is_version_patch in
        *.*) return 1 ;;
    esac

    for is_version_part in "$is_version_major" "$is_version_minor" "$is_version_patch"; do
        case $is_version_part in
            '' | *[!0-9]*) return 1 ;;
        esac
    done
}

validate_hosty() {
    validate_hosty_file=$1

    if ! validate_hosty_version=$("$validate_hosty_file" -v 2> /dev/null) ||
        ! is_version "$validate_hosty_version"; then
        return 1
    fi

    if ! validate_hosty_help=$("$validate_hosty_file" -h 2> /dev/null); then
        return 1
    fi
    case $validate_hosty_help in
        *"usage: hosty"*) ;;
        *) return 1 ;;
    esac

    HOSTY_VERSION=$validate_hosty_version
}

run_privileged() {
    if [ -n "$PRIVILEGE_TOOL" ]; then
        "$PRIVILEGE_TOOL" "$@"
    else
        "$@"
    fi
}

cleanup() {
    if [ -n "$DOWNLOAD_TMP" ]; then
        rm -f "$DOWNLOAD_TMP"
    fi
    if [ -n "$STAGED_TMP" ]; then
        run_privileged rm -f "$STAGED_TMP" 2> /dev/null || true
    fi
}

for dependency in curl mktemp cp chmod id mkdir mv rm; do
    check_dep "$dependency"
done

printf '======== welcome to hosty installer ========\n'
printf '========        4st.li/hosty        ========\n\n'

if [ "$(id -u)" -ne 0 ]; then
    select_privilege_tool ||
        fail "run this installer as root, or configure sudo or doas for this account."
    printf 'using %s for privileged operations.\n' "$PRIVILEGE_TOOL"
else
    printf 'running as root.\n'
fi

DOWNLOAD_TMP=$(mktemp) || exit 1
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

printf '\ndownloading hosty...\n'
case $HOSTY_URL in
    https://* | file://*)
        curl -fsSL --retry 3 -o "$DOWNLOAD_TMP" "$HOSTY_URL"
        ;;
    *://*)
        fail "HOSTY_URL must be https://, file://, or a local path."
        ;;
    *)
        cp "$HOSTY_URL" "$DOWNLOAD_TMP"
        ;;
esac

chmod 755 "$DOWNLOAD_TMP"
validate_hosty "$DOWNLOAD_TMP" || fail "staged file does not look like a working hosty executable."

printf '\ninstalling hosty...\n'
run_privileged mkdir -p "$DEST_DIR"
STAGED_TMP=$(run_privileged mktemp "$DEST_DIR/.hosty.XXXXXX") || exit 1
run_privileged cp "$DOWNLOAD_TMP" "$STAGED_TMP"
run_privileged chmod 755 "$STAGED_TMP"
run_privileged mv -f "$STAGED_TMP" "$DEST"
STAGED_TMP=""

printf 'installed hosty v%s\n\n' "$HOSTY_VERSION"

if command -v crontab > /dev/null 2>&1; then
    if has_terminal; then
        printf 'configure automatic hosts-file updates now? y/n\n'
        IFS= read -r answer < /dev/tty || fail "failed to read input."
        printf '\n'

        if is_yes "$answer"; then
            run_privileged "$DEST" -a < /dev/tty
        elif ! is_no "$answer"; then
            fail "bad answer."
        fi
    else
        printf 'no terminal available; run hosty -a as root to configure automatic updates.\n'
    fi
fi

trap - 0 INT TERM
rm -f "$DOWNLOAD_TMP"
DOWNLOAD_TMP=""
printf 'done.\n'