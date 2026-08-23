#!/bin/sh
set -u

# A separate reader lets timeout bound a POSIX read without losing parent state.
if [ "${1-}" = __read-event ]; then
    IFS= read -r event || exit 1
    printf '%s\n' "$event"
    exit
fi

wpctl=${EWW_AUDIO_WPCTL:-wpctl}
pwdump=${EWW_AUDIO_PWDUMP:-pw-dump}
pactl=${EWW_AUDIO_PACTL:-pactl}
curl_cmd=${EWW_AUDIO_CURL:-curl}
# Wired at build time from mine.desktop.audio.monitorOutputs; the empty
# default degrades the monitor commands to an unavailable response.
monitor_outputs=${EWW_AUDIO_MONITOR_OUTPUTS:-[]}

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
    description=${2-}
    if [ -z "$description" ]; then
        description=$("$wpctl" inspect "$target" 2>/dev/null | awk -F '"' '/node.description =/ { print $2; exit }')
    fi
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

device_status() {
    if ! "$wpctl" status 2>/dev/null | awk '
        /Sinks:/ { section = "outputs"; next }
        /Sources:/ { section = "inputs"; next }
        /Filters:/ { section = ""; next }
        section && match($0, /([0-9]+)[.] (.*) \[vol:/, entry) {
            printf "%s\\t%s\\t%s\\t%s\\n", section, entry[1], entry[2], ($0 ~ /\*/)
        }
    ' | jq -Rsc '
        split("\\n") | map(select(length > 0) | split("\\t"))
        | map({kind: .[0], id: (.[1] | tonumber), label: .[2], active: (.[3] == "1")})
        | {outputs: map(select(.kind == "outputs")), inputs: map(select(.kind == "inputs"))}
    ';
    then
        printf '{"outputs":[],"inputs":[]}'
    fi
}

emit_status() {
    jq -nc --argjson sink "$sink" --argjson source "$source" --argjson capture "$capture" --argjson devices "$devices" \
        '{available: $sink.available, sink: $sink,
          source: ($source + {active: $capture.active, clients: $capture.clients})}
         + $devices'
}

refresh_all() {
    sink=$(stream_status @DEFAULT_AUDIO_SINK@)
    source=$(stream_status @DEFAULT_AUDIO_SOURCE@)
    capture=$(capture_status)
    devices=$(device_status)
    sink_description=$(printf '%s' "$sink" | jq -r '.description')
    source_description=$(printf '%s' "$source" | jq -r '.description')
}

refresh_sink() {
    if [ "$sink_description" = "Unavailable" ]; then
        sink=$(stream_status @DEFAULT_AUDIO_SINK@)
        sink_description=$(printf '%s' "$sink" | jq -r '.description')
    else
        sink=$(stream_status @DEFAULT_AUDIO_SINK@ "$sink_description")
    fi
}

refresh_source() {
    if [ "$source_description" = "Unavailable" ]; then
        source=$(stream_status @DEFAULT_AUDIO_SOURCE@)
        source_description=$(printf '%s' "$source" | jq -r '.description')
    else
        source=$(stream_status @DEFAULT_AUDIO_SOURCE@ "$source_description")
    fi
}

refresh_capture() {
    capture=$(capture_status)
}

status() {
    refresh_all
    emit_status
}


reset_refresh() {
    refresh_all_needed=false
    refresh_sink_needed=false
    refresh_source_needed=false
    refresh_capture_needed=false
    refresh_devices_needed=false
}

classify_event() {
    case $1 in
        *"on server"*) refresh_all_needed=true ;;
        *"on card"*)
            refresh_sink_needed=true
            refresh_source_needed=true
            refresh_devices_needed=true
            ;;
        *"on source-output"*) refresh_capture_needed=true ;;
        *"on source"*) refresh_source_needed=true ;;
        *"on sink-input"*) ;;
        *"on sink"*) refresh_sink_needed=true ;;
    esac
}

has_refresh() {
    [ "$refresh_all_needed" = true ] || [ "$refresh_sink_needed" = true ] ||
        [ "$refresh_source_needed" = true ] || [ "$refresh_capture_needed" = true ] ||
        [ "$refresh_devices_needed" = true ]
}

apply_refresh() {
    if [ "$refresh_all_needed" = true ]; then
        refresh_all
        return
    fi
    if [ "$refresh_sink_needed" = true ]; then refresh_sink; fi
    if [ "$refresh_source_needed" = true ]; then refresh_source; fi
    if [ "$refresh_capture_needed" = true ]; then refresh_capture; fi
    if [ "$refresh_devices_needed" = true ]; then devices=$(device_status); fi
}

emit_if_changed() {
    current=$(emit_status)
    [ "$current" = "$last" ] && return
    last=$current
    printf '%s\n' "$current"
}

# The bar must move when the hardware does, not on a timer: PipeWire-pulse
# events are the refresh signal. Hardware controls emit source/card bursts,
# so the first event refreshes immediately and a 20ms quiet period folds the
# remaining events into one final refresh. Unrelated Pulse objects are ignored.
# The first status is a snapshot because subscribe emits no initial event.
follow_events() {
    refresh_all
    last=$(emit_status)
    printf '%s\n' "$last"
    while IFS= read -r event <&3; do
        reset_refresh
        classify_event "$event"
        has_refresh || continue
        apply_refresh
        emit_if_changed

        reset_refresh
        while timeout 0.02 "$@" __read-event <&3 >"$listener_dir/event"; do
            IFS= read -r event <"$listener_dir/event" || break
            classify_event "$event"
        done
        has_refresh || continue
        apply_refresh
        emit_if_changed
    done
}

# pactl ignores SIGPIPE, so a reader that stops would leave it running and
# the bar frozen; the listener therefore owns and kills the subscriber.
stop_subscriber() {
    if [ -n "$subscriber_pid" ]; then
        kill "$subscriber_pid" 2>/dev/null || :
        wait "$subscriber_pid" 2>/dev/null || :
        subscriber_pid=
    fi
}

cleanup_listener() {
    stop_subscriber
    rm -rf "$listener_dir"
}

listen() {
    listener_dir=$(mktemp -d) || return 1
    subscriber_pid=
    trap cleanup_listener 0
    trap 'exit 0' HUP INT TERM PIPE
    mkfifo "$listener_dir/events" || return 1
    if [ -x "$0" ]; then set -- "$0"; else set -- sh "$0"; fi
    while :; do
        "$pactl" subscribe >"$listener_dir/events" 2>/dev/null &
        subscriber_pid=$!
        follow_events "$@" 3<"$listener_dir/events" || :
        stop_subscriber
        # A dead or restarting server ends the subscription; resubscribe
        # after a beat so the bar recovers without an eww reload.
        sleep 2
    done
}

# OpenXLR is the sole authority for the monitor route; these commands read
# and command its HTTP API and keep no selection state of their own.
openxlr_token() {
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -r "$XDG_RUNTIME_DIR/openxlr/token" ]; then
        cat "$XDG_RUNTIME_DIR/openxlr/token"
    elif [ -n "${HOME:-}" ] && [ -r "$HOME/.config/openxlr/token" ]; then
        cat "$HOME/.config/openxlr/token"
    else
        return 1
    fi
}

openxlr_get_state() {
    token=$(openxlr_token) || return 1
    "$curl_cmd" -fsS -H "Authorization: Bearer $token" \
        http://127.0.0.1:37890/api/v1/state
}

monitor_degraded() {
    printf '%s' "$monitor_outputs" \
        | jq -c '[.[] | {label, node, available: false, active: false}]
                 | {available: false, active: null, default: null, outputs: .}'
}

monitor_status() {
    state=$(openxlr_get_state 2>/dev/null) || state=''
    if [ -n "$state" ] && printf '%s' "$state" | jq -e '.type == "state"' >/dev/null 2>&1; then
        printf '%s' "$state" \
            | jq -c --argjson allowlist "$monitor_outputs" '
                . as $state
                | (($allowlist | length) > 0) as $configured
                | ($state.mixer.monitorOutput // $state.mixer.monitorOutputs[0] // null) as $active
                | ($state.mixer.enforcedDefaultSink // null) as $default
                | {
                    available: $configured,
                    active: (if $configured then $active else null end),
                    default: (if $configured then $default else null end),
                    outputs: [
                        $allowlist[]
                        | . as $output
                        | {
                            label: $output.label,
                            node: $output.node,
                            available: any($state.devices[]?; .kind == 0 and .name == $output.node),
                            active: ($output.node == $active)
                        }
                    ]
                }
            '
    else
        monitor_degraded
    fi
}

set_openxlr_output() {
    node=$1
    command=$2
    if ! printf '%s' "$monitor_outputs" | jq -e --arg node "$node" 'any(.[]; .node == $node)' >/dev/null; then
        printf 'monitor output not configured: %s\n' "$node" >&2
        return 2
    fi
    token=$(openxlr_token) || return 1
    payload=$(jq -nc --arg cmd "$command" --arg device "$node" '{cmd: $cmd, device: $device}')
    response=$("$curl_cmd" -sS -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        http://127.0.0.1:37890/api/v1/commands) || return 1
    if ! printf '%s' "$response" | jq -e '.ok == true' >/dev/null; then
        printf 'openxlr rejected %s\n' "$command" >&2
        return 1
    fi
}

set_monitor() {
    set_openxlr_output "$1" setMonitorOutput
}

# The desktop default is a fixed enforced choice, never @monitor follow mode.
set_default_output() {
    set_openxlr_output "$1" setMainOutput
}

cycle_monitor() {
    state=$(openxlr_get_state 2>/dev/null) || return 1
    printf '%s' "$state" | jq -e '.type == "state"' >/dev/null 2>&1 || return 1
    target=$(printf '%s' "$state" \
        | jq -r --argjson allowlist "$monitor_outputs" '
            ($allowlist | map(.node)) as $nodes
            | (.devices // [] | map(select(.kind == 0) | .name)) as $sinks
            | (.mixer.monitorOutput // .mixer.monitorOutputs[0] // null) as $active
            | ($nodes | index($active)) as $idx
            | (if $idx == null then $nodes
               else [range($nodes | length) | $nodes[($idx + 1 + .) % ($nodes | length)]]
               end) as $rotated
            | [$rotated[] | . as $node | select($sinks | index($node) != null)][0] // null
        ') || return 1
    if [ -z "$target" ] || [ "$target" = null ]; then
        printf 'no available monitor output to cycle to\n' >&2
        return 1
    fi
    set_monitor "$target"
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
    status)
        [ "$#" -eq 1 ] || exit 2
        status
        ;;
    listen)
        [ "$#" -eq 1 ] || exit 2
        listen
        ;;
    monitor-status)
        [ "$#" -eq 1 ] || exit 2
        monitor_status
        ;;
    set-monitor)
        [ "$#" -eq 2 ] || exit 2
        set_monitor "$2"
        ;;
    set-default-output)
        [ "$#" -eq 2 ] || exit 2
        set_default_output "$2"
        ;;
    cycle-monitor)
        [ "$#" -eq 1 ] || exit 2
        cycle_monitor
        ;;
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
        printf 'usage: eww-audio status | listen | monitor-status | toggle-sink|toggle-source | change-sink|change-source up|down | set-sink|set-source 0..100 | set-default <node-id> | set-monitor <node> | cycle-monitor\n' >&2
        exit 2
        ;;
esac
