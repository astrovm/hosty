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
    # POSIX arithmetic comparison
    [ "$actual" -gt "$min" ] || die "$msg"
}

# Run a command as root when needed. Prefer existing root; else sudo.
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
    if command -v sudo > /dev/null 2>&1 && sudo -n true 2> /dev/null; then
        return 0
    fi
    return 1
}
