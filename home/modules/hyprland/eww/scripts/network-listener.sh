#!/bin/sh
set -eu
export LC_ALL=C

nmcli=${EWW_NETWORK_NMCLI:-nmcli}
clock=${EWW_NETWORK_DATE:-date}
sys_root=${EWW_NETWORK_SYS_ROOT:-/sys}
interval=${EWW_NETWORK_INTERVAL:-2}

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

is_up() (
    interface=$1
    [ -r "$sys_root/class/net/$interface/operstate" ] || return 1
    read -r operstate < "$sys_root/class/net/$interface/operstate" || return 1
    [ "$operstate" != down ]
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

wifi_signal() {
    wifi_rows=$("$nmcli" --terse --escape no --fields IN-USE,SIGNAL,SSID \
        device wifi list ifname "$1" 2>/dev/null || true)
    while IFS=: read -r wifi_marker wifi_strength wifi_ssid; do
        if [ "$wifi_marker" = '*' ]; then
            case $wifi_strength in
                '' | *[!0-9]*) ;;
                *) signal=$wifi_strength ;;
            esac
            [ -z "$wifi_ssid" ] || name=$wifi_ssid
            break
        fi
    done <<EOF
$wifi_rows
EOF
}

kind_json() (
    kind=$1
    devices=$2
    connectivity=$3
    interface=$4
    # Measurements arrive from the parent so the cache survives substitutions.
    kind_rx_rate=$5
    kind_tx_rate=$6

    if [ -z "$interface" ]; then
        jq -nc --arg kind "$kind" \
            '{kind:$kind,available:false,state:"unavailable",connected:false,internet:false,
              interface:"",name:"Unavailable",signal:null,ip:"",
              rx_bytes_per_second:0,tx_bytes_per_second:0}'
        return
    fi

    state=disconnected
    name=$interface
    signal=null
    ip=

    if [ -n "$devices" ]; then
        while IFS=: read -r candidate_interface candidate_type candidate_state candidate_name; do
            [ "$candidate_type" = "$kind" ] || continue
            [ "$candidate_interface" = "$interface" ] || continue
            case $candidate_state in
                connected*) state=connected ;;
                connecting*) state=connecting ;;
                unavailable*) state=unavailable ;;
                *) state=disconnected ;;
            esac
            [ -z "$candidate_name" ] || name=$candidate_name
            break
        done <<EOF
$devices
EOF

        if [ "$kind" = wifi ] && [ "$state" != connected ]; then
            if [ "$("$nmcli" radio wifi 2>/dev/null || true)" = disabled ]; then
                state=off
            fi
        fi
    elif is_carrying "$interface"; then
        state=connected
    fi

    # A down interface cannot reconnect until brought up, unlike an idle link.
    if [ "$state" = disconnected ] && ! is_up "$interface"; then
        state=unavailable
    fi

    if [ "$state" = connected ]; then
        if [ -n "$devices" ]; then
            if [ "$kind" = wifi ]; then wifi_signal "$interface"; fi
            ip=$("$nmcli" --get-values IP4.ADDRESS device show "$interface" 2>/dev/null | head -n 1 || true)
        fi
    else
        kind_rx_rate=0
        kind_tx_rate=0
    fi

    case $state in
        off)
            if [ "$kind" = wifi ]; then name='Wi-Fi disabled'; else name=Disabled; fi
            ;;
        unavailable) name=Unavailable ;;
        disconnected) name=Disconnected ;;
    esac
    internet=false
    if [ "$state" = connected ] && [ "$connectivity" = full ]; then internet=true; fi

    jq -nc \
        --arg kind "$kind" \
        --arg state "$state" \
        --arg interface "$interface" \
        --arg name "$name" \
        --argjson signal "$signal" \
        --arg ip "$ip" \
        --argjson internet "$internet" \
        --argjson rx "$kind_rx_rate" \
        --argjson tx "$kind_tx_rate" \
        '{kind:$kind,available:true,state:$state,connected:($state == "connected"),
          internet:$internet,interface:$interface,name:$name,signal:$signal,ip:$ip,
          rx_bytes_per_second:$rx,tx_bytes_per_second:$tx}'
)

emit() {
    devices=$("$nmcli" --terse --escape no --fields DEVICE,TYPE,STATE,CONNECTION \
        device status 2>/dev/null || true)
    connectivity=full
    if [ -n "$devices" ]; then
        connectivity=$("$nmcli" networking connectivity 2>/dev/null || echo full)
    fi

    wifi_interface=$(pick_interface wifi)
    ethernet_interface=$(pick_interface ethernet)
    wifi_rx=0
    wifi_tx=0
    ethernet_rx=0
    ethernet_tx=0
    if [ -n "$wifi_interface" ]; then
        read_rate "$wifi_interface"
        wifi_rx=$rx_rate
        wifi_tx=$tx_rate
    fi
    if [ -n "$ethernet_interface" ]; then
        read_rate "$ethernet_interface"
        ethernet_rx=$rx_rate
        ethernet_tx=$tx_rate
    fi

    wifi=$(kind_json wifi "$devices" "$connectivity" "$wifi_interface" "$wifi_rx" "$wifi_tx")
    ethernet=$(kind_json ethernet "$devices" "$connectivity" \
        "$ethernet_interface" "$ethernet_rx" "$ethernet_tx")

    jq -nc --argjson wifi "$wifi" --argjson ethernet "$ethernet" \
        '{wifi:$wifi,ethernet:$ethernet,
          primary:(if $ethernet.connected then $ethernet
                   elif $wifi.connected then $wifi
                   elif $ethernet.available then $ethernet
                   else $wifi end)}'
}

case ${1-} in
    status)
        [ "$#" -eq 1 ] || exit 64
        emit
        ;;
    listen)
        [ "$#" -eq 1 ] || exit 64
        while true; do
            emit
            sleep "$interval"
        done
        ;;
    *)
        printf 'usage: eww-network-listener status | listen\n' >&2
        exit 64
        ;;
esac
