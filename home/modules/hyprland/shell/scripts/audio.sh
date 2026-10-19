#!/bin/sh
set -u

wpctl=${SHELL_AUDIO_WPCTL:-wpctl}

valid_number() {
    awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/) }'
}

valid_percentage() {
    valid_number "$1" && awk -v value="$1" 'BEGIN { exit !(value >= 0 && value <= 100) }'
}

set_volume() {
    target=$1
    value=$2
    valid_percentage "$value" || return 2
    "$wpctl" set-volume -l 1 "$target" "${value}%"
}

set_default() {
    case $1 in
        '' | *[!0-9]*) return 2 ;;
    esac
    "$wpctl" set-default "$1"
}

export LC_ALL=C

case ${1-} in
    toggle-sink)
        [ "$#" -eq 1 ] || exit 2
        "$wpctl" set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    toggle-source)
        [ "$#" -eq 1 ] || exit 2
        "$wpctl" set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    change-sink)
        [ "$#" -eq 2 ] || exit 2
        case $2 in
            up) "$wpctl" set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
            down) "$wpctl" set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
            *) exit 2 ;;
        esac
        ;;
    change-source)
        [ "$#" -eq 2 ] || exit 2
        case $2 in
            up) "$wpctl" set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+ ;;
            down) "$wpctl" set-volume @DEFAULT_AUDIO_SOURCE@ 5%- ;;
            *) exit 2 ;;
        esac
        ;;
    set-sink)
        [ "$#" -eq 2 ] || exit 2
        set_volume @DEFAULT_AUDIO_SINK@ "$2"
        ;;
    set-source)
        [ "$#" -eq 2 ] || exit 2
        set_volume @DEFAULT_AUDIO_SOURCE@ "$2"
        ;;
    set-default)
        [ "$#" -eq 2 ] || exit 2
        set_default "$2"
        ;;
    *)
        printf 'usage: shell-audio toggle-sink|toggle-source | change-sink|change-source up|down | set-sink|set-source 0..100 | set-default <node-id>\n' >&2
        exit 2
        ;;
esac