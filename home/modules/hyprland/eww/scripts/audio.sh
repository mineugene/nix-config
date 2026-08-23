wpctl=${EWW_AUDIO_WPCTL:-wpctl}

stream_status() {
    local target line muted volume percent description

    target=$1
    if ! line=$("$wpctl" get-volume "$target" 2>/dev/null); then
        printf '{"available":false,"muted":false,"volume":0,"description":"Unavailable"}'
        return
    fi

    muted=false
    [[ $line == *"[MUTED]"* ]] && muted=true
    volume=${line#Volume: }
    volume=${volume%% *}
    if [[ ! $volume =~ ^[0-9]+([.][0-9]+)?$ ]]; then
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

status() {
    local sink source

    sink=$(stream_status @DEFAULT_AUDIO_SINK@)
    source=$(stream_status @DEFAULT_AUDIO_SOURCE@)
    jq -nc --argjson sink "$sink" --argjson source "$source" \
        '{available: $sink.available, sink: $sink, source: $source}'
}

set_volume() {
    local target value

    target=$1
    value=$2
    if [[ ! $value =~ ^[0-9]+([.][0-9]+)?$ ]] || (( $(awk -v value="$value" 'BEGIN { print value < 0 || value > 100 }') )); then
        return 2
    fi
    exec "$wpctl" set-volume -l 1 "$target" "${value}%"
}

export LC_ALL=C

case ${1-} in
    status)
        (( $# == 1 )) || exit 2
        status
        ;;
    toggle-sink)
        (( $# == 1 )) || exit 2
        exec "$wpctl" set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    toggle-source)
        (( $# == 1 )) || exit 2
        exec "$wpctl" set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    change-sink)
        (( $# == 2 )) || exit 2
        case $2 in
            up) exec "$wpctl" set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
            down) exec "$wpctl" set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
            *) exit 2 ;;
        esac
        ;;
    set-sink)
        (( $# == 2 )) || exit 2
        set_volume @DEFAULT_AUDIO_SINK@ "$2"
        ;;
    set-source)
        (( $# == 2 )) || exit 2
        set_volume @DEFAULT_AUDIO_SOURCE@ "$2"
        ;;
    *)
        printf 'usage: eww-audio status | toggle-sink|toggle-source | change-sink up|down | set-sink|set-source 0..100\n' >&2
        exit 2
        ;;
esac
