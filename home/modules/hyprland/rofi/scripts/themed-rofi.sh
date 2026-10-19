#!/bin/sh

resolve_rofi_theme() {
    rofi_config_home=${XDG_CONFIG_HOME:-${HOME:?HOME must be set}/.config}
    rofi_mode=$("$2" get 2>/dev/null) || rofi_mode=dark
    case $rofi_mode in
        dark | light) ;;
        *) rofi_mode=dark ;;
    esac
    ROFI_MONITOR=$("$3" primary 2>/dev/null) || ROFI_MONITOR=
    ROFI_MONITOR=${ROFI_MONITOR:--1}
    # shellcheck disable=SC2034
    ROFI_THEME="$rofi_config_home/rofi/themes/$1-$rofi_mode.rasi"
}
