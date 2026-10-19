#!/bin/sh
# Force-push the previous HEAD to the current remote branch.
# Useful for undoing a force-push. Shows what will be pushed and asks
# for confirmation before proceeding.

branch=$(git rev-parse --abbrev-ref HEAD)
prev_head=$(git rev-parse --short 'HEAD@{1}' 2>/dev/null)
curr_head=$(git rev-parse --short HEAD)

if [ -z "$prev_head" ]; then
    printf '%s\n' 'No previous HEAD found in reflog.' >&2
    exit 1
fi

printf 'Branch:       %s\nCurrent HEAD: %s\nWill push:    %s (HEAD@{1})\n\n' \
    "$branch" "$curr_head" "$prev_head"
printf 'This will force-push (--force-with-lease) to origin/%s.\n\n' "$branch"
printf '%s' 'Proceed? [y/N] '
IFS= read -r answer || answer=

case $answer in
    y | Y) git push --force-with-lease origin "HEAD@{1}:$branch" ;;
    *) printf '%s\n' 'Aborted.' ;;
esac
