# shellcheck disable=SC2016

urgent_addresses='[]'

normalize_address() {
    local address=$1

    if [[ -z $address ]]; then
        return
    elif [[ $address == 0x* ]]; then
        printf '%s\n' "$address"
    else
        printf '0x%s\n' "$address"
    fi
}

remember_urgent() {
    local address

    address=$(normalize_address "$1")
    if [[ -n $address ]]; then
        urgent_addresses=$(jq --compact-output --arg address "$address" '. + [$address] | unique' <<< "$urgent_addresses")
    fi
}

forget_urgent() {
    local address

    address=$(normalize_address "$1")
    if [[ -n $address ]]; then
        urgent_addresses=$(jq --compact-output --arg address "$address" 'map(select(. != $address))' <<< "$urgent_addresses")
    fi
}

empty_state() {
    jq --compact-output --null-input '
        {
            workspaces: [
                range(1; 10) |
                { id: ., occupied: false, active: false, urgent: false }
            ],
            title: "",
            class: ""
        }
    '
}

snapshot() {
    local active clients window

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
        jq --compact-output \
            --argjson clients "$clients" \
            '[.[] as $address | select(any($clients[]?; .address == $address)) | $address]' \
            <<< "$urgent_addresses"
    ); then
        urgent_addresses='[]'
    fi

    jq --compact-output --null-input \
        --argjson active "$active" \
        --argjson clients "$clients" \
        --argjson urgent "$urgent_addresses" \
        --argjson window "$window" '
            {
                workspaces: [
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
                ],
                title: ($window.title // ""),
                class: ($window.class // "")
            }
        ' || empty_state
}

socket_path() {
    if [[ -z ${XDG_RUNTIME_DIR:-} || -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        return 1
    fi

    printf '%s/hypr/%s/.socket2.sock\n' \
        "$XDG_RUNTIME_DIR" "$HYPRLAND_INSTANCE_SIGNATURE"
}

while true; do
    snapshot

    if socket=$(socket_path) && [[ -S $socket ]]; then
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
        done < <(socat -U - "UNIX-CONNECT:$socket" 2>/dev/null || true)
    fi

    sleep 1
done
