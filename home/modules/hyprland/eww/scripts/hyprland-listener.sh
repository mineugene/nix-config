#!/bin/sh
# shellcheck disable=SC2016

urgent_addresses='[]'

normalize_address() {
    case $1 in
        '') ;;
        0x*) printf '%s\n' "$1" ;;
        *) printf '0x%s\n' "$1" ;;
    esac
}

remember_urgent() {
    address=$(normalize_address "$1")
    if [ -n "$address" ]; then
        urgent_addresses=$(printf '%s\n' "$urgent_addresses" |
            jq --compact-output --arg address "$address" '. + [$address] | unique')
    fi
}

forget_urgent() {
    address=$(normalize_address "$1")
    if [ -n "$address" ]; then
        urgent_addresses=$(printf '%s\n' "$urgent_addresses" |
            jq --compact-output --arg address "$address" 'map(select(. != $address))')
    fi
}

empty_state() {
    jq --compact-output --null-input '
        {
            workspaces: [
                range(1; 10) |
                {
                    id: .,
                    occupied: false,
                    active: false,
                    urgent: false,
                    group_start: false,
                    group_end: false,
                    classes: "empty"
                }
            ],
            title: "",
            app: "",
            address: "",
            class: ""
        }
    '
}

snapshot() {
    if ! active=$(hyprctl -j activeworkspace 2>/dev/null); then
        empty_state
        return
    fi
    if ! clients=$(hyprctl -j clients 2>/dev/null); then
        empty_state
        return
    fi
    if ! window=$(hyprctl -j activewindow 2>/dev/null); then
        window='{}'
    fi

    if ! urgent_addresses=$(
        printf '%s\n' "$urgent_addresses" | jq --compact-output \
            --argjson clients "$clients" \
            '[.[] as $address | select(any($clients[]?; .address == $address)) | $address]'
    ); then
        urgent_addresses='[]'
    fi

    jq --compact-output --null-input \
        --argjson active "$active" \
        --argjson clients "$clients" \
        --argjson urgent "$urgent_addresses" \
        --argjson window "$window" '
            {
                workspaces: (
                    [
                        range(1; 10) as $id |
                        {
                            id: $id,
                            occupied: any($clients[]?; (.workspace.id // -1) == $id),
                            active: (($active.id // -1) == $id),
                            urgent: any(
                                $clients[]?;
                                ((.workspace.id // -1) == $id)
                                    and (.address as $address | any($urgent[]?; . == $address))
                            )
                        }
                    ] as $workspaces |
                    $workspaces | to_entries | map(
                        .key as $index |
                        (
                            .value.occupied and (
                                $index == 0
                                    or (($workspaces[$index - 1].occupied // false) | not)
                            )
                        ) as $group_start |
                        (
                            .value.occupied
                                and (($workspaces[$index + 1].occupied // false) | not)
                        ) as $group_end |
                        .value + {
                            group_start: $group_start,
                            group_end: $group_end,
                            classes: (
                                [
                                    (if .value.occupied then "occupied" else "empty" end),
                                    (if $group_start then "group-start" else empty end),
                                    (if $group_end then "group-end" else empty end),
                                    (if .value.active then "active" else empty end),
                                    (if .value.urgent then "urgent" else empty end)
                                ] | join(" ")
                            )
                        }
                    )
                ),
                title: ($window.title // ""),
                app: (
                    [$window.initialTitle?, $window.class?]
                    | map(select(. != null and . != ""))
                    | first // ""
                ),
                class: ($window.class // ""),
                address: ($window.address // "")
            }
        ' || empty_state
}

socket_path() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        return 1
    fi

    printf '%s/hypr/%s/.socket2.sock\n' \
        "$XDG_RUNTIME_DIR" "$HYPRLAND_INSTANCE_SIGNATURE"
}

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

listener_dir=$(mktemp -d) || exit 1
subscriber_pid=
trap cleanup_listener 0
trap 'exit 0' HUP INT TERM PIPE
mkfifo "$listener_dir/events" || exit 1

while true; do
    snapshot

    if socket=$(socket_path) && [ -S "$socket" ]; then
        socat -U - "UNIX-CONNECT:$socket" >"$listener_dir/events" 2>/dev/null &
        subscriber_pid=$!
        while IFS= read -r event; do
            event_name=${event%%>>*}
            event_data=${event#*>>}

            case $event_name in
                urgent)
                    remember_urgent "$event_data"
                    snapshot
                    ;;
                activewindowv2 | closewindow)
                    forget_urgent "$event_data"
                    snapshot
                    ;;
                activewindow | createworkspace | createworkspacev2 | destroyworkspace | destroyworkspacev2 | focusedmon | fullscreen | minimize | movewindow | movewindowv2 | openwindow | workspace | workspacev2 | windowtitle | windowtitlev2)
                    snapshot
                    ;;
            esac
        done <"$listener_dir/events"
        stop_subscriber
    fi

    sleep 1 2>/dev/null
done
