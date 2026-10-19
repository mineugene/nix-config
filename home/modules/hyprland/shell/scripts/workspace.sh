#!/bin/sh
set -u

if [ "$#" -ne 1 ]; then
    printf 'usage: shell-workspace 1..9\n' >&2
    exit 2
fi

# Hyprland 0.56 evaluates dispatch arguments as Lua, so the shell-word form
# parses as an expression and fails; a dispatcher object is required.
case $1 in
    [1-9]) exec hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" ;;
    *)
        printf 'shell-workspace: invalid workspace: %s\n' "$1" >&2
        exit 2
        ;;
esac
