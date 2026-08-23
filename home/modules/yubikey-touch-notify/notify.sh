#!/usr/bin/env bash
# Socket reader for yubikey-touch-detector. Distinguishes the touch-wait phase
# from the PIN-entry phase (upstream's GPG_1 fires for both) by waiting past
# any running pinentry, then drives:
#   - dunst notification (Linux only) with countdown + Cancel
#   - shared state file consumed by tmux/starship (both backends)
#
# Usage: yubikey-touch-notify <backend>
#   backend: "linux" (notify-send via dunst) or "wsl" (chip-only, no popup)
set -uo pipefail

BACKEND="${1:-linux}"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch"
PENDING_FILE="${STATE_DIR}/pending"   # raw GPG_1/GPG_0 state (internal)
STATE_FILE="${STATE_DIR}/active"      # touch-phase state (tmux/starship read this)
mkdir -p "$STATE_DIR"
: >"$PENDING_FILE"
: >"$STATE_FILE"

resolve_gpghome() {
    if [[ -n "${GNUPGHOME:-}" && -d "$GNUPGHOME" ]]; then
        printf '%s\n' "$GNUPGHOME"
    elif [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/gnupg" ]]; then
        printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/gnupg"
    else
        printf '%s\n' "$HOME/.gnupg"
    fi
}

resolve_socket() {
    local gpghome
    gpghome=$(resolve_gpghome)
    local candidates=(
        "${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch-detector.socket"
        "$gpghome/yubikey-touch-detector.socket"
        "$HOME/.gnupg/yubikey-touch-detector.socket"
    )
    for sock in "${candidates[@]}"; do
        [[ -S "$sock" ]] && { printf '%s\n' "$sock"; return 0; }
    done
    return 1
}

readonly TIMEOUT_SECS=15
readonly SYNC_NAME="yubikey-touch"
readonly DEBOUNCE_SECS=0.5

refresh_status_bars() {
    if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
        tmux refresh-client -S 2>/dev/null || true
    fi
}

# Toggle @yk-touching user option; tmux's window-status-current-format reads it
# (via #{E:@yk-touching}) and paints the active window love-bg. Scoped to active
# only by where the check lives in the format, not by what we set here.
WINDOW_FLASH_ACTIVE=0
flash_window_current_on() {
    command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1 || return 0
    (( WINDOW_FLASH_ACTIVE )) && return 0
    tmux set-option -g @yk-touching 1 2>/dev/null || true
    WINDOW_FLASH_ACTIVE=1
}
flash_window_current_off() {
    command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1 || return 0
    (( WINDOW_FLASH_ACTIVE )) || return 0
    tmux set-option -gu @yk-touching 2>/dev/null || true
    WINDOW_FLASH_ACTIVE=0
}
trap 'flash_window_current_off' EXIT


cancel_request() {
    case "$1" in
        GPG) gpgconf --kill scdaemon 2>/dev/null || true ;;
    esac
}

# Block while pinentry is running. Returns 1 if the pending flag clears in the
# meantime (the op resolved during PIN entry).
wait_past_pinentry() {
    while pgrep -u "$UID" pinentry >/dev/null 2>&1; do
        sleep "$DEBOUNCE_SECS"
        [[ -s "$PENDING_FILE" ]] || return 1
    done
    return 0
}

notify_linux_loop() {
    local reason="$1"
    local action_args=()
    [[ "$reason" == "GPG" ]] && action_args+=(--action=cancel=Cancel)

    local end=$(( SECONDS + TIMEOUT_SECS ))
    while [[ -s "$PENDING_FILE" ]]; do
        local remaining=$(( end - SECONDS ))
        (( remaining <= 0 )) && break

        # This loop has no sleep on purpose: with --action, notify-send blocks
        # until the notification is dismissed or expires, and that block is
        # what paces the countdown. When no notification daemon is running --
        # a host with no Wayland compositor, so dunst never starts -- the call
        # returns immediately instead, and the loop would spin for the whole
        # TIMEOUT_SECS window. Bail on the first failure: the popup is
        # unavailable, but ring_terminal_bells and the tmux/starship state
        # file below still work, which is the useful part on a TTY anyway.
        local result
        result=$(notify-send \
            --urgency=critical \
            --expire-time=1100 \
            --hint=string:x-canonical-private-synchronous:"$SYNC_NAME" \
            "${action_args[@]}" \
            "YubiKey ${reason} touch" \
            "Touch sensor; ${remaining}s remaining" 2>/dev/null) || break

        if [[ "$result" == "cancel" ]]; then
            cancel_request "$reason"
            break
        fi
    done
}

ring_terminal_bells() {
    command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1 || return 0
    while IFS= read -r tty; do
        [[ -n "$tty" && -w "$tty" ]] && printf '\a' >"$tty"
    done < <(tmux list-clients -F '#{client_tty}' 2>/dev/null)
}

touch_phase_loop() {
    local reason="$1"

    sleep "$DEBOUNCE_SECS"
    [[ -s "$PENDING_FILE" ]] || return

    if ! wait_past_pinentry; then
        return
    fi

    # Touch phase reached: ring terminal bell once for the tab-flash cue,
    # then dispatch backend-specific popup (Linux only).
    ring_terminal_bells

    if [[ "$BACKEND" == "linux" ]]; then
        notify_linux_loop "$reason"
    fi
}

on_event_start() {
    local reason="$1"
    echo "$reason" >"$PENDING_FILE"
    echo "$reason" >"$STATE_FILE"
    flash_window_current_on
    refresh_status_bars
    touch_phase_loop "$reason" &
}

# Clear state only when the end event's type matches what is pending;
# an unrelated U2F_0/MAC_0 must not cancel a GPG touch-wait mid-flight.
on_event_end() {
    local reason="$1"
    local pending
    pending=$(<"$PENDING_FILE") || pending=""
    if [[ -n "$pending" && "$pending" != "$reason" ]]; then
        return 0
    fi
    : >"$PENDING_FILE"
    : >"$STATE_FILE"
    flash_window_current_off
    refresh_status_bars
}

SOCKET=""
while [[ -z "$SOCKET" ]]; do
    SOCKET=$(resolve_socket) || { sleep 2; SOCKET=""; }
done

while :; do
    if [[ ! -S "$SOCKET" ]]; then
        SOCKET=$(resolve_socket) || { sleep 2; continue; }
    fi
    # Upstream writes fixed-width 5-byte tokens with no delimiter; read in
    # exact chunks (-N never stops early on a delimiter byte). HMAC events
    # are wire-named MAC_1/MAC_0.
    while IFS= read -r -N 5 event; do
        echo "event: $event"
        case "$event" in
            GPG_1) on_event_start GPG ;;
            U2F_1) on_event_start U2F ;;
            MAC_1) on_event_start HMAC ;;
            GPG_0) on_event_end GPG ;;
            U2F_0) on_event_end U2F ;;
            MAC_0) on_event_end HMAC ;;
        esac
    done < <(socat -u "UNIX-CONNECT:$SOCKET" STDOUT 2>/dev/null)
    sleep 1
done
