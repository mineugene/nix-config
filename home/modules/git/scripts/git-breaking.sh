#!/usr/bin/env bash
# Find commits with conventional commit breaking changes.
# Detects the `!` marker in subjects (e.g. feat!:) and BREAKING CHANGE footers.

usage() {
    echo "Usage: git breaking <count|range>"
    echo
    echo "Find commits with conventional commit breaking changes."
    echo
    echo "Examples:"
    echo "  git breaking 20           # last 20 commits"
    echo "  git breaking main..HEAD   # commit range"
    echo "  git breaking v1.0..v2.0   # tag range"
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

case "$1" in
    *[!0-9]*) range="$1" ;;
    *) range="HEAD~$1..HEAD" ;;
esac

git log "$range" --format='%H %s' | while read -r hash subj; do
    if echo "$subj" | grep -qE '^[a-z]+(\(.+\))?!:'; then
        echo "$subj"
    elif git log -1 --format='%b' "$hash" | grep -qE '^BREAKING[ -]CHANGE:'; then
        echo "$subj"
    fi
done
