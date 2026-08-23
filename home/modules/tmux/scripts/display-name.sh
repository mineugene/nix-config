#!/bin/sh
set -u

window_name=${1-}
pane_path=${2-}

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
