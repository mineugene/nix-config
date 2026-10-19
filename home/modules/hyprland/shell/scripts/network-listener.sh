#!/bin/sh
set -eu
export LC_ALL=C

# iwd owns Wi-Fi association and systemd-networkd owns addressing, so link
# state comes from iwd's D-Bus API and addressing comes from the network
# stack. Every external program is overridable so tests can drive the script
# without the daemons.
busctl=${SHELL_NETWORK_BUSCTL:-busctl}
iwctl=${SHELL_NETWORK_IWCTL:-iwctl}
ip_command=${SHELL_NETWORK_IP:-ip}
pkexec=${SHELL_NETWORK_PKEXEC:-pkexec}
rofi=${SHELL_NETWORK_ROFI:-rofi}
desktop_theme=${SHELL_NETWORK_DESKTOP_THEME:-desktop-theme}
monitor_topology=${SHELL_NETWORK_MONITOR_TOPOLOGY:-monitor-topology}
clock=${SHELL_NETWORK_DATE:-date}
sys_root=${SHELL_NETWORK_SYS_ROOT:-/sys}
interval=${SHELL_NETWORK_INTERVAL:-2}
timeout_seconds=${SHELL_NETWORK_TIMEOUT:-2}
state_root=${SHELL_NETWORK_STATE_ROOT:-${XDG_RUNTIME_DIR:-/tmp}/shell-network}

# Retain counters for every interface, including links not selected this cycle.
# Kernel interface names cannot contain whitespace, so records are unambiguous.
previous_rates=

is_virtual_interface() {
    case $1 in
        br-* | docker* | lo | podman* | tap* | tun* | veth* | virbr* | wg*) return 0 ;;
        *) return 1 ;;
    esac
}

# Kernel capability keeps the radio control visible even when Wi-Fi is off.
interfaces_of_kind() (
    kind=$1
    for interface in "$sys_root"/class/net/*; do
        [ -d "$interface" ] || continue
        interface=${interface##*/}
        is_virtual_interface "$interface" && continue
        case $kind in
            wifi) [ -d "$sys_root/class/net/$interface/wireless" ] || continue ;;
            ethernet) [ -d "$sys_root/class/net/$interface/wireless" ] && continue ;;
        esac
        printf '%s\n' "$interface"
    done
)

# Administrative state decides whether the link can be used at all. A radio
# that is up but unassociated reports operstate down while IFF_UP stays set:
# that is a disconnected link the user can still select, not a missing one.
is_up() (
    interface=$1
    [ -r "$sys_root/class/net/$interface/flags" ] || return 1
    read -r flags < "$sys_root/class/net/$interface/flags" || return 1
    [ "$((flags & 1))" -eq 1 ]
)

is_carrying() (
    interface=$1
    [ -r "$sys_root/class/net/$interface/operstate" ] || return 1
    read -r operstate < "$sys_root/class/net/$interface/operstate" || return 1
    [ "$operstate" = up ] || return 1

    [ -r "$sys_root/class/net/$interface/carrier" ] || return 1
    read -r carrier < "$sys_root/class/net/$interface/carrier" || return 1
    [ "$carrier" = 1 ]
)

pick_interface() (
    first=
    interfaces=$(interfaces_of_kind "$1")
    while IFS= read -r interface; do
        [ -n "$interface" ] || continue
        [ -n "$first" ] || first=$interface
        if is_carrying "$interface"; then
            printf '%s\n' "$interface"
            return
        fi
    done <<EOF
$interfaces
EOF
    printf '%s\n' "$first"
)

read_rate() {
    rate_interface=$1
    rate_now=$("$clock" +%s)
    rate_rx=0
    rate_tx=0
    if [ -r "$sys_root/class/net/$rate_interface/statistics/rx_bytes" ]; then
        read -r rate_rx < "$sys_root/class/net/$rate_interface/statistics/rx_bytes" || rate_rx=0
    fi
    if [ -r "$sys_root/class/net/$rate_interface/statistics/tx_bytes" ]; then
        read -r rate_tx < "$sys_root/class/net/$rate_interface/statistics/tx_bytes" || rate_tx=0
    fi

    rx_rate=0
    tx_rate=0
    rate_cache=
    while read -r rate_cached_interface rate_previous_rx rate_previous_tx rate_previous_time; do
        [ -n "$rate_cached_interface" ] || continue
        if [ "$rate_cached_interface" = "$rate_interface" ]; then
            if [ "$rate_previous_time" -gt 0 ] && [ "$rate_now" -gt "$rate_previous_time" ]; then
                rate_elapsed=$((rate_now - rate_previous_time))
                if [ "$rate_rx" -ge "$rate_previous_rx" ]; then
                    rx_rate=$(((rate_rx - rate_previous_rx) / rate_elapsed))
                fi
                if [ "$rate_tx" -ge "$rate_previous_tx" ]; then
                    tx_rate=$(((rate_tx - rate_previous_tx) / rate_elapsed))
                fi
            fi
        else
            rate_cache="$rate_cache$rate_cached_interface $rate_previous_rx $rate_previous_tx $rate_previous_time
"
        fi
    done <<EOF
$previous_rates
EOF
    previous_rates="$rate_cache$rate_interface $rate_rx $rate_tx $rate_now"
}

# --- iwd D-Bus helpers -------------------------------------------------------

# Every iwd call is bounded: a daemon that is restarting must not block the
# only thread that emits bar state.
bus() {
    timeout "$timeout_seconds" "$busctl" "$@" 2>/dev/null || true
}

# Every device path iwd publishes has the shape /net/connman/iwd/<adapter>/<id>.
# Deeper network paths share that prefix, so sorting the matches removes the
# duplicates they contribute.
iwd_device_paths() {
    bus tree net.connman.iwd |
        grep -o '/net/connman/iwd/[0-9][0-9]*/[0-9][0-9]*' |
        sort -u ||
        true
}

# Reads one property as its bare value. A missing property yields nothing.
iwd_property() {
    bus --json=short get-property net.connman.iwd "$1" "$2" "$3" |
        jq -r '.data' 2>/dev/null ||
        true
}

iwd_device_for() {
    interface=$1
    for path in $(iwd_device_paths); do
        name=$(iwd_property "$path" net.connman.iwd.Device Name)
        if [ "$name" = "$interface" ]; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

iwd_first_device() {
    for path in $(iwd_device_paths); do
        printf '%s\n' "$path"
        return 0
    done
    return 1
}

iwd_station() {
    if [ -n "${1-}" ]; then
        iwd_device_for "$1" && return 0
    fi
    iwd_first_device
}

# iwd reports a network's signal as 100 * dBm, so the percentage the bar draws
# is 100 plus the unscaled value. The connected network sorts first.
iwd_connected_signal() {
    signal=$(
        bus --json=short call net.connman.iwd "$1" net.connman.iwd.Station GetOrderedNetworks |
            jq -r '.data[0][0][1] // empty' 2>/dev/null ||
            true
    )
    [ -n "$signal" ] || return 0
    printf '%s\n' "$((100 + signal / 100))"
}

# --- addressing helpers ------------------------------------------------------

interface_address() {
    "$ip_command" -4 -o addr show dev "$1" 2>/dev/null |
        awk 'NR == 1 { print $4 }' ||
        true
}

has_default_route() {
    [ -n "$("$ip_command" -4 route show default dev "$1" 2>/dev/null || true)" ]
}

initial_link() {
    kind=$1
    jq -nc --arg kind "$kind" \
        '{kind:$kind,available:false,state:"unavailable",connected:false,internet:false,
          interface:"",name:"Unavailable",signal:null,ip:"",
          rx_bytes_per_second:0,tx_bytes_per_second:0}'
}

link_json() {
    jq -nc \
        --arg kind "$1" \
        --argjson available "$2" \
        --arg state "$3" \
        --argjson connected "$4" \
        --argjson internet "$5" \
        --arg interface "$6" \
        --arg name "$7" \
        --argjson signal "$8" \
        --arg ip "$9" \
        --argjson rx "${10}" \
        --argjson tx "${11}" \
        '{kind:$kind,available:$available,state:$state,connected:$connected,
          internet:$internet,interface:$interface,name:$name,signal:$signal,ip:$ip,
          rx_bytes_per_second:$rx,tx_bytes_per_second:$tx}'
}

wifi_link() {
    wifi_interface=$(pick_interface wifi || true)
    station=$(iwd_station "$wifi_interface" || true)

    available=false
    powered=true
    interface=$wifi_interface
    if [ -n "$station" ]; then
        available=true
        [ -n "$interface" ] || interface=$(iwd_property "$station" net.connman.iwd.Device Name)
        if [ "$(iwd_property "$station" net.connman.iwd.Device Powered)" = false ]; then
            powered=false
        fi
    fi
    if [ -n "$interface" ]; then
        available=true
    fi

    state=unavailable
    name=Unavailable
    connected=false
    signal=null
    ip=
    internet=false

    if [ -z "$interface" ]; then
        state=unavailable
    elif [ "$powered" = false ]; then
        state=off
        name='Wi-Fi disabled'
    elif [ -z "$station" ]; then
        state=unavailable
    else
        case $(iwd_property "$station" net.connman.iwd.Station State) in
            connected) state=connected ;;
            connecting | disconnecting | roaming) state=connecting ;;
            *) state=disconnected ;;
        esac

        if [ "$state" = connected ]; then
            connected=true
            network=$(iwd_property "$station" net.connman.iwd.Station ConnectedNetwork)
            if [ -n "$network" ]; then
                ssid=$(iwd_property "$network" net.connman.iwd.Network Name)
                [ -z "$ssid" ] || name=$ssid
            fi
            signal=$(iwd_connected_signal "$station")
            [ -n "$signal" ] || signal=null
            ip=$(interface_address "$interface")
            if has_default_route "$interface"; then internet=true; fi
        fi

        # A down interface cannot reconnect until brought up.
        if [ "$state" = disconnected ] && ! is_up "$interface"; then
            state=unavailable
        fi

        case $state in
            off) name='Wi-Fi disabled' ;;
            unavailable) name=Unavailable ;;
            disconnected) name=Disconnected ;;
        esac
    fi

    wifi_rx=0
    wifi_tx=0
    if [ "$state" = connected ] && [ -n "$interface" ]; then
        read_rate "$interface"
        wifi_rx=$rx_rate
        wifi_tx=$tx_rate
    fi

    wifi_out=$(link_json wifi "$available" "$state" "$connected" "$internet" \
        "$interface" "$name" "$signal" "$ip" "$wifi_rx" "$wifi_tx")
}

ethernet_link() {
    ethernet_interface=$(pick_interface ethernet || true)

    available=false
    state=unavailable
    name=Unavailable
    connected=false
    signal=null
    ip=
    internet=false

    if [ -n "$ethernet_interface" ]; then
        available=true
        name=$ethernet_interface
        if is_carrying "$ethernet_interface"; then
            state=connected
            connected=true
            ip=$(interface_address "$ethernet_interface")
            if has_default_route "$ethernet_interface"; then internet=true; fi
        else
            state=disconnected
        fi
        if [ "$state" = disconnected ] && ! is_up "$ethernet_interface"; then
            state=unavailable
        fi
        case $state in
            unavailable) name=Unavailable ;;
            disconnected) name=Disconnected ;;
        esac
    fi

    ethernet_rx=0
    ethernet_tx=0
    if [ "$state" = connected ]; then
        read_rate "$ethernet_interface"
        ethernet_rx=$rx_rate
        ethernet_tx=$tx_rate
    fi

    ethernet_out=$(link_json ethernet "$available" "$state" "$connected" "$internet" \
        "$ethernet_interface" "$name" "$signal" "$ip" "$ethernet_rx" "$ethernet_tx")
}

emit_state() {
    # Both links are built in this shell, not a subshell: the rate cache they
    # share only advances when read_rate runs against the persistent state.
    wifi_link
    ethernet_link
    wifi=$wifi_out
    ethernet=$ethernet_out

    jq -nc --argjson wifi "$wifi" --argjson ethernet "$ethernet" \
        '{wifi:$wifi,ethernet:$ethernet,
          primary:(if $ethernet.connected then $ethernet
                   elif $wifi.connected then $wifi
                   elif $ethernet.available then $ethernet
                   else $wifi end)}'
}

# --- network list ------------------------------------------------------------

cache_file() {
    mkdir -p "$state_root"
    printf '%s\n' "$state_root/networks.json"
}

emit_networks() {
    wifi_interface=$(pick_interface wifi || true)
    station=$(iwd_station "$wifi_interface" || true)

    scanning=false
    # Only a scan this helper started refreshes the list. iwd runs its own
    # background scans, and counting those would keep the list rebuilding.
    if [ -e "$state_root/scanning" ]; then
        scanning=true
    fi

    if [ -z "$station" ]; then
        jq -nc --argjson scanning "$scanning" '{scanning:$scanning,networks:[]}'
        return 0
    fi

    connected_path=$(iwd_property "$station" net.connman.iwd.Station ConnectedNetwork)

    entries=$(
        bus --json=short call net.connman.iwd "$station" net.connman.iwd.Station GetOrderedNetworks |
            jq -r '.data[0][] | "\(.[0])\t\(.[1])"' 2>/dev/null ||
            true
    )

    rows=
    network_index=0
    while IFS="$(printf '\t')" read -r path signal; do
        [ -n "$path" ] || continue
        ssid=$(iwd_property "$path" net.connman.iwd.Network Name)
        [ -n "$ssid" ] || continue
        security=$(iwd_property "$path" net.connman.iwd.Network Type)
        [ -n "$security" ] || security=psk
        known=false
        if timeout "$timeout_seconds" "$busctl" get-property net.connman.iwd "$path" net.connman.iwd.Network KnownNetwork >/dev/null 2>&1; then
            known=true
        fi
        connected=false
        if [ -n "$connected_path" ] && [ "$path" = "$connected_path" ]; then
            connected=true
        fi
        percent=$((100 + signal / 100))
        if [ "$percent" -lt 0 ]; then percent=0; fi
        if [ "$percent" -gt 100 ]; then percent=100; fi
        rows="$rows$(jq -nc \
            --argjson index "$network_index" \
            --arg ssid "$ssid" \
            --arg security "$security" \
            --argjson signal "$percent" \
            --argjson known "$known" \
            --argjson connected "$connected" \
            '{index:$index,ssid:$ssid,security:$security,signal:$signal,known:$known,connected:$connected}')
"
        network_index=$((network_index + 1))
    done <<EOF
$entries
EOF

    output=$(printf '%s' "$rows" | jq -sc --argjson scanning "$scanning" \
        '{scanning:$scanning,networks:.,top:(.[0:6])}')
    printf '%s\n' "$output" > "$(cache_file)"
    printf '%s\n' "$output"
}

network_entry() {
    entry_index=$1
    case $entry_index in
        '' | *[!0-9]*) return 1 ;;
    esac
    emit_networks >/dev/null
    jq -c --argjson index "$entry_index" '.networks[$index] // empty' "$(cache_file)" 2>/dev/null
}

network_field() {
    jq -r --arg field "$2" '.[$field] // ""' <<EOF
$1
EOF
}

prompt_password() {
    "$rofi" -dmenu -password -p "$1 password" 2>/dev/null || true
}

prompt_line() {
    "$rofi" -dmenu -p "$1" 2>/dev/null || true
}

# Connects through iwctl with the password supplied on the privileged
# command's argument vector. That process runs as root, so its arguments are
# unreadable to other users.
do_connect() {
    connect_ssid=$1
    connect_passphrase=$2
    connect_mode=$3

    device=$(pick_interface wifi || true)
    [ -n "$device" ] || return 1

    set -- station "$device"
    if [ "$connect_mode" = hidden ]; then
        set -- "$@" connect-hidden "$connect_ssid"
    else
        set -- "$@" connect "$connect_ssid"
    fi

    if [ -n "$connect_passphrase" ]; then
        exec "$pkexec" "$iwctl" --passphrase="$connect_passphrase" "$@"
    fi
    exec "$pkexec" "$iwctl" "$@"
}

connect_index() {
    index=$1
    entry=$(network_entry "$index") || exit 64
    [ -n "$entry" ] || exit 1

    ssid=$(network_field "$entry" ssid)
    security=$(network_field "$entry" security)
    known=$(network_field "$entry" known)

    passphrase=
    if [ "$security" != open ] && [ "$known" != true ]; then
        passphrase=$(prompt_password "$ssid")
        [ -n "$passphrase" ] || exit 0
    fi

    do_connect "$ssid" "$passphrase" broadcast
}

forget_index() {
    index=$1
    entry=$(network_entry "$index") || exit 64
    [ -n "$entry" ] || exit 1
    ssid=$(network_field "$entry" ssid)
    exec "$pkexec" "$iwctl" known-networks "$ssid" forget
}

# Emit the list only while a scan is in flight, and only when it changes. The shell
# rebuilds the rows whenever the list is written, so a value written every
# tick would reset the hover highlight under the pointer. The idle cost is one stat per tick; the iwd reads and jq run only
# during a scan. The shell starts and stops this with the popup, so nothing runs
# while the popup is closed.
watch_networks() {
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
            current=$(emit_networks)
            if [ "$current" != "$last" ]; then
                printf '%s\n' "$current"
                last=$current
            fi
        fi
        sleep 1
    done
}

# The full list lives in a Rofi menu, the same surface as the power dialogs.
# Rofi reports the chosen row by index, so an SSID never reaches a shell.
menu_networks() {
    config_home=${XDG_CONFIG_HOME:-${HOME:-}/.config}
    mode=$("$desktop_theme" get 2>/dev/null || true)
    [ -n "$mode" ] || mode=dark
    monitor=$("$monitor_topology" primary 2>/dev/null || true)
    [ -n "$monitor" ] || monitor=-1

    emit_networks >/dev/null

    lines=$(jq -r '
        def signal_glyph:
          if .signal < 40 then "󰤟"
          elif .signal < 60 then "󰤢"
          elif .signal < 80 then "󰤥"
          else "󰤨" end;
        .networks[]
        | "\(signal_glyph)  \(.ssid)  \(if .security == "open" then "" else "󰌾" end)\(if .connected then " (connected)" else "" end)"
        | sub(" +$"; "")
    ' "$(cache_file)")
    [ -n "$lines" ] || exit 0

    if ! choice=$(printf '%s\n' "$lines" | "$rofi" \
        -dmenu \
        -p Wi-Fi \
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

    connected=$(jq -r --argjson index "$choice" '.networks[$index].connected // false' "$(cache_file)")
    if [ "$connected" = true ]; then
        disconnect_network
    else
        connect_index "$choice"
    fi
}

# Custom and hidden networks are not in iwd's ordered list, so every field is
# collected before the connection starts. Security and hidden state are the
# advanced options iwd stores per network.
add_network() {
    ssid=$(prompt_line "Network name")
    [ -n "$ssid" ] || exit 0

    security=$(prompt_line "Security (psk/open)")
    case $security in
        '' | psk | open) ;;
        *)
            printf 'unknown security type: %s\n' "$security" >&2
            exit 64
            ;;
    esac
    [ -n "$security" ] || exit 0

    hidden=$(prompt_line "Hidden network (yes/no)")
    case $hidden in '' | no) hidden=no ;; yes) ;; *) exit 64 ;; esac

    passphrase=
    if [ "$security" = psk ]; then
        passphrase=$(prompt_password "$ssid")
        [ -n "$passphrase" ] || exit 0
    fi

    if [ "$hidden" = yes ]; then
        do_connect "$ssid" "$passphrase" hidden
    fi
    do_connect "$ssid" "$passphrase" broadcast
}

wifi_radio() {
    action=$1
    case $action in
        on | off) ;;
        *)
            printf 'usage: shell-network-listener wifi on | off\n' >&2
            exit 64
            ;;
    esac

    device=$(pick_interface wifi || true)
    if [ -z "$device" ]; then
        device=$(iwd_property "$(iwd_first_device || true)" net.connman.iwd.Device Name)
    fi
    [ -n "$device" ] || exit 1

    exec "$iwctl" device "$device" set-property Powered "$action"
}

scan_networks() {
    device=$(pick_interface wifi || true)
    if [ -z "$device" ]; then
        device=$(iwd_property "$(iwd_first_device || true)" net.connman.iwd.Device Name)
    fi
    [ -n "$device" ] || exit 1

    mkdir -p "$state_root"
    : > "$state_root/scanning"
    timeout "$timeout_seconds" "$iwctl" station "$device" scan >/dev/null 2>&1 || true

    station=$(iwd_station "$device" || true)
    (
        # Hold the marker briefly so the bar can show feedback for a scan that
        # completes between two polls, then wait for iwd to report the scan
        # finished. The loop is bounded so a stuck scan cannot pin the label.
        sleep 1
        tries=0
        while [ "$tries" -lt 100 ]; do
            [ "$(iwd_property "$station" net.connman.iwd.Station Scanning)" = true ] || break
            tries=$((tries + 1))
            sleep 0.2
        done
        # Hold the flag one more interval so the gated list poll picks up the
        # completed scan before it stops itself.
        sleep 1
        rm -f "$state_root/scanning"
    ) >/dev/null 2>&1 &
    exit 0
}

disconnect_network() {
    device=$(pick_interface wifi || true)
    [ -n "$device" ] || exit 1
    exec "$pkexec" "$iwctl" station "$device" disconnect
}

case ${1-} in
    status)
        [ "$#" -eq 1 ] || exit 64
        emit_state
        ;;
    listen)
        [ "$#" -eq 1 ] || exit 64
        while true; do
            emit_state
            sleep "$interval"
        done
        ;;
    networks)
        [ "$#" -eq 1 ] || exit 64
        emit_networks
        ;;
    watch)
        [ "$#" -eq 1 ] || exit 64
        watch_networks
        ;;
    menu)
        [ "$#" -eq 1 ] || exit 64
        menu_networks
        ;;
    scan)
        [ "$#" -eq 1 ] || exit 64
        scan_networks
        ;;
    connect)
        [ "$#" -eq 2 ] || exit 64
        connect_index "$2"
        ;;
    forget)
        [ "$#" -eq 2 ] || exit 64
        forget_index "$2"
        ;;
    add)
        [ "$#" -eq 1 ] || exit 64
        add_network
        ;;
    wifi)
        [ "$#" -eq 2 ] || exit 64
        wifi_radio "$2"
        ;;
    disconnect)
        [ "$#" -eq 1 ] || exit 64
        disconnect_network
        ;;
    *)
        printf 'usage: shell-network-listener status | listen | networks | watch | menu | scan | connect INDEX | forget INDEX | add | wifi on | off | disconnect\n' >&2
        exit 64
        ;;
esac