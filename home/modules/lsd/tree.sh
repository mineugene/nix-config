#!/bin/sh
set -eu

ignore=$(git -C "${LSD_TREE_DIRECTORY:-.}" rev-parse --show-toplevel 2>/dev/null || :)/.gitignore
set -- --tree --depth=3 --blocks=date,size,name "$@"
if [ -f "$ignore" ]; then
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        case $pattern in
            ''|'#'*) continue ;;
        esac
        set -- "$@" "--ignore-glob=$pattern"
    done < "$ignore"
fi
exec lsd "$@"
