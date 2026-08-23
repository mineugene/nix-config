#!/bin/sh
set -u

state_file=${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch/active
[ -s "$state_file" ] || exit 0
reason=$(cat "$state_file" 2>/dev/null) || exit 0
[ -n "$reason" ] || exit 0
# Chip mirrors the starship prompt badge: rounded powerline caps (U+E0B6/U+E0B4,
# emitted as octal escapes for POSIX printf) transition base -> overlay -> base,
# sakura text on overlay, like [custom.yubikey_touch].
printf '#[fg=#0c0e14,bg=#1a1b26]\356\202\266#[fg=#f7768e,bg=#0c0e14,blink] YK %s #[fg=#0c0e14,bg=#1a1b26]\356\202\264#[default,noblink] ' "$reason"
