#!/bin/sh
# Show commits on the current branch that are not on the remote default branch.
# Automatically detects the remote default branch (main, master, etc.).

remote=${1:-origin}

default_branch=$(git symbolic-ref "refs/remotes/${remote}/HEAD" 2>/dev/null | sed 's|refs/remotes/||')

if [ -z "$default_branch" ]; then
    printf "Could not detect default branch for remote '%s'.\n" "$remote" >&2
    printf 'Try: git remote set-head %s --auto\n' "$remote" >&2
    exit 1
fi

git log --oneline --no-merges HEAD --not "$default_branch"
