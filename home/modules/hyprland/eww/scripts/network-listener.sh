#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

nmcli=${EWW_NETWORK_NMCLI:-nmcli}
clock=${EWW_NETWORK_DATE:-date}
sys_root=${EWW_NETWORK_SYS_ROOT:-/sys}
interval=${EWW_NETWORK_INTERVAL:-2}
previous_interface=
previous_rx=0
previous_tx=0
previous_time=0

unavailable() {
    jq -nc '{state:"unavailable",connected:false,kind:"none",interface:"",name:"Unavailable",signal:null,ip:"",rx_bytes_per_second:0,tx_bytes_per_second:0}'
}

read_rate() {
    local interface now rx tx elapsed

    interface=$1
    now=$("$clock" +%s)
    rx=0
    tx=0
    [[ -r "$sys_root/class/net/$interface/statistics/rx_bytes" ]] && read -r rx < "$sys_root/class/net/$interface/statistics/rx_bytes"
    [[ -r "$sys_root/class/net/$interface/statistics/tx_bytes" ]] && read -r tx < "$sys_root/class/net/$interface/statistics/tx_bytes"

    rx_rate=0
    tx_rate=0
    if [[ $previous_interface == "$interface" ]] && (( previous_time > 0 && now > previous_time )); then
        elapsed=$((now - previous_time))
        (( rx >= previous_rx )) && rx_rate=$(((rx - previous_rx) / elapsed))
        (( tx >= previous_tx )) && tx_rate=$(((tx - previous_tx) / elapsed))
    fi

    previous_interface=$interface
    previous_rx=$rx
    previous_tx=$tx
    previous_time=$now
}

emit() {
    local devices interface type device_state name kind state connected signal ip
    local marker strength ssid rx_rate tx_rate

    if ! devices=$("$nmcli" --terse --escape no --fields DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null); then
        unavailable
        return
    fi

    interface=
    type=
    device_state=disconnected
    name=
    while IFS=: read -r candidate_interface candidate_type candidate_state candidate_name; do
        case $candidate_state in
            connected*)
                interface=$candidate_interface
                type=$candidate_type
                device_state=connected
                name=$candidate_name
                break
                ;;
            connecting*)
                if [[ -z $interface ]]; then
                    interface=$candidate_interface
                    type=$candidate_type
                    device_state=connecting
                    name=$candidate_name
                fi
                ;;
        esac
    done <<< "$devices"

    connected=false
    signal=null
    ip=
    case $type in
        wifi) kind=wifi ;;
        ethernet) kind=wired ;;
        "") kind=none ;;
        *) kind=other ;;
    esac

    if [[ $device_state == connected ]]; then
        connected=true
        state=$kind
        [[ $state == other ]] && state=connected
        if [[ $kind == wifi ]]; then
            while IFS=: read -r marker strength ssid; do
                if [[ $marker == "*" ]]; then
                    [[ $strength =~ ^[0-9]+$ ]] && signal=$strength
                    [[ -n $ssid ]] && name=$ssid
                    break
                fi
            done < <("$nmcli" --terse --escape no --fields IN-USE,SIGNAL,SSID device wifi list ifname "$interface" 2>/dev/null || true)
        fi
        ip=$("$nmcli" --get-values IP4.ADDRESS device show "$interface" 2>/dev/null | head -n 1 || true)
        read_rate "$interface"
    elif [[ $device_state == connecting ]]; then
        state=connecting
        rx_rate=0
        tx_rate=0
    else
        state=disconnected
        rx_rate=0
        tx_rate=0
        name=Disconnected
    fi

    jq -nc \
        --arg state "$state" \
        --argjson connected "$connected" \
        --arg kind "$kind" \
        --arg interface "$interface" \
        --arg name "${name:-$interface}" \
        --argjson signal "$signal" \
        --arg ip "$ip" \
        --argjson rx "$rx_rate" \
        --argjson tx "$tx_rate" \
        '{state:$state,connected:$connected,kind:$kind,interface:$interface,name:$name,signal:$signal,ip:$ip,rx_bytes_per_second:$rx,tx_bytes_per_second:$tx}'
}

case ${1-} in
    status)
        (( $# == 1 )) || exit 64
        emit
        ;;
    listen)
        (( $# == 1 )) || exit 64
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
