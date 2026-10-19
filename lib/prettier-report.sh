#!/bin/sh
# Prettier reporter for the pre-commit hook.
#
# The hook runs with require_serial, so a single invocation sees every
# file. Prints nothing on success. On failure, prints the files that
# failed the check as a sorted list followed by prettier's fix advice.
# Raw prettier stderr, for example syntax errors, passes through
# unchanged instead of the file list.
#
# Arguments: <prettier binary> <config path> <file>...

set -u

prettier=$1
config=$2
shift 2

errors=$(mktemp) || exit 2
trap 'rm -f "$errors"' EXIT

status=0
files=$("$prettier" --list-different --config "$config" --ignore-unknown "$@" 2>"$errors") ||
    status=$?

if [ -s "$errors" ]; then
    cat "$errors" >&2
    exit "$status"
fi

if [ "$status" -ne 0 ]; then
    printf '%s\n' "$files" | LC_ALL=C sort
    printf 'Code style issues found in the above file(s). Run Prettier with --write to fix.\n'
fi

exit "$status"
