# Shared helpers for hosty CI scripts (sourced, not executed).
# shellcheck shell=sh

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    haystack=$1
    needle=$2
    msg=${3:-"expected to find '$needle'"}
    printf '%s' "$haystack" | grep -qF -- "$needle" || die "$msg"
}

assert_file_contains() {
    file=$1
    needle=$2
    msg=${3:-"$file should contain '$needle'"}
    [ -f "$file" ] || die "$msg (file missing: $file)"
    grep -qF -- "$needle" "$file" || die "$msg"
}

assert_file_not_contains() {
    file=$1
    needle=$2
    msg=${3:-"$file should not contain '$needle'"}
    [ -f "$file" ] || die "$msg (file missing: $file)"
    if grep -qF -- "$needle" "$file"; then
        die "$msg"
    fi
}

assert_eq() {
    actual=$1
    expected=$2
    msg=${3:-"expected '$expected', got '$actual'"}
    [ "$actual" = "$expected" ] || die "$msg"
}

assert_gt() {
    actual=$1
    min=$2
    msg=${3:-"expected $actual > $min"}
    [ "$actual" -gt "$min" ] || die "$msg"
}

# Parse "done, N websites blocked." from a log file.
blocked_count_from() {
    awk '/^done, / {
        for (i = 1; i <= NF; i++)
            if ($i ~ /^[0-9]+$/) { print $i; exit }
    }' "$1"
}

# Run a command as root when needed.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

can_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    command -v sudo > /dev/null 2>&1 && sudo -n true 2> /dev/null
}

# Portable file mode bits (e.g. 644). GNU stat -c %a, BSD/macOS stat -f %OLp.
file_mode() {
    if _mode=$(stat -c '%a' "$1" 2> /dev/null); then
        printf '%s\n' "$_mode"
        return 0
    fi
    if _mode=$(stat -f '%OLp' "$1" 2> /dev/null); then
        printf '%s\n' "$_mode"
        return 0
    fi
    return 1
}

# Accept 644 or 0644.
assert_mode() {
    _file=$1
    _expected=$2
    _msg=${3:-"$_file should have mode $_expected"}
    _mode=$(file_mode "$_file") || die "$_msg (cannot stat mode)"
    case $_mode in
        "$_expected" | "0$_expected") ;;
        *) die "$_msg (got $_mode)" ;;
    esac
}

# Fail if any regular file under dir exists other than keep (absolute path).
assert_no_extra_files() {
    _dir=$1
    _keep=$2
    _msg=${3:-"unexpected files under $_dir"}
    _list=$(mktemp) || die "mktemp failed"
    find "$_dir" -type f > "$_list" 2> /dev/null || true
    _leaked=""
    while IFS= read -r _f || [ -n "$_f" ]; do
        [ -n "$_f" ] || continue
        [ "$_f" = "$_keep" ] && continue
        _leaked="$_f"
        break
    done < "$_list"
    rm -f "$_list"
    [ -z "$_leaked" ] || die "$_msg: $_leaked"
}

# No leftover installer staging files in /usr/local/bin.
assert_no_hosty_staging() {
    _msg=${1:-"leftover /usr/local/bin/.hosty.* staging files"}
    _list=$(mktemp) || die "mktemp failed"
    # find may need root when dir entries are root-only; redirect stays local.
    as_root find /usr/local/bin -maxdepth 1 -name '.hosty.*' > "$_list" 2> /dev/null || true
    if [ -s "$_list" ]; then
        _leaked=$(cat "$_list")
        rm -f "$_list"
        die "$_msg: $_leaked"
    fi
    rm -f "$_list"
}
