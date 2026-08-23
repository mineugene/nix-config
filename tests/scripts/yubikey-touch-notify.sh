#!/bin/sh
set -eu

yubikey_touch_notify=$1
tmp=$2
runtime_dir=$tmp/runtime
socket=$runtime_dir/yubikey-touch-detector.socket
fake_bin=$tmp/bin

mkdir -p "$runtime_dir" "$fake_bin"
socat "UNIX-LISTEN:$socket,fork" OPEN:/dev/null >/dev/null 2>&1 &
socket_pid=$!
cleanup() {
    kill "$notifier_pid" "$socket_pid" 2>/dev/null || :
    wait "$notifier_pid" "$socket_pid" 2>/dev/null || :
}
trap cleanup 0 HUP INT TERM

for _ in $(seq 1 100); do
    [ -S "$socket" ] && break
    sleep 0.01
done
[ -S "$socket" ]

cat > "$fake_bin/socat" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$YUBIKEY_TEST_SOCAT_LOG"
if [ -e "$YUBIKEY_TEST_SOCAT_DONE" ]; then
    sleep 60
    exit 0
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
printf '%s\n' cancel
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
    YUBIKEY_TOUCH_SOCAT="$fake_bin/socat" \
    YUBIKEY_TOUCH_TMUX="$fake_bin/tmux" \
    "$yubikey_touch_notify" linux >/dev/null 2>&1 &
notifier_pid=$!

state_file=$runtime_dir/yubikey-touch/active
for _ in $(seq 1 200); do
    [ -s "$state_file" ] && break
    sleep 0.01
done
[ "$(cat "$state_file")" = GPG ]

for _ in $(seq 1 200); do
    [ -s "$YUBIKEY_TEST_NOTIFY_LOG" ] && break
    sleep 0.01
done
[ -s "$YUBIKEY_TEST_SOCAT_LOG" ]
[ -s "$YUBIKEY_TEST_NOTIFY_LOG" ]
[ "$(cat "$YUBIKEY_TEST_GPGCONF_LOG")" = '--kill scdaemon' ]

touch "$YUBIKEY_TEST_END"
for _ in $(seq 1 200); do
    [ ! -s "$state_file" ] && break
    sleep 0.01
done
[ ! -s "$state_file" ]
kill "$notifier_pid"
wait "$notifier_pid" 2>/dev/null || :

rm -f "$YUBIKEY_TEST_END"
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

for _ in $(seq 1 200); do
    [ -s "$state_file" ] && break
    sleep 0.01
done
[ "$(cat "$state_file")" = U2F ]
touch "$YUBIKEY_TEST_END"
for _ in $(seq 1 200); do
    [ ! -s "$state_file" ] && break
    sleep 0.01
done
[ ! -s "$state_file" ]
[ ! -s "$YUBIKEY_TEST_NOTIFY_LOG" ]
