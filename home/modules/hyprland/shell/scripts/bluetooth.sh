#!/bin/sh
set -eu

bluetoothctl=${SHELL_BLUETOOTHCTL:-bluetoothctl}
sys_root=${SHELL_BLUETOOTH_SYS_ROOT:-/sys}
state_root=${SHELL_BLUETOOTH_STATE_ROOT:-${XDG_RUNTIME_DIR:-/tmp}/shell-bluetooth}
scan_seconds=${SHELL_BLUETOOTH_SCAN_SECONDS:-8}
rofi=${SHELL_BLUETOOTH_ROFI:-rofi}
desktop_theme=${SHELL_BLUETOOTH_DESKTOP_THEME:-desktop-theme}
monitor_topology=${SHELL_BLUETOOTH_MONITOR_TOPOLOGY:-monitor-topology}

# Capability is a property of the machine, so it is read from the adapters the
# kernel exposes. bluetoothctl reports no controller while the radio is blocked,
# which would otherwise hide the control exactly when it is needed to unblock it.
# The adapter name travels with the state so the bar can identify the link.
adapter_name() {
    for adapter in "$sys_root"/class/bluetooth/*; do
        [ -e "$adapter" ] || continue
        printf '%s\n' "${adapter##*/}"
        return 0
    done
    return 1
}

emit() {
    printf '{"available":%s,"powered":%s,"connected":%s,"audio":%s,"adapter":"%s"}\n' "$1" "$2" "$3" "$4" "$5"
}

# A connected headset is what the radio is usually for, so it is reported
# separately from a connected input device: the two deserve different glyphs.
connections() {
    connected=false
    audio=false

    devices=$(timeout 5 "$bluetoothctl" devices Connected 2>/dev/null || true)
    [ -n "$devices" ] || return 0
    connected=true

    # The loop is a pipeline stage, so it cannot assign to the caller: it
    # reports an audio device by exiting non-zero instead.
    printf '%s\n' "$devices" | while IFS=' ' read -r keyword address _; do
        [ "$keyword" = Device ] || continue
        info=$(timeout 5 "$bluetoothctl" info "$address" 2>/dev/null || true)
        case $info in
            *'Icon: audio-'*) exit 1 ;;
        esac
    done || audio=true

    return 0
}

status() {
    if ! adapter=$(adapter_name); then
        emit false false false false ""
        return
    fi

    # A stopped or missing Bluetooth service cannot be controlled from the
    # bar, so the control hides rather than offering a toggle that fails.
    if ! output=$(timeout 5 "$bluetoothctl" show 2>/dev/null); then
        emit false false false false "$adapter"
        return
    fi

    case $output in
        *'Powered: yes'*) ;;
        *)
            emit true false false false "$adapter"
            return
            ;;
    esac

    connections
    emit true true "$connected" "$audio" "$adapter"
}

# The fields a device row shows come from one `info` query per address. RSSI is
# only present for a device seen in a recent scan, so it is optional and a
# missing value sorts last.
device_json() {
    address=$1
    info=$(timeout 5 "$bluetoothctl" info "$address" 2>/dev/null || true)

    name=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*Name: //p' | head -n 1)
    [ -n "$name" ] || name=$address

    paired=false
    case $info in *'Paired: yes'*) paired=true ;; esac
    connected=false
    case $info in *'Connected: yes'*) connected=true ;; esac
    audio=false
    case $info in *'Icon: audio-'*) audio=true ;; esac

    # bluetoothctl prints RSSI as a hex-masked value with a signed decimal in
    # parentheses ("0xffffffad (-83)"). Only the decimal is valid JSON, and a
    # value jq rejects aborts the whole list.
    rssi=null
    rssi_value=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*RSSI: .*(\(-\{0,1\}[0-9]\{1,\}\)).*$/\1/p' | head -n 1)
    if [ -z "$rssi_value" ]; then
        rssi_value=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*RSSI: \(-\{0,1\}[0-9]\{1,\}\)$/\1/p' | head -n 1)
    fi
    if [ -n "$rssi_value" ]; then
        rssi=$rssi_value
    fi

    jq -nc \
        --arg address "$address" \
        --arg name "$name" \
        --argjson paired "$paired" \
        --argjson connected "$connected" \
        --argjson audio "$audio" \
        --argjson rssi "$rssi" \
        '{address:$address,name:$name,paired:$paired,connected:$connected,audio:$audio,rssi:$rssi}'
}

list_devices() {
    scanning=false
    if [ -e "$state_root/scanning" ]; then
        scanning=true
    fi

    rows=
    devices=$(timeout 5 "$bluetoothctl" devices 2>/dev/null || true)
    while IFS=' ' read -r keyword address rest; do
        [ "$keyword" = Device ] || continue
        [ -n "$address" ] || continue
        rows="$rows$(device_json "$address")
"
    done <<EOF
$devices
EOF

    printf '%s' "$rows" |
        jq -sc --argjson scanning "$scanning" \
            'sort_by(.name | ascii_downcase) as $devices |
             ($devices | map(select(.paired and .connected))) as $online |
             ($devices | map(select(.paired and (.connected | not)))) as $offline |
             ($devices | map(select(.paired | not))) as $discovered |
             {scanning:$scanning,
              devices:$devices,
              paired_online:$online,
              paired_offline:$offline,
              discovered:$discovered,
              discovered_top:($discovered[0:6])}'
}

# Broadcasting makes the adapter discoverable and pairable so a remote can find
# and pair with this machine. It lasts only while the popover is open, so the
# popup's own close path turns it off; the watchdog below is the backstop for
# when that path never runs, such as a shell or helper crash.
broadcast_marker=$state_root/broadcasting
broadcast_pid=$state_root/broadcast.pid
broadcast_seconds=${SHELL_BLUETOOTH_BROADCAST_SECONDS:-900}

broadcast_stop_watchdog() {
    [ -f "$broadcast_pid" ] || return 0
    pid=$(cat "$broadcast_pid" 2>/dev/null || true)
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$broadcast_pid"
}

broadcast_disable() {
    rm -f "$broadcast_marker"
    timeout 5 "$bluetoothctl" discoverable off >/dev/null 2>&1 || true
    timeout 5 "$bluetoothctl" pairable off >/dev/null 2>&1 || true
}

broadcast_watchdog() {
    sleep "$broadcast_seconds"
    broadcast_disable
    rm -f "$broadcast_pid"
}

broadcast_on() {
    mkdir -p "$state_root"
    broadcast_stop_watchdog
    timeout 5 "$bluetoothctl" discoverable on >/dev/null 2>&1 || true
    timeout 5 "$bluetoothctl" pairable on >/dev/null 2>&1 || true
    : > "$broadcast_marker"
    ( broadcast_watchdog ) >/dev/null 2>&1 &
    printf '%s\n' "$!" > "$broadcast_pid"
}

broadcast_off() {
    broadcast_stop_watchdog
    broadcast_disable
}

scan_devices() {
    mkdir -p "$state_root"
    : > "$state_root/scanning"
    # The scan is detached and bounded. bluetoothctl starts discovery and
    # returns at once unless it is given --timeout, and discovery stops when it
    # exits, so the timeout is passed to bluetoothctl rather than wrapped
    # around it: otherwise the marker is gone before the watcher's tick sees it
    # and the list never refreshes.
    (
        "$bluetoothctl" --timeout "$scan_seconds" scan on >/dev/null 2>&1 || true
        rm -f "$state_root/scanning"
    ) >/dev/null 2>&1 &
    exit 0
}

# Emit the list only while a scan is in flight, and only when it changes. The shell
# rebuilds the rows whenever the list is written, so a value written every
# tick would reset the hover highlight under the pointer. The idle cost is one stat per tick; the bluetoothctl reads and jq
# run only during a scan. The shell starts and stops this with the popup, so nothing
# runs while the popup is closed.
watch_devices() {
    last=
    scanning=false
    while :; do
        was_scanning=$scanning
        if [ -e "$state_root/scanning" ]; then
            scanning=true
        else
            scanning=false
        fi
        # The tick after a scan ends refreshes the list one last time with
        # scanning cleared, so the reload control re-enables.
        if [ "$scanning" = true ] || [ "$was_scanning" = true ]; then
            current=$(list_devices)
            if [ "$current" != "$last" ]; then
                printf '%s\n' "$current"
                last=$current
            fi
        fi
        sleep 1
    done
}

# The full list lives in a Rofi menu, the same surface as the Wi-Fi list and
# the power dialogs. Rofi reports the chosen row by index, so a device name
# never reaches a shell.
menu_devices() {
    config_home=${XDG_CONFIG_HOME:-${HOME:-}/.config}
    mode=$("$desktop_theme" get 2>/dev/null || true)
    [ -n "$mode" ] || mode=dark
    monitor=$("$monitor_topology" primary 2>/dev/null || true)
    [ -n "$monitor" ] || monitor=-1

    devices=$(list_devices)
    entries=$(printf '%s' "$devices" | jq -c '
        def device_glyph: if .audio then "󰂰" else "󰂯" end;
        def device_status: if .connected then "Connected" elif .paired then "Paired" else "" end;
        def device_row: {display: "\(device_glyph)  \(.name)  \(device_status)" | sub(" +$"; ""), address: .address, paired: .paired, connected: .connected, heading: false};
        def group($title; $rows): if ($rows | length) > 0 then [{display: $title, address: "", paired: false, connected: false, heading: true}] + ($rows | map(device_row)) else [] end;
        group("Paired & online"; .paired_online)
        + group("Paired & offline"; .paired_offline)
        + group("Discovered devices"; .discovered)
    ')
    lines=$(printf '%s' "$entries" | jq -r '.[].display')
    [ -n "$lines" ] || exit 0

    if ! choice=$(printf '%s\n' "$lines" | "$rofi" \
        -dmenu \
        -p Bluetooth \
        -monitor "$monitor" \
        -theme "$config_home/rofi/themes/menu-$mode.rasi" \
        -no-custom \
        -no-cycle \
        -click-to-exit \
        -format i \
        -selected-row 0 \
        -hover-select \
        -me-select-entry '' \
        -me-accept-entry MousePrimary); then
        exit 0
    fi
    [ -n "$choice" ] || exit 0

    # A heading is a plain text row, so selecting one carries no address and
    # the action is skipped rather than aimed at a device by accident.
    entry=$(printf '%s' "$entries" | jq -c --argjson index "$choice" '.[$index] // {}')
    address=$(printf '%s' "$entry" | jq -r '.address // ""')
    [ -n "$address" ] || exit 0
    connected=$(printf '%s' "$entry" | jq -r '.connected // false')
    paired=$(printf '%s' "$entry" | jq -r '.paired // false')
    if [ "$connected" = true ]; then
        device_action disconnect "$address"
    elif [ "$paired" = true ]; then
        device_action connect "$address"
    else
        device_action pair "$address"
    fi
}

device_action() {
    action=$1
    address=$2
    case $address in
        '' | *[!0-9A-Fa-f:]*) exit 64 ;;
    esac
    case $action in
        pair | connect | disconnect | forget) ;;
        *) exit 64 ;;
    esac

    if [ "$action" = forget ]; then
        exec "$bluetoothctl" remove "$address"
    fi
    exec "$bluetoothctl" "$action" "$address"
}

case ${1-} in
    status)
        [ "$#" -eq 1 ] || exit 2
        status
        ;;
    toggle)
        [ "$#" -eq 1 ] || exit 2
        case $(status) in
            *'"powered":true'*) exec "$bluetoothctl" power off ;;
            *'"available":true'*) exec "$bluetoothctl" power on ;;
            *) exit 1 ;;
        esac
        ;;
    devices)
        [ "$#" -eq 1 ] || exit 2
        list_devices
        ;;
    watch)
        [ "$#" -eq 1 ] || exit 2
        watch_devices
        ;;
    menu)
        [ "$#" -eq 1 ] || exit 2
        menu_devices
        ;;
    broadcast)
        [ "$#" -eq 2 ] || exit 2
        case $2 in
            on) broadcast_on ;;
            off) broadcast_off ;;
            *) exit 2 ;;
        esac
        ;;
    scan)
        [ "$#" -eq 1 ] || exit 2
        scan_devices
        ;;
    pair | connect | disconnect | forget)
        [ "$#" -eq 2 ] || exit 2
        device_action "$1" "$2"
        ;;
    *)
        printf 'usage: shell-bluetooth status | toggle | devices | watch | menu | scan | broadcast on|off | pair ADDRESS | connect ADDRESS | disconnect ADDRESS | forget ADDRESS\n' >&2
        exit 2
        ;;
esac