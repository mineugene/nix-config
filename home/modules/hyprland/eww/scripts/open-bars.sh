#!/bin/sh
# Opens the primary bar, and the reduced secondary bar when a second monitor is
# connected. Opening a window for an absent monitor fails, so the secondary is
# gated on the compositor's monitor count rather than attempted blindly.
set -eu

eww --no-daemonize open bar

monitor_count=$(hyprctl -j monitors 2>/dev/null | jq 'length' 2>/dev/null || echo 1)

if [ "$monitor_count" -gt 1 ]; then
    eww --no-daemonize open bar-secondary
fi
