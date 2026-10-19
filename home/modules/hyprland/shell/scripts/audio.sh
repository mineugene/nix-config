#!/bin/sh
set -u

wpctl=${SHELL_AUDIO_WPCTL:-wpctl}
pw_metadata=${SHELL_AUDIO_PW_METADATA:-pw-metadata}
pw_dump=${SHELL_AUDIO_PW_DUMP:-pw-dump}
pactl=${SHELL_AUDIO_PACTL:-pactl}

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
    capture-target)
        [ "$#" -ge 3 ] || exit 2
        target=$2
        shift 2
        metadata_target=$target
        if [ "$target" != -1 ]; then
            metadata_target=$($pw_dump | jq -r --arg target "$target" '.[] | select(.type == "PipeWire:Interface:Node") | select(.info.props["node.name"] == $target) | .info.props["object.serial"] // empty' | head -n 1)
            [ -n "$metadata_target" ] || exit 1
        fi
        for stream in "$@"; do
            case $stream in
                '' | *[!0-9]*) exit 2 ;;
            esac
        done
        for stream in "$@"; do
            "$pw_metadata" -n default -- "$stream" target.object "$metadata_target" Spa:Id
        done
        if [ "$target" = -1 ]; then
            default_source=$($pw_metadata -n default | awk -F"value:'" '/id:0 key:'\''default.audio.source'\''/ { split($2, value, "'\''"); print value[1] }' | jq -r '.name // empty')
            for stream in "$@"; do
                serial=$($pw_dump | jq -r --argjson stream "$stream" '.[] | select(.type == "PipeWire:Interface:Node" and .id == $stream) | .info.props["object.serial"] // empty')
                if [ -n "$default_source" ] && [ -n "$serial" ]; then
                    "$pactl" move-source-output "$serial" "$default_source"
                fi
                "$pw_metadata" -n default -- "$stream" target.object -1 Spa:Id
            done
        fi
        ;;
    *)
        printf 'usage: shell-audio toggle-sink|toggle-source | change-sink|change-source up|down | set-sink|set-source 0..100 | set-default <node-id> | capture-target <node-name|-1> <stream-id>...\n' >&2
        exit 2
        ;;
esac