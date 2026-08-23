#!/usr/bin/env bash
# Remove tracked files that match .gitignore rules from the index.
# Shows what will be removed and prompts for confirmation.

files=$(git ls-files --cached --ignored --exclude-standard)

if [[ -z "$files" ]]; then
    echo "No tracked files match .gitignore rules."
    exit 0
fi

echo "The following tracked files match .gitignore and will be removed from the index:"
echo
echo "$files"
echo

if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    confirmed=true
else
    read -rp "Proceed? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] && confirmed=true || confirmed=false
fi

if [[ "$confirmed" == true ]]; then
    git ls-files --cached --ignored --exclude-standard -z | xargs -0 git rm --cached
else
    echo "Aborted."
fi
