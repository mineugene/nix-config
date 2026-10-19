#!/bin/sh
set -eu

# Reloads the running Hyprland instance when the generated configuration
# changes. HYPRLAND_INSTANCE_SIGNATURE is absent from the activation
# environment, so the live instance is discovered through hyprctl.
runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-activation
stamp_file=$state_dir/reloaded

# Any of these files can change without the others, so the whole set is the
# fingerprint of the Hyprland configuration.
fingerprint=$(
    for file in hyprland.lua bindings.lua monitors.lua generated/monitor.lua generated/programs.lua; do
        readlink -f "$HOME/.config/hypr/$file" 2>/dev/null || true
    done
)
[ -n "$fingerprint" ] || exit 0
[ -d "$runtime_dir/hypr" ] || exit 0
[ "$fingerprint" != "$(cat "$stamp_file" 2>/dev/null || true)" ] || exit 0

instance=$(
    XDG_RUNTIME_DIR="$runtime_dir" hyprctl instances -j 2>/dev/null \
        | jq -r '.[0].instance // empty' 2>/dev/null \
        || true
)
[ -n "$instance" ] || exit 0

mkdir -p "$state_dir" || exit 0
if XDG_RUNTIME_DIR="$runtime_dir" hyprctl --instance "$instance" reload; then
    printf '%s\n' "$fingerprint" > "$stamp_file" || true
fi

# Activation must not fail because a desktop session is absent or unwilling.
exit 0