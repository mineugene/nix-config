#!/bin/sh
set -eu
: "${waitHelpers:?}"
# shellcheck source=/dev/null
. "$waitHelpers"

yubikey_touch_notify=$1
tmp=$2
runtime_dir=$tmp/runtime
socket=$runtime_dir/yubikey-touch-detector.socket
fake_bin=$tmp/bin

mkdir -p "$runtime_dir" "$fake_bin"
socat "UNIX-LISTEN:$socket,fork" OPEN:/dev/null >/dev/null 2>&1 &
socket_pid=$!
notifier_pid=
cleanup() {
    if [ -n "$notifier_pid" ]; then
        kill "$notifier_pid" 2>/dev/null || :
        wait "$notifier_pid" 2>/dev/null || :
    fi
    kill "$socket_pid" 2>/dev/null || :
    wait "$socket_pid" 2>/dev/null || :
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

wait_until test -S "$socket"

cat > "$fake_bin/socat" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$YUBIKEY_TEST_SOCAT_LOG"
if [ -e "$YUBIKEY_TEST_SOCAT_DONE" ]; then
    exec sleep 600
fi
touch "$YUBIKEY_TEST_SOCAT_DONE"
printf '%s' "$YUBIKEY_TEST_START_EVENT"
while [ ! -e "$YUBIKEY_TEST_END" ]; do
    sleep 0.01
done
printf '%s' "$YUBIKEY_TEST_END_EVENT"
SH
cat > "$fake_bin/notify-send" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$YUBIKEY_TEST_NOTIFY_LOG"
case " $* " in
    *' --print-id '*) printf '%s\n' 42 ;;
esac
if [ "${YUBIKEY_TEST_NOTIFY_MODE:-cancel}" = wait ]; then
    while [ ! -e "$YUBIKEY_TEST_CLOSED" ]; do
        sleep 0.01
    done
else
    printf '%s\n' cancel
fi
SH
cat > "$fake_bin/gdbus" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$YUBIKEY_TEST_CLOSE_LOG"
touch "$YUBIKEY_TEST_CLOSED"
SH
cat > "$fake_bin/gpgconf" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$YUBIKEY_TEST_GPGCONF_LOG"
SH
cat > "$fake_bin/tmux" <<'SH'
#!/bin/sh
case ${1-} in
    ls) exit 0 ;;
    list-clients) exit 0 ;;
    *) printf '%s\n' "$*" >> "$YUBIKEY_TEST_TMUX_LOG" ;;
esac
SH
chmod +x "$fake_bin"/*

export XDG_RUNTIME_DIR="$runtime_dir"
export YUBIKEY_TEST_END="$tmp/end-linux"
export YUBIKEY_TEST_END_EVENT=GPG_0
export YUBIKEY_TEST_SOCAT_DONE="$tmp/socat-linux.done"
export YUBIKEY_TEST_SOCAT_LOG="$tmp/socat.log"
export YUBIKEY_TEST_START_EVENT=GPG_1
export YUBIKEY_TEST_NOTIFY_LOG="$tmp/notify.log"
export YUBIKEY_TEST_GPGCONF_LOG="$tmp/gpgconf.log"
export YUBIKEY_TEST_TMUX_LOG="$tmp/tmux.log"
YUBIKEY_TOUCH_GPGCONF="$fake_bin/gpgconf" \
    YUBIKEY_TOUCH_NOTIFY_SEND="$fake_bin/notify-send" \
    YUBIKEY_TOUCH_GDBUS="$fake_bin/gdbus" \
    YUBIKEY_TOUCH_SOCAT="$fake_bin/socat" \
    YUBIKEY_TOUCH_TMUX="$fake_bin/tmux" \
    "$yubikey_touch_notify" linux >/dev/null 2>&1 &
notifier_pid=$!

state_file=$runtime_dir/yubikey-touch/active
wait_until grep -Fxqs GPG "$state_file"
wait_until test -s "$YUBIKEY_TEST_GPGCONF_LOG"
[ -s "$YUBIKEY_TEST_SOCAT_LOG" ]
[ -s "$YUBIKEY_TEST_NOTIFY_LOG" ]
[ "$(cat "$YUBIKEY_TEST_GPGCONF_LOG")" = '--kill scdaemon' ]

touch "$YUBIKEY_TEST_END"
wait_until test ! -s "$state_file"
kill "$notifier_pid"
wait "$notifier_pid" 2>/dev/null || :
notifier_pid=

rm -f "$YUBIKEY_TEST_END"

# SwayNC never expires critical popups, so each finished request must close
# its own popup.
export YUBIKEY_TEST_NOTIFY_MODE=wait
for reason in GPG U2F MAC; do
    export YUBIKEY_TEST_END="$tmp/end-$reason"
    export YUBIKEY_TEST_END_EVENT="${reason}_0"
    export YUBIKEY_TEST_START_EVENT="${reason}_1"
    export YUBIKEY_TEST_SOCAT_DONE="$tmp/socat-$reason.done"
    export YUBIKEY_TEST_NOTIFY_LOG="$tmp/notify-$reason.log"
    export YUBIKEY_TEST_CLOSE_LOG="$tmp/close-$reason.log"
    export YUBIKEY_TEST_CLOSED="$tmp/closed-$reason"
    YUBIKEY_TOUCH_GPGCONF="$fake_bin/gpgconf" \
        YUBIKEY_TOUCH_NOTIFY_SEND="$fake_bin/notify-send" \
        YUBIKEY_TOUCH_GDBUS="$fake_bin/gdbus" \
        YUBIKEY_TOUCH_SOCAT="$fake_bin/socat" \
        YUBIKEY_TOUCH_TMUX="$fake_bin/tmux" \
        "$yubikey_touch_notify" linux >/dev/null 2>&1 &
    notifier_pid=$!

    wait_until test -s "$YUBIKEY_TEST_NOTIFY_LOG"
    touch "$YUBIKEY_TEST_END"
    wait_until test -e "$YUBIKEY_TEST_CLOSED"
    grep -q -- '--method org.freedesktop.Notifications.CloseNotification uint32 42$' "$YUBIKEY_TEST_CLOSE_LOG"
    kill "$notifier_pid"
    wait "$notifier_pid" 2>/dev/null || :
    notifier_pid=
done

export YUBIKEY_TEST_END="$tmp/end-wsl"
export YUBIKEY_TEST_END_EVENT=U2F_0
export YUBIKEY_TEST_NOTIFY_LOG="$tmp/notify-wsl.log"
export YUBIKEY_TEST_SOCAT_DONE="$tmp/socat-wsl.done"
export YUBIKEY_TEST_START_EVENT=U2F_1
YUBIKEY_TOUCH_GPGCONF="$fake_bin/gpgconf" \
    YUBIKEY_TOUCH_NOTIFY_SEND="$fake_bin/notify-send" \
    YUBIKEY_TOUCH_SOCAT="$fake_bin/socat" \
    YUBIKEY_TOUCH_TMUX="$fake_bin/tmux" \
    "$yubikey_touch_notify" wsl >/dev/null 2>&1 &
notifier_pid=$!

wait_until grep -Fxqs U2F "$state_file"
touch "$YUBIKEY_TEST_END"
wait_until test ! -s "$state_file"
[ ! -s "$YUBIKEY_TEST_NOTIFY_LOG" ]
