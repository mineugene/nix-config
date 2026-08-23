#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: eww-menu ACTION [WINDOW_ADDRESS]\n' >&2
    exit 2
fi

btop=${EWW_MENU_BTOP:-btop}
eww=${EWW_MENU_EWW:-eww}
hyprctl=${EWW_MENU_HYPRCTL:-hyprctl}
terminal=${EWW_MENU_TERMINAL:-${EWW_MENU_TERMINAL_DEFAULT:?terminal not configured}}

case "$1" in
    reload-compositor|terminal|force-quit|quit) ;;
    *)
        printf 'eww-menu: invalid action: %s\n' "$1" >&2
        exit 2
        ;;
esac

"$eww" close menu

case "$1" in
    reload-compositor)
        "$hyprctl" reload
        ;;
    terminal)
        "$terminal"
        ;;
    force-quit)
        btop_path=$(command -v "$btop")
        "$hyprctl" dispatch \
            "hl.dsp.exec_cmd('[float; center; size 1100 720] $terminal -e $btop_path')"
        ;;
    quit)
        # Closing the menu can leave the compositor with no active window, so
        # killactive has nothing to act on. The bar already knows which window
        # the label named, so close that one by address and fall back only when
        # no address was supplied.
        if [ -n "${2-}" ]; then
            "$hyprctl" dispatch "hl.dsp.window.close({ address = '$2' })"
        else
            "$hyprctl" dispatch "hl.dsp.window.close()"
        fi
        ;;
esac
