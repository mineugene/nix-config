#!/bin/sh
set -eu
: "${audioTestTokens:?}" "${audioTestDesktop:?}"

shellConfig=$1
testSource=$2
work=$(mktemp -d)
pipewire_pid=
wireplumber_pid=
cleanup() {
    test -z "$wireplumber_pid" || kill "$wireplumber_pid" 2>/dev/null || :
    test -z "$pipewire_pid" || kill "$pipewire_pid" 2>/dev/null || :
    wait 2>/dev/null || :
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
export XDG_RUNTIME_DIR="$work"
export XDG_CONFIG_HOME="$work/config"
export XDG_STATE_HOME="$work/state"
export PIPEWIRE_RUNTIME_DIR="$work"
export PIPEWIRE_REMOTE=pipewire-0
export QT_QPA_PLATFORM=offscreen
export QT_QPA_PLATFORMTHEME=
export QT_QUICK_CONTROLS_STYLE=Basic
export QT_QUICK_BACKEND=software
pipewire >"$work/pipewire.log" 2>&1 &
pipewire_pid=$!
for attempt in $(seq 1 200); do
    if pw-cli info 0 >/dev/null 2>&1; then
        break
    fi
    test "$attempt" -lt 200
    sleep 0.02
done
wireplumber --profile policy >"$work/wireplumber.log" 2>&1 &
wireplumber_pid=$!
for kind in sink source; do
    for suffix in a b; do
        case "$kind" in
            sink) class=Audio/Sink ;;
            source) class=Audio/Source ;;
        esac
        pw-cli create-node adapter "{ factory.name = support.null-audio-sink node.name = test_${kind}_${suffix} media.class = $class object.linger = true audio.position = [ FL FR ] }"
    done
done
cp "$shellConfig/Audio.qml" "$work/Audio.qml"
cp "$shellConfig/AudioRouting.js" "$work/AudioRouting.js"
cp "$audioTestTokens" "$work/Tokens.qml"
cp "$audioTestDesktop" "$work/Desktop.qml"
cp "$testSource" "$work/audio-defaults.qml"
if ! quickshell --no-color --path "$work/audio-defaults.qml" >"$work/test.log" 2>&1 ||
    ! grep -Fq 'native audio defaults ok' "$work/test.log"; then
    cat "$work/test.log" "$work/wireplumber.log" "$work/pipewire.log" >&2
    exit 1
fi
printf '%s\n' 'native audio defaults ok'
