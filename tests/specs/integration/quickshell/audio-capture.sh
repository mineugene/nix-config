#!/bin/sh
set -eu
: "${captureRoutingConfig:?}"

work=$(mktemp -d)
pipewire_pid=
pulse_pid=
wireplumber_pid=
capture_pid=
cleanup() {
    test -z "$capture_pid" || kill "$capture_pid" 2>/dev/null || :
    test -z "$wireplumber_pid" || kill "$wireplumber_pid" 2>/dev/null || :
    test -z "$pulse_pid" || kill "$pulse_pid" 2>/dev/null || :
    test -z "$pipewire_pid" || kill "$pipewire_pid" 2>/dev/null || :
    wait 2>/dev/null || :
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
export XDG_RUNTIME_DIR="$work"
export XDG_CONFIG_HOME="$work/config"
export XDG_STATE_HOME="$work/state"
export XDG_DATA_HOME="$work/data"
export XDG_CACHE_HOME="$work/cache"
export PIPEWIRE_RUNTIME_DIR="$work"
export PIPEWIRE_REMOTE=pipewire-0
export WIREPLUMBER_DEBUG=openxlr-capture:I
mkdir -p "$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d"
cp "$captureRoutingConfig" "$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d/90-capture-routing.conf"

app_id() {
    pw-dump | jq -r '.[] | select(.type == "PipeWire:Interface:Node") | select(.info.props["application.process.binary"] == "capture.test") | .id' | head -n 1
}

linked_source() {
    pw-link -l | awk '
        /^test_source_[ab]:capture_/ {
            source = $1
            sub(/:.*/, "", source)
            getline
            if ($0 ~ /\|->[[:space:]]*parec:input_/) {
                print source
                exit
            }
        }
    '
}

wait_source() {
    expected=$1
    attempt=0
    while test "$attempt" -lt 250; do
        actual=$(linked_source)
        if test "$actual" = "$expected"; then
            printf 'linked source: %s\n' "${actual:-none}"
            return
        fi
        sleep 0.02
        attempt=$((attempt + 1))
    done
    printf 'expected source %s, got %s\n' "${expected:-none}" "${actual:-none}" >&2
    return 1
}

start_wireplumber() {
    wireplumber --profile policy >"$work/wireplumber.log" 2>&1 &
    wireplumber_pid=$!
    attempt=0
    while test "$attempt" -lt 250; do
        if grep -q 'capture target restore ready' "$work/wireplumber.log"; then
            return
        fi
        sleep 0.02
        attempt=$((attempt + 1))
    done
    cat "$work/wireplumber.log" >&2
    return 1
}

stop_wireplumber() {
    kill "$wireplumber_pid" 2>/dev/null || :
    wait "$wireplumber_pid" 2>/dev/null || :
    wireplumber_pid=
}

start_capture() {
    if test "$#" -gt 0; then
        parec -d "$1" --format=s16le --rate=48000 --channels=2 --latency-msec=22 \
            --property=application.process.binary=capture.test \
            >"$work/capture.raw" 2>"$work/capture.log" &
    else
        parec --format=s16le --rate=48000 --channels=2 --latency-msec=22 \
            --property=application.process.binary=capture.test \
            >"$work/capture.raw" 2>"$work/capture.log" &
    fi
    capture_pid=$!
    attempt=0
    while test "$attempt" -lt 250; do
        if test -n "$(app_id)"; then
            return
        fi
        sleep 0.02
        attempt=$((attempt + 1))
    done
    cat "$work/capture.log" >&2
    return 1
}

stop_capture() {
    kill "$capture_pid" 2>/dev/null || :
    wait "$capture_pid" 2>/dev/null || :
    capture_pid=
}

pipewire >"$work/pipewire.log" 2>&1 &
pipewire_pid=$!
for attempt in $(seq 1 200); do
    if pw-cli info 0 >/dev/null 2>&1; then
        break
    fi
    test "$attempt" -lt 200
    sleep 0.02
done
pipewire-pulse >"$work/pulse.log" 2>&1 &
pulse_pid=$!
for attempt in $(seq 1 200); do
    if pactl info >/dev/null 2>&1; then
        break
    fi
    test "$attempt" -lt 200
    sleep 0.02
done
start_wireplumber
for suffix in a b; do
    pw-cli create-node adapter "{ factory.name = support.null-audio-sink node.name = test_source_${suffix} media.class = Audio/Source object.linger = true audio.position = [ FL FR ] }"
done
pw-metadata -n default 0 default.audio.source '{"name":"test_source_a"}' Spa:String:JSON

start_capture test_source_a
stream_id=$(app_id)
: "${stream_id:?}"
shell-audio capture-target test_source_b "$stream_id"
wait_source test_source_b
shell-audio capture-target -1 "$stream_id"
wait_source test_source_a
pw-metadata -n default 0 default.audio.source '{"name":"test_source_b"}' Spa:String:JSON
wait_source test_source_b
shell-audio capture-target test_source_b "$stream_id"
wait_source test_source_b
attempt=0
while test "$attempt" -lt 500; do
    if grep -R -q 'test_source_b' "$XDG_STATE_HOME/wireplumber"; then
        break
    fi
    sleep 0.02
    attempt=$((attempt + 1))
done
grep -R -q 'test_source_b' "$XDG_STATE_HOME/wireplumber"

source_id=$(pw-dump | jq -r '.[] | select(.type == "PipeWire:Interface:Node") | select(.info.props["node.name"] == "test_source_b") | .id')
: "${source_id:?}"
pw-cli destroy "$source_id"
wait_source ""
stop_capture
start_capture
wait_source ""
stop_capture
stop_wireplumber
start_wireplumber
start_capture
wait_source ""
pw-cli create-node adapter "{ factory.name = support.null-audio-sink node.name = test_source_b media.class = Audio/Source object.linger = true audio.position = [ FL FR ] }"
wait_source test_source_b
printf '%s\n' 'native capture routing ok'
