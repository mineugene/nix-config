#!/bin/sh
# Sourced from the login shell. Start the compositor only on the autologin
# terminal, and never from a nested shell or an SSH session that already has a
# Wayland display.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/@tty@" ]; then
    exec uwsm start -e -D Hyprland hyprland.desktop
fi