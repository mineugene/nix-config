#!/bin/sh
# shellcheck disable=SC2016
set -eu
: "${unitFile:?}" "${loginGuardFile:?}" "${out:?}"

# The instance drop-in must reset the inherited exec line, then set exactly one
# autologin command. Two ExecStart lines that are not a reset plus one command
# would let systemd run the plain getty as well.
exec_lines=$(grep -c '^ExecStart=' "$unitFile")
test "$exec_lines" -eq 2
test "$(grep '^ExecStart=' "$unitFile" | head -n 1)" = "ExecStart="
autologin_line=$(grep '^ExecStart=' "$unitFile" | tail -n 1)
case "$autologin_line" in
    *--autologin\ autologin-check*) ;;
    *)
        echo "getty instance does not autologin the configured user: $autologin_line" >&2
        exit 1
        ;;
esac
case "$autologin_line" in
    *--login-program*) ;;
    *)
        echo "getty instance dropped agetty's login program: $autologin_line" >&2
        exit 1
        ;;
esac
case "$autologin_line" in
    *'%I'*) ;;
    *)
        echo "getty instance does not stay bound to its instance terminal: $autologin_line" >&2
        exit 1
        ;;
esac

grep -Fq 'WAYLAND_DISPLAY' "$loginGuardFile"
grep -Fq '[ "$(tty)" = "/dev/tty1" ]' "$loginGuardFile"
grep -Fq 'exec uwsm start -e -D Hyprland hyprland.desktop' "$loginGuardFile"

touch "$out"