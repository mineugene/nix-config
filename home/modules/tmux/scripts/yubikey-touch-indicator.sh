#!/bin/sh
set -u

state_file=${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch/active
[ -s "$state_file" ] || exit 0
reason=$(cat "$state_file" 2>/dev/null) || exit 0
[ -n "$reason" ] || exit 0
printf '#[fg=#f7768e,bg=#1a1b26,blink]#[fg=#f7768e,bg=#1a1b26,reverse,blink] TOUCH YK %s #[noreverse]#[fg=#f7768e,bg=#1a1b26,blink]#[default,noblink] ' "$reason"
