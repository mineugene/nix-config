#!/bin/sh
set -u

window_name=${1-}
pane_path=${2-}

if [ "${3-}" = title ]; then
    full_path=$pane_path
    if [ -n "${HOME:-}" ]; then
        case $full_path in
            "$HOME") full_path='~' ;;
            "$HOME"/*) full_path="~${full_path#"$HOME"}" ;;
        esac
    fi
    printf '%s %s' "$window_name" "$full_path"
    exit
fi

if [ "$window_name" = zsh ]; then
    name=$(shorten-path "$pane_path")
else
    name=$window_name
fi

if [ "${#name}" -gt 32 ]; then
    while [ "${#name}" -gt 29 ]; do
        name=${name#?}
    done
    printf '...%s' "$name"
else
    printf '%s' "$name"
fi
