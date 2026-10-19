#!/bin/sh
# Remove tracked files that match .gitignore rules from the index.
# Shows what will be removed and prompts for confirmation.

files=$(git ls-files --cached --ignored --exclude-standard)

if [ -z "$files" ]; then
    printf '%s\n' 'No tracked files match .gitignore rules.'
    exit 0
fi

printf '%s\n\n%s\n\n' \
    'The following tracked files match .gitignore and will be removed from the index:' \
    "$files"

case ${1-} in
    -f | --force) confirmed=true ;;
    *)
        printf '%s' 'Proceed? [y/N] '
        IFS= read -r answer || answer=
        case $answer in
            y | Y) confirmed=true ;;
            *) confirmed=false ;;
        esac
        ;;
esac

if [ "$confirmed" = true ]; then
    git ls-files --cached --ignored --exclude-standard -z | xargs -0 git rm --cached
else
    printf '%s\n' 'Aborted.'
fi
