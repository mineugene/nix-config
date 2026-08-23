#!/bin/sh
set -eu
: "${monitors:?}" "${monitorEvents:?}" "${bindings:?}" "${generatedMonitor:?}" "${generatedPrograms:?}"
: "${configuredMonitor:?}" "${hyprlandCommand:?}" "${root:?}" "${out:?}"

MONITORS_LUA="$monitors" lua "$monitorEvents"

# Lua's require returns true when a module returns nil. Exercise the
# generated default monitor through Hyprland's parser so that value
# cannot be passed to hl.monitor.
config="$TMPDIR/config"
runtime="$TMPDIR/runtime"
# shellcheck disable=SC2174
mkdir -m 700 -p "$config/hypr/generated" "$runtime"
ln -s "$bindings" "$config/hypr/bindings.lua"
ln -s "$monitors" "$config/hypr/monitors.lua"
ln -s "$generatedMonitor" "$config/hypr/generated/monitor.lua"
ln -s "$generatedPrograms" "$config/hypr/generated/programs.lua"
XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="$runtime" "$hyprlandCommand" --verify-config --config "$root"

ln -sfn "$configuredMonitor" "$config/hypr/generated/monitor.lua"
XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="$runtime" "$hyprlandCommand" --verify-config --config "$root"

touch "$out"
