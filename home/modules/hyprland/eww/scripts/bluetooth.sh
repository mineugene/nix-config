#!/bin/sh
set -eu

bluetoothctl=${EWW_BLUETOOTHCTL:-bluetoothctl}
sys_root=${EWW_BLUETOOTH_SYS_ROOT:-/sys}

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

    devices=$(timeout 1 "$bluetoothctl" devices Connected 2>/dev/null || true)
    [ -n "$devices" ] || return 0
    connected=true

    # The loop is a pipeline stage, so it cannot assign to the caller: it
    # reports an audio device by exiting non-zero instead.
    printf '%s\n' "$devices" | while IFS=' ' read -r keyword address _; do
        [ "$keyword" = Device ] || continue
        info=$(timeout 1 "$bluetoothctl" info "$address" 2>/dev/null || true)
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
    if ! output=$(timeout 1 "$bluetoothctl" show 2>/dev/null); then
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
    *)
        printf 'usage: eww-bluetooth status | toggle\n' >&2
        exit 2
        ;;
esac
