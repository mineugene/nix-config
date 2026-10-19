#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: shell-menu ACTION [WINDOW_ADDRESS]\n' >&2
    exit 2
fi

btm=${SHELL_MENU_BTM:-btm}
hyprctl=${SHELL_MENU_HYPRCTL:-hyprctl}
terminal=${SHELL_MENU_TERMINAL:-${SHELL_MENU_TERMINAL_DEFAULT:?terminal not configured}}
ui_kill=${SHELL_MENU_UI_KILL:-ui-kill}

case "$1" in
    reload-compositor|terminal|processes|force-quit|quit) ;;
    *)
        printf 'shell-menu: invalid action: %s\n' "$1" >&2
        exit 2
        ;;
esac

case "$1" in
    reload-compositor)
        "$hyprctl" reload
        ;;
    terminal)
        "$terminal"
        ;;
    force-quit)
        "$ui_kill"
        ;;
    processes)
        btm_path=$(command -v "$btm")
        "$hyprctl" dispatch \
            "hl.dsp.exec_cmd('[float; center; size 1100 720] $terminal -e $btm_path')"
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
