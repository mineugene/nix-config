#!/usr/bin/env bash
# Force-push the previous HEAD to the current remote branch.
# Useful for undoing a force-push. Shows what will be pushed and asks
# for confirmation before proceeding.

branch=$(git rev-parse --abbrev-ref HEAD)
prev_head=$(git rev-parse --short "HEAD@{1}" 2>/dev/null)
curr_head=$(git rev-parse --short HEAD)

if [[ -z "$prev_head" ]]; then
    echo "No previous HEAD found in reflog." >&2
    exit 1
fi

echo "Branch:       $branch"
echo "Current HEAD: $curr_head"
echo "Will push:    $prev_head (HEAD@{1})"
echo
echo "This will force-push (--force-with-lease) to origin/$branch."
echo

read -rp "Proceed? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    git push --force-with-lease origin "HEAD@{1}:$branch"
else
    echo "Aborted."
fi
