# Shared helpers for hosty CI scripts (sourced, not executed).
# shellcheck shell=sh

ROOT_TOOL=""

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    assert_contains_haystack=$1
    assert_contains_needle=$2
    assert_contains_message=${3:-"expected to find '$assert_contains_needle'"}
    printf '%s' "$assert_contains_haystack" | grep -qF -e "$assert_contains_needle" ||
        die "$assert_contains_message"
}

assert_file_contains() {
    assert_file_contains_file=$1
    assert_file_contains_needle=$2
    assert_file_contains_message=${3:-"$assert_file_contains_file should contain '$assert_file_contains_needle'"}
    [ -f "$assert_file_contains_file" ] ||
        die "$assert_file_contains_message (file missing: $assert_file_contains_file)"
    grep -qF -e "$assert_file_contains_needle" "$assert_file_contains_file" ||
        die "$assert_file_contains_message"
}

assert_file_not_contains() {
    assert_file_not_contains_file=$1
    assert_file_not_contains_needle=$2
    assert_file_not_contains_message=${3:-"$assert_file_not_contains_file should not contain '$assert_file_not_contains_needle'"}
    [ -f "$assert_file_not_contains_file" ] ||
        die "$assert_file_not_contains_message (file missing: $assert_file_not_contains_file)"
    if grep -qF -e "$assert_file_not_contains_needle" "$assert_file_not_contains_file"; then
        die "$assert_file_not_contains_message"
    fi
}

assert_eq() {
    assert_eq_actual=$1
    assert_eq_expected=$2
    assert_eq_message=${3:-"expected '$assert_eq_expected', got '$assert_eq_actual'"}
    [ "$assert_eq_actual" = "$assert_eq_expected" ] || die "$assert_eq_message"
}

assert_gt() {
    assert_gt_actual=$1
    assert_gt_minimum=$2
    assert_gt_message=${3:-"expected $assert_gt_actual > $assert_gt_minimum"}
    [ "$assert_gt_actual" -gt "$assert_gt_minimum" ] || die "$assert_gt_message"
}

# Parse "done, N websites blocked." from a log file.
blocked_count_from() {
    awk '/^done, / {
        for (i = 1; i <= NF; i++)
            if ($i ~ /^[0-9]+$/) { print $i; exit }
    }' "$1"
}

select_root_tool() {
    if [ "$(id -u)" -eq 0 ]; then
        ROOT_TOOL=""
        return 0
    fi

    for select_root_candidate in sudo doas; do
        if command -v "$select_root_candidate" > /dev/null 2>&1 &&
            "$select_root_candidate" -n true 2> /dev/null; then
            ROOT_TOOL=$select_root_candidate
            return 0
        fi
    done
    return 1
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return
    fi

    [ -n "$ROOT_TOOL" ] || select_root_tool || return 1
    "$ROOT_TOOL" "$@"
}

can_as_root() {
    select_root_tool
}

# Portable file mode bits (for example 644).
file_mode() {
    if file_mode_value=$(stat -c '%a' "$1" 2> /dev/null); then
        printf '%s\n' "$file_mode_value"
        return 0
    fi
    if file_mode_value=$(stat -f '%OLp' "$1" 2> /dev/null); then
        printf '%s\n' "$file_mode_value"
        return 0
    fi
    return 1
}

assert_mode() {
    assert_mode_file=$1
    assert_mode_expected=$2
    assert_mode_message=${3:-"$assert_mode_file should have mode $assert_mode_expected"}
    assert_mode_actual=$(file_mode "$assert_mode_file") ||
        die "$assert_mode_message (cannot stat mode)"
    case $assert_mode_actual in
        "$assert_mode_expected" | "0$assert_mode_expected") ;;
        *) die "$assert_mode_message (got $assert_mode_actual)" ;;
    esac
}

# Fail if a regular file exists under dir other than keep (both absolute paths).
assert_no_extra_files() {
    assert_no_extra_dir=$1
    assert_no_extra_keep=$2
    assert_no_extra_message=${3:-"unexpected files under $assert_no_extra_dir"}
    assert_no_extra_list=$(mktemp) || die "mktemp failed"
    find "$assert_no_extra_dir" -type f > "$assert_no_extra_list" 2> /dev/null || true
    assert_no_extra_leaked=""
    while IFS= read -r assert_no_extra_file || [ -n "$assert_no_extra_file" ]; do
        [ -n "$assert_no_extra_file" ] || continue
        [ "$assert_no_extra_file" = "$assert_no_extra_keep" ] && continue
        assert_no_extra_leaked=$assert_no_extra_file
        break
    done < "$assert_no_extra_list"
    rm -f "$assert_no_extra_list"
    [ -z "$assert_no_extra_leaked" ] ||
        die "$assert_no_extra_message: $assert_no_extra_leaked"
}

assert_no_hosty_staging() {
    assert_no_staging_message=${1:-"leftover /usr/local/bin/.hosty.* staging files"}
    for assert_no_staging_file in /usr/local/bin/.hosty.*; do
        [ -f "$assert_no_staging_file" ] || continue
        die "$assert_no_staging_message: $assert_no_staging_file"
    done
}
