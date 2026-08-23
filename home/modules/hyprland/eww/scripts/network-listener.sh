#!/usr/bin/env bash
# Bash is required for here strings, process substitution and the per-interface
# rate cache, none of which survive a POSIX rewrite without losing state.
set -euo pipefail
export LC_ALL=C

nmcli=${EWW_NETWORK_NMCLI:-nmcli}
clock=${EWW_NETWORK_DATE:-date}
sys_root=${EWW_NETWORK_SYS_ROOT:-/sys}
interval=${EWW_NETWORK_INTERVAL:-2}

# Counters are cached per interface because Wi-Fi and Ethernet are reported
# together; a single previous-interface slot would blank whichever link was
# not sampled last.
declare -A previous_rx=()
declare -A previous_tx=()
declare -A previous_time=()

is_virtual_interface() {
    case $1 in
        br-* | docker* | lo | podman* | tap* | tun* | veth* | virbr* | wg*) return 0 ;;
        *) return 1 ;;
    esac
}

# Capability is read from the kernel, never from nmcli: a machine keeps its
# radio when the radio is switched off, and the control has to stay visible for
# the user to switch it back on.
interfaces_of_kind() {
    local kind interface

    kind=$1
    for interface in "$sys_root"/class/net/*; do
        [[ -d $interface ]] || continue
        interface=${interface##*/}
        is_virtual_interface "$interface" && continue
        case $kind in
            wifi) [[ -d $sys_root/class/net/$interface/wireless ]] || continue ;;
            ethernet) [[ -d $sys_root/class/net/$interface/wireless ]] && continue ;;
        esac
        printf '%s\n' "$interface"
    done
}

# Both files are read defensively: carrier is unreadable while a device is
# down, which under set -e would take the whole listener with it.
# A down interface is not a disconnected one: nothing can be done with it
# until it is brought up, which is the same dead end as a blocked radio.
is_up() {
    local interface operstate

    interface=$1
    [[ -r $sys_root/class/net/$interface/operstate ]] || return 1
    read -r operstate < "$sys_root/class/net/$interface/operstate"
    [[ $operstate != down ]]
}

is_carrying() {
    local interface operstate carrier

    interface=$1
    [[ -r $sys_root/class/net/$interface/operstate ]] || return 1
    read -r operstate < "$sys_root/class/net/$interface/operstate"
    [[ $operstate == up ]] || return 1

    [[ -r $sys_root/class/net/$interface/carrier ]] || return 1
    read -r carrier < "$sys_root/class/net/$interface/carrier"
    [[ $carrier == 1 ]]
}

# Prefer a link that is actually up, so a machine with several interfaces of one
# kind reports the one carrying traffic rather than the first one enumerated.
pick_interface() {
    local kind interface first

    kind=$1
    first=
    while read -r interface; do
        [[ -n $first ]] || first=$interface
        if is_carrying "$interface"; then
            printf '%s\n' "$interface"
            return
        fi
    done < <(interfaces_of_kind "$kind")
    printf '%s\n' "$first"
}

read_rate() {
    local interface now rx tx elapsed last

    interface=$1
    now=$("$clock" +%s)
    rx=0
    tx=0
    [[ -r "$sys_root/class/net/$interface/statistics/rx_bytes" ]] &&
        read -r rx < "$sys_root/class/net/$interface/statistics/rx_bytes"
    [[ -r "$sys_root/class/net/$interface/statistics/tx_bytes" ]] &&
        read -r tx < "$sys_root/class/net/$interface/statistics/tx_bytes"

    rx_rate=0
    tx_rate=0
    last=${previous_time[$interface]:-0}
    if ((last > 0 && now > last)); then
        elapsed=$((now - last))
        ((rx >= previous_rx[$interface])) && rx_rate=$(((rx - previous_rx[$interface]) / elapsed))
        ((tx >= previous_tx[$interface])) && tx_rate=$(((tx - previous_tx[$interface]) / elapsed))
    fi

    previous_rx[$interface]=$rx
    previous_tx[$interface]=$tx
    previous_time[$interface]=$now
}

wifi_signal() {
    local interface marker strength ssid

    interface=$1
    while IFS=: read -r marker strength ssid; do
        if [[ $marker == "*" ]]; then
            [[ $strength =~ ^[0-9]+$ ]] && signal=$strength
            [[ -n $ssid ]] && name=$ssid
            break
        fi
    done < <("$nmcli" --terse --escape no --fields IN-USE,SIGNAL,SSID \
        device wifi list ifname "$interface" 2>/dev/null || true)
}

# One kind's state, as its own object. Both are reported every cycle, so the
# bar can show a link that is present but idle instead of hiding it behind
# whichever link happened to win a priority contest.
kind_json() {
    local kind devices connectivity interface rx_rate tx_rate state name signal ip
    local candidate_interface candidate_type candidate_state candidate_name

    kind=$1
    devices=$2
    connectivity=$3
    interface=$4
    # Rates arrive as arguments because this function is called in a command
    # substitution: anything it measured would die with that subshell, and the
    # counters only mean something across two samples.
    rx_rate=$5
    tx_rate=$6

    if [[ -z $interface ]]; then
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

    if [[ -n $devices ]]; then
        while IFS=: read -r candidate_interface candidate_type candidate_state candidate_name; do
            [[ $candidate_type == "$kind" ]] || continue
            [[ $candidate_interface == "$interface" ]] || continue
            case $candidate_state in
                connected*) state=connected ;;
                connecting*) state=connecting ;;
                unavailable*) state=unavailable ;;
                *) state=disconnected ;;
            esac
            [[ -n $candidate_name ]] && name=$candidate_name
            break
        done <<< "$devices"

        if [[ $kind == wifi && $state != connected ]]; then
            [[ $("$nmcli" radio wifi 2>/dev/null || true) == disabled ]] && state=off
        fi
    elif is_carrying "$interface"; then
        # Without nmcli the kernel is the only source, and a carrying link is
        # the closest observable thing to a connection.
        state=connected
    fi

    # Applies to both sources: nmcli calls an unmanaged down interface
    # disconnected, and the kernel-only path has no better word for it either.
    if [[ $state == disconnected ]] && ! is_up "$interface"; then
        state=unavailable
    fi

    if [[ $state == connected ]]; then
        if [[ -n $devices ]]; then
            [[ $kind == wifi ]] && wifi_signal "$interface"
            ip=$("$nmcli" --get-values IP4.ADDRESS device show "$interface" 2>/dev/null | head -n 1 || true)
        fi
    else
        rx_rate=0
        tx_rate=0
    fi

    case $state in
        off) name=$([[ $kind == wifi ]] && echo "Wi-Fi disabled" || echo "Disabled") ;;
        unavailable) name=Unavailable ;;
        disconnected) name=Disconnected ;;
    esac

    jq -nc \
        --arg kind "$kind" \
        --arg state "$state" \
        --arg interface "$interface" \
        --arg name "$name" \
        --argjson signal "$signal" \
        --arg ip "$ip" \
        --argjson internet "$([[ $state == connected && $connectivity == full ]] && echo true || echo false)" \
        --argjson rx "$rx_rate" \
        --argjson tx "$tx_rate" \
        '{kind:$kind,available:true,state:$state,connected:($state == "connected"),
          internet:$internet,interface:$interface,name:$name,signal:$signal,ip:$ip,
          rx_bytes_per_second:$rx,tx_bytes_per_second:$tx}'
}

emit() {
    local devices connectivity wifi ethernet
    local wifi_interface ethernet_interface wifi_rx wifi_tx ethernet_rx ethernet_tx

    devices=$("$nmcli" --terse --escape no --fields DEVICE,TYPE,STATE,CONNECTION \
        device status 2>/dev/null || true)
    connectivity=$([[ -n $devices ]] && "$nmcli" networking connectivity 2>/dev/null || echo full)

    # Sampled here, in the parent shell, so the counter cache survives between
    # cycles; kind_json runs in a subshell and cannot keep it.
    wifi_interface=$(pick_interface wifi)
    ethernet_interface=$(pick_interface ethernet)
    wifi_rx=0
    wifi_tx=0
    ethernet_rx=0
    ethernet_tx=0
    if [[ -n $wifi_interface ]]; then
        read_rate "$wifi_interface"
        wifi_rx=$rx_rate
        wifi_tx=$tx_rate
    fi
    if [[ -n $ethernet_interface ]]; then
        read_rate "$ethernet_interface"
        ethernet_rx=$rx_rate
        ethernet_tx=$tx_rate
    fi

    wifi=$(kind_json wifi "$devices" "$connectivity" "$wifi_interface" "$wifi_rx" "$wifi_tx")
    ethernet=$(kind_json ethernet "$devices" "$connectivity" \
        "$ethernet_interface" "$ethernet_rx" "$ethernet_tx")

    # The popup describes one link, so a primary is chosen here rather than in
    # markup: Ethernet outranks Wi-Fi when both carry traffic.
    jq -nc --argjson wifi "$wifi" --argjson ethernet "$ethernet" \
        '{wifi:$wifi,ethernet:$ethernet,
          primary:(if $ethernet.connected then $ethernet
                   elif $wifi.connected then $wifi
                   elif $ethernet.available then $ethernet
                   else $wifi end)}'
}

case ${1-} in
    status)
        (($# == 1)) || exit 64
        emit
        ;;
    listen)
        (($# == 1)) || exit 64
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
