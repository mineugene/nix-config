#!/bin/sh
set -eu
: "${greeterSessionExecutable:?}" "${greeterSessionSource:?}" "${startGreeterSource:?}" "${greeterPath:?}" "${wayfireConfig:?}"
: "${wayfireCommand:?}" "${ewwScss:?}" "${ewwYuck:?}" "${smokeScript:?}" "${smokePath:?}"
: "${dbusRunSession:?}" "${dbusConfig:?}" "${xvfbRun:?}" "${out:?}" "${waitHelpers:?}"
# shellcheck source=/dev/null
. "$waitHelpers"

test -x "$greeterSessionExecutable"
shellcheck --shell=sh "$greeterSessionSource" "$startGreeterSource"
dash -n "$greeterSessionSource"
dash -n "$startGreeterSource"

greeter_test_bin="$TMPDIR/greeter-test-bin"
mkdir -p "$greeter_test_bin"
cat > "$greeter_test_bin/wlr-randr" <<'SH'
#!/bin/sh
if [ "$#" -eq 0 ]; then
    cat <<'EOF'
DP-3 "Primary"
  Enabled: yes
DP-4 "Secondary"
  Enabled: yes
EOF
    exit 0
fi
printf 'wlr-randr:%s\n' "$*" >> "$GREETER_TEST_LOG"
SH
cat > "$greeter_test_bin/eww" <<'SH'
#!/bin/sh
if [ "${XDG_CACHE_HOME:-}" != "$XDG_RUNTIME_DIR" ]; then
    echo 'greeter did not redirect Eww cache into its writable runtime directory' >&2
    exit 99
fi
printf 'eww:%s\n' "$*" >> "$GREETER_TEST_LOG"
[ "${GREETER_EWW_FAIL:-}" != "$3" ]
SH
cat > "$greeter_test_bin/regreet" <<'SH'
#!/bin/sh
printf '%s\n' regreet >> "$GREETER_TEST_LOG"
if [ "${GREETER_REGREET_SIGNAL_PARENT:-0}" -eq 1 ]; then
    kill -TERM "$PPID"
    exit 0
fi
exit "${GREETER_REGREET_STATUS:-0}"
SH
cat > "$greeter_test_bin/wayfire" <<'SH'
#!/bin/sh
printf '%s\n' "$*" > "$GREETER_START_LOG"
cat "$2" > "$GREETER_WAYFIRE_CONFIG_LOG"
printf '%s\n' 0 > "$GREETER_SESSION_STATUS_FILE"
trap 'exit 0' TERM
while :; do sleep 1; done
SH
cat > "$greeter_test_bin/dbus-run-session" <<'SH'
#!/bin/sh
[ "$1" = -- ] && shift
{ [ "$1" = sh ] || [ "$1" = /bin/sh ]; } && shift && exec "$dashCommand" "$@"
exec "$@"
SH
chmod +x "$greeter_test_bin"/*

export PATH="$greeter_test_bin:$greeterPath"
export GREETER_START_LOG="$TMPDIR/greeter-start.log"
export GREETER_WAYFIRE_CONFIG_LOG="$TMPDIR/greeter-wayfire.ini"
export XDG_RUNTIME_DIR="$TMPDIR/greeter-start-runtime"
export GREETER_WAYFIRE_TEMPLATE="$wayfireConfig"
export GREETER_DRM_DIR="$TMPDIR/drm"
mkdir -m 700 "$XDG_RUNTIME_DIR"
mkdir -p "$GREETER_DRM_DIR/card0-DP-3" "$GREETER_DRM_DIR/card0-DP-4"
printf '%s\n' connected > "$GREETER_DRM_DIR/card0-DP-3/status"
printf '%s\n' connected > "$GREETER_DRM_DIR/card0-DP-4/status"
"$startGreeterSource"
test "$(cat "$GREETER_START_LOG")" = "--config $XDG_RUNTIME_DIR/wayfire.ini"
grep -Fq '[output:DP-3]' "$GREETER_WAYFIRE_CONFIG_LOG"
grep -Fq 'mode = auto' "$GREETER_WAYFIRE_CONFIG_LOG"
grep -Fq '[output:DP-4]' "$GREETER_WAYFIRE_CONFIG_LOG"
grep -Fq 'mode = mirror DP-3' "$GREETER_WAYFIRE_CONFIG_LOG"

export HOME=/var/empty
export XDG_RUNTIME_DIR="$TMPDIR/greeter-runtime"
export GREETER_TEST_LOG="$TMPDIR/greeter-test.log"
mkdir -m 700 "$XDG_RUNTIME_DIR"
"$greeterSessionSource"
test "$(cat "$GREETER_TEST_LOG")" = 'eww:--config /etc/greetd/eww daemon
eww:--config /etc/greetd/eww open bar --id bar-0 --screen 0
eww:--config /etc/greetd/eww open motd --id motd-0 --screen 0
eww:--config /etc/greetd/eww open bar --id bar-1 --screen 1
eww:--config /etc/greetd/eww open motd --id motd-1 --screen 1
regreet
eww:--config /etc/greetd/eww kill'

: > "$GREETER_TEST_LOG"
GREETER_EWW_FAIL=daemon "$greeterSessionSource" 2> "$TMPDIR/eww-failure.log"
grep -Fxq regreet "$GREETER_TEST_LOG"
grep -Fq 'greeter: failed to start eww daemon' "$TMPDIR/eww-failure.log"

: > "$GREETER_TEST_LOG"
if GREETER_REGREET_STATUS=23 "$greeterSessionSource" 2> "$TMPDIR/regreet-failure.log"; then
    echo 'greeter session discarded ReGreet failure' >&2
    exit 1
else
    status=$?
fi
test "$status" -eq 23
grep -Fq 'greeter: regreet exited with status 23' "$TMPDIR/regreet-failure.log"
grep -Fq 'eww:--config /etc/greetd/eww kill' "$GREETER_TEST_LOG"

: > "$GREETER_TEST_LOG"
signal_status_file="$TMPDIR/signal-status"
if GREETER_REGREET_SIGNAL_PARENT=1 GREETER_SESSION_STATUS_FILE="$signal_status_file" \
    "$greeterSessionSource" 2> "$TMPDIR/regreet-signal.log"; then
    echo 'greeter session discarded its termination signal' >&2
    exit 1
else
    status=$?
fi
test "$status" -eq 143
test "$(cat "$signal_status_file")" -eq 143
grep -Fq 'eww:--config /etc/greetd/eww kill' "$GREETER_TEST_LOG"

wayfire_runtime="$TMPDIR/wayfire-runtime"
mkdir -m 700 "$wayfire_runtime"
XDG_RUNTIME_DIR="$wayfire_runtime" WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 \
    "$wayfireCommand" --config "$wayfireConfig" > "$TMPDIR/wayfire.log" 2>&1 &
wayfire_pid=$!
trap 'kill -TERM "$wayfire_pid" 2>/dev/null || :; wait "$wayfire_pid" 2>/dev/null || :' EXIT
wayfire_ready() {
    kill -0 "$wayfire_pid" 2>/dev/null || {
        cat "$TMPDIR/wayfire.log" >&2
        exit 1
    }
    wayfire_socket=$(find "$wayfire_runtime" -maxdepth 1 -type s -name 'wayland-*' -print -quit)
    [ -n "$wayfire_socket" ]
}
wait_until wayfire_ready
kill -TERM "$wayfire_pid"
wait "$wayfire_pid"
trap - EXIT

config_dir="$TMPDIR/eww"
mkdir -p "$config_dir"
ln -s "$ewwScss" "$config_dir/eww.scss"
ln -s "$ewwYuck" "$config_dir/eww.yuck"

export HOME="$TMPDIR/home"
export XDG_CACHE_HOME="$TMPDIR/cache"
export XDG_RUNTIME_DIR="$TMPDIR/runtime"
# shellcheck disable=SC2174
mkdir -m 700 -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"

cp "$smokeScript" "$TMPDIR/eww-smoke"
chmod +x "$TMPDIR/eww-smoke"

export PATH="$smokePath"
if ! "$dbusRunSession" --config-file="$dbusConfig" -- \
    "$xvfbRun" -a "$TMPDIR/eww-smoke" "$config_dir" "$TMPDIR/eww.log"; then
    cat "$TMPDIR/eww.log" >&2
    exit 1
fi

touch "$out"
