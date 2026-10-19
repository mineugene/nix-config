#!/bin/sh
set -eu
: "${fontConfig:?}"

shellConfig=$1
testSource=$2
testTokens=$3
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
cp "$shellConfig/Tip.qml" "$work/"
cp "$shellConfig/BarControl.qml" "$work/"
cp "$shellConfig/CornerRectangle.qml" "$work/"
cp "$shellConfig/corner.js" "$work/"
cp "$testTokens" "$work/Tokens.qml"
cp "$testSource" "$work/tooltip.qml"
mkdir "$work/home" "$work/config" "$work/cache" "$work/runtime"
chmod 700 "$work/runtime"
export HOME="$work/home"
export XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache"
export XDG_RUNTIME_DIR="$work/runtime"
export FONTCONFIG_FILE="$fontConfig"
export QT_QPA_PLATFORM=offscreen
export QT_QPA_PLATFORMTHEME=
export QT_QUICK_CONTROLS_STYLE=Basic
export QT_QUICK_BACKEND=software
if ! timeout 10s quickshell --no-color --path "$work/tooltip.qml" >"$work/test.log" 2>&1 ||
    ! grep -Fq 'native tooltip geometry ok' "$work/test.log"; then
    cat "$work/test.log" >&2
    exit 1
fi
printf '%s\n' 'native tooltip geometry ok'
