#!/bin/sh
# Shorten a path to last 2 parent dirs + basename, with ellipsis if truncated.
# If inside a git repo, show the path from the repo root instead.
path=$1
if [ -n "${HOME:-}" ]; then
    case $path in
        "$HOME") path='~' ;;
        "$HOME"/*) path="~${path#"$HOME"}" ;;
    esac
fi

# Check if inside a git repo
git_root=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$git_root" ]; then
    repo_name=$(basename "$git_root")
    rel=$(realpath --relative-to="$git_root" "$1" 2>/dev/null)
    if [ "$rel" = "." ]; then
        echo "$repo_name"
    else
        echo "$repo_name/$rel"
    fi
    exit
fi

case $path in
    */*/*/*)
        basename=${path##*/}
        parents=${path%/*}
        parent=${parents##*/}
        parents=${parents%/*}
        grandparent=${parents##*/}
        printf '…/%s/%s/%s\n' "$grandparent" "$parent" "$basename"
        ;;
    *)
        printf '%s\n' "$path"
        ;;
esac
