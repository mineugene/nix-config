#!/bin/sh
# Socket reader for yubikey-touch-detector. Distinguishes the touch-wait phase
# from the PIN-entry phase (upstream's GPG_1 fires for both) by waiting past
# any running pinentry, then drives:
#   - desktop notification (Linux only) with Cancel
#   - shared state file consumed by tmux/starship (both backends)
#
# Usage: yubikey-touch-notify <backend>
#   backend: "linux" (notify-send) or "wsl" (chip-only, no popup)
set -u

BACKEND="${1:-linux}"
gpgconf_command=${YUBIKEY_TOUCH_GPGCONF:-gpgconf}
notify_send=${YUBIKEY_TOUCH_NOTIFY_SEND:-notify-send}
gdbus_command=${YUBIKEY_TOUCH_GDBUS:-gdbus}
socat_command=${YUBIKEY_TOUCH_SOCAT:-socat}
tmux_command=${YUBIKEY_TOUCH_TMUX:-tmux}

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch"
PENDING_FILE="${STATE_DIR}/pending"   # raw GPG_1/GPG_0 state (internal)
STATE_FILE="${STATE_DIR}/active"      # touch-phase state (tmux/starship read this)
mkdir -p "$STATE_DIR" || exit 1
: >"$PENDING_FILE" || exit 1
: >"$STATE_FILE" || exit 1
user_id=$(id -u) || exit 1

readonly TIMEOUT_SECS=15
readonly DEBOUNCE_SECS=0.5

refresh_status_bars() {
    if command -v "$tmux_command" >/dev/null 2>&1 && "$tmux_command" ls >/dev/null 2>&1; then
        "$tmux_command" refresh-client -S 2>/dev/null || true
    fi
}


cancel_request() {
    case "$1" in
        GPG) "$gpgconf_command" --kill scdaemon 2>/dev/null || true ;;
    esac
}

# Block while pinentry is running. Returns 1 if the pending flag clears in the
# meantime (the op resolved during PIN entry).
wait_past_pinentry() {
    while pgrep -u "$user_id" pinentry >/dev/null 2>&1; do
        sleep "$DEBOUNCE_SECS"
        [ -s "$PENDING_FILE" ] || return 1
    done
    return 0
}

close_notification() {
    "$gdbus_command" call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.CloseNotification \
        "uint32 $1" >/dev/null 2>&1 || true
}

monotonic_seconds() {
    read -r uptime _ < /proc/uptime || return 1
    printf '%s\n' "${uptime%%.*}"
}

cleanup_notification() {
    if [ -n "$notify_pid" ]; then
        if IFS= read -r notification_id <"$output"; then
            close_notification "$notification_id"
        fi
        kill "$notify_pid" 2>/dev/null || :
        wait "$notify_pid" 2>/dev/null || :
    fi
    rm -f "$output"
}

notify_linux_loop() {
    reason=$1
    set --
    if [ "$reason" = GPG ]; then set -- --action=cancel=Cancel; fi

    notify_pid=
    notification_id=
    result=
    output=$(mktemp "$STATE_DIR/notification.XXXXXX") || return
    trap cleanup_notification 0
    trap 'exit 0' HUP INT TERM PIPE

    # SwayNC and this module's dunst rules never expire critical popups, so
    # close this one by ID once the request ends. notify-send prints the ID,
    # then any chosen action, and exits when the popup closes or no daemon
    # runs. --expire-time would only end its wait, leaving the popup open.
    "$notify_send" --print-id --wait \
        --urgency=critical \
        "$@" \
        "YubiKey ${reason} touch" \
        "Touch sensor to continue" >"$output" 2>/dev/null &
    notify_pid=$!

    end=$(( $(monotonic_seconds) + TIMEOUT_SECS ))
    while kill -0 "$notify_pid" 2>/dev/null; do
        # Wait for the ID even if the request already ended, so a touch made
        # while the popup appears still closes it.
        if IFS= read -r notification_id <"$output" \
            && { [ ! -s "$PENDING_FILE" ] || [ "$(monotonic_seconds)" -ge "$end" ]; }; then
            close_notification "$notification_id"
            kill "$notify_pid" 2>/dev/null || :
            break
        fi
        sleep 0.1
    done
    wait "$notify_pid" 2>/dev/null || :
    notify_pid=
    { IFS= read -r notification_id || :; IFS= read -r result || :; } <"$output"
    rm -f "$output"

    if [ "$result" = cancel ]; then
        cancel_request "$reason"
    fi
}

ring_terminal_bells() {
    command -v "$tmux_command" >/dev/null 2>&1 && "$tmux_command" ls >/dev/null 2>&1 || return 0
    while IFS= read -r tty; do
        if [ -n "$tty" ] && [ -w "$tty" ]; then printf '\a' >"$tty"; fi
    done <<EOF
$("$tmux_command" list-clients -F '#{client_tty}' 2>/dev/null || :)
EOF
}

touch_phase_loop() {
    reason=$1
    trap - 0
    trap 'exit 0' HUP INT TERM PIPE

    sleep "$DEBOUNCE_SECS"
    [ -s "$PENDING_FILE" ] || return

    if ! wait_past_pinentry; then
        return
    fi

    # Touch phase reached: publish the badge state (tmux/starship read this;
    # held back until now so PIN entry alone never shows the badge), ring
    # terminal bell once for the tab-flash cue, then dispatch backend-specific
    # popup (Linux only).
    echo "$reason" >"$STATE_FILE"
    refresh_status_bars
    ring_terminal_bells

    if [ "$BACKEND" = linux ]; then
        notify_linux_loop "$reason"
    fi
}

on_event_start() {
    reason=$1
    echo "$reason" >"$PENDING_FILE"
    live_phase_pids=
    for phase_pid in $phase_pids; do
        if kill -0 "$phase_pid" 2>/dev/null; then
            live_phase_pids="$live_phase_pids $phase_pid"
        else
            wait "$phase_pid" 2>/dev/null || :
        fi
    done
    touch_phase_loop "$reason" &
    phase_pids="$live_phase_pids $!"
}

# Clear state only when the end event's type matches what is pending;
# an unrelated U2F_0/MAC_0 must not cancel a GPG touch-wait mid-flight.
on_event_end() {
    reason=$1
    pending=$(cat "$PENDING_FILE") || pending=""
    if [ -n "$pending" ] && [ "$pending" != "$reason" ]; then
        return 0
    fi
    : >"$PENDING_FILE"
    : >"$STATE_FILE"
    refresh_status_bars
}

# The detector creates its socket only in the runtime directory.
SOCKET="${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch-detector.socket"

stop_subscriber() {
    if [ -n "$subscriber_pid" ]; then
        kill "$subscriber_pid" 2>/dev/null || :
        wait "$subscriber_pid" 2>/dev/null || :
        subscriber_pid=
    fi
}

cleanup_listener() {
    if [ -n "$reader_pid" ]; then
        kill "$reader_pid" 2>/dev/null || :
        wait "$reader_pid" 2>/dev/null || :
    fi
    stop_subscriber
    for phase_pid in $phase_pids; do
        kill "$phase_pid" 2>/dev/null || :
    done
    for phase_pid in $phase_pids; do
        wait "$phase_pid" 2>/dev/null || :
    done
    : >"$PENDING_FILE"
    : >"$STATE_FILE"
    refresh_status_bars
    rm -rf "$listener_dir"
}

listener_dir=$(mktemp -d "$STATE_DIR/listener.XXXXXX") || exit 1
subscriber_pid=
reader_pid=
phase_pids=
trap cleanup_listener 0
trap 'exit 0' HUP INT TERM PIPE
mkfifo "$listener_dir/events" || exit 1

while :; do
    if [ ! -S "$SOCKET" ]; then
        sleep 2
        continue
    fi
    "$socat_command" -u "UNIX-CONNECT:$SOCKET" STDOUT >"$listener_dir/events" 2>/dev/null &
    subscriber_pid=$!
    # GNU dd's fullblock reads keep fragmented, delimiter-free tokens intact.
    # Background wait keeps signal traps responsive while the socket is idle.
    # HMAC events are wire-named MAC_1/MAC_0.
    while :; do
        dd bs=5 count=1 iflag=fullblock <&3 >"$listener_dir/event" 2>/dev/null &
        reader_pid=$!
        if ! wait "$reader_pid"; then
            reader_pid=
            break
        fi
        reader_pid=
        event=$(cat "$listener_dir/event") || break
        [ "${#event}" -eq 5 ] || break
        echo "event: $event"
        case "$event" in
            GPG_1) on_event_start GPG ;;
            U2F_1) on_event_start U2F ;;
            MAC_1) on_event_start HMAC ;;
            GPG_0) on_event_end GPG ;;
            U2F_0) on_event_end U2F ;;
            MAC_0) on_event_end HMAC ;;
        esac
    done 3<"$listener_dir/events"
    stop_subscriber
    sleep 1
done
