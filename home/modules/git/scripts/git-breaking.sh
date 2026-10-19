#!/bin/sh
# Find commits with conventional commit breaking changes.
# Detects the `!` marker in subjects (e.g. feat!:) and BREAKING CHANGE footers.

usage() {
    printf '%s\n' \
        'Usage: git breaking <count|range>' \
        '' \
        'Find commits with conventional commit breaking changes.' \
        '' \
        'Examples:' \
        '  git breaking 20           # last 20 commits' \
        '  git breaking main..HEAD   # commit range' \
        '  git breaking v1.0..v2.0   # tag range'
}

if [ "$#" -ne 1 ] || [ "$1" = -h ] || [ "$1" = --help ]; then
    usage
    exit 0
fi

case $1 in
    *[!0-9]*) range=$1 ;;
    *) range="HEAD~$1..HEAD" ;;
esac

git log "$range" --format='%H %s' | while IFS=' ' read -r hash subj; do
    if printf '%s\n' "$subj" | grep -qE '^[a-z]+(\(.+\))?!:'; then
        printf '%s\n' "$subj"
    elif git log -1 --format='%b' "$hash" | grep -qE '^BREAKING[ -]CHANGE:'; then
        printf '%s\n' "$subj"
    fi
done
