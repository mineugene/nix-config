#!/bin/sh
set -u

wpctl=${EWW_AUDIO_WPCTL:-wpctl}
eww=${EWW_AUDIO_EWW:-eww}
pwdump=${EWW_AUDIO_PWDUMP:-pw-dump}

show_volume() {
    "$eww" update audio_volume_visible=true >/dev/null 2>&1 || true
    (sleep 3; "$eww" update audio_volume_visible=false >/dev/null 2>&1 || true) &
}

valid_number() {
    awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/) }'
}

valid_percentage() {
    valid_number "$1" && awk -v value="$1" 'BEGIN { exit !(value >= 0 && value <= 100) }'
}

stream_status() {
    target=$1
    if ! line=$("$wpctl" get-volume "$target" 2>/dev/null); then
        printf '{"available":false,"muted":false,"volume":0,"description":"Unavailable"}'
        return
    fi

    muted=false
    case $line in
        *"[MUTED]"*) muted=true ;;
    esac
    volume=${line#Volume: }
    volume=${volume%% *}
    if ! valid_number "$volume"; then
        printf '{"available":false,"muted":false,"volume":0,"description":"Unavailable"}'
        return
    fi

    percent=$(awk -v value="$volume" 'BEGIN { printf "%d", (value * 100) + 0.5 }')
    description=$("$wpctl" inspect "$target" 2>/dev/null | awk -F '"' '/node.description =/ { print $2; exit }')
    jq -nc \
        --arg description "${description:-Default audio device}" \
        --argjson muted "$muted" \
        --argjson volume "$percent" \
        '{available: true, muted: $muted, volume: $volume, description: $description}'
}

# An application holding the microphone open is a capture stream in the running
# state; a stream that merely exists is not listening, and the device node is
# not enough either, since it runs for any client at all.
capture_status() {
    if ! graph=$("$pwdump" 2>/dev/null); then
        printf '{"active":false,"clients":[]}'
        return
    fi

    printf '%s' "$graph" | jq -c '
        [ .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["media.class"] == "Stream/Input/Audio")
        | select(.info.state == "running")
        | .info.props["application.name"] // .info.props["node.name"] // "An application"
        ] | unique
        | {active: (length > 0), clients: .}
    ' 2>/dev/null || printf '{"active":false,"clients":[]}'
}

status() {
    sink=$(stream_status @DEFAULT_AUDIO_SINK@)
    source=$(stream_status @DEFAULT_AUDIO_SOURCE@)
    capture=$(capture_status)
    jq -nc --argjson sink "$sink" --argjson source "$source" --argjson capture "$capture" \
        '{available: $sink.available, sink: $sink,
          source: ($source + {active: $capture.active, clients: $capture.clients})}'
}

set_volume() {
    target=$1
    value=$2
    valid_percentage "$value" || return 2
    "$wpctl" set-volume -l 1 "$target" "${value}%"
    show_volume
}

export LC_ALL=C

case ${1-} in
    status)
        [ "$#" -eq 1 ] || exit 2
        status
        ;;
    toggle-sink)
        [ "$#" -eq 1 ] || exit 2
        "$wpctl" set-mute @DEFAULT_AUDIO_SINK@ toggle
        show_volume
        ;;
    toggle-source)
        [ "$#" -eq 1 ] || exit 2
        "$wpctl" set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        show_volume
        ;;
    change-sink)
        [ "$#" -eq 2 ] || exit 2
        case $2 in
            up) "$wpctl" set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+; show_volume ;;
            down) "$wpctl" set-volume @DEFAULT_AUDIO_SINK@ 5%-; show_volume ;;
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
    *)
        printf 'usage: eww-audio status | toggle-sink|toggle-source | change-sink up|down | set-sink|set-source 0..100\n' >&2
        exit 2
        ;;
esac
