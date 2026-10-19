#!/bin/sh
set -eu
: "${shellConfig:?}" "${extensionShellConfig:?}" "${shellFile:?}" "${extensionShellFile:?}" "${lockFile:?}" "${lockEnable:?}" "${pamModule:?}" "${qmlLint:?}" "${quickshellModules:?}" "${qtModules:?}" "${out:?}"

# Both entry points and every source they use must lint clean.
for entry in bar.qml lock.qml; do
    test -f "$shellConfig/$entry"
done
sh "$qmlLint" "$shellConfig" "$qtModules" "$quickshellModules"
sh "$qmlLint" "$extensionShellConfig" "$qtModules" "$quickshellModules"

# With no extension the popup configuration stays PipeWire-only. A configured
# extension merges its component in and the popup loads it.
test ! -e "$shellConfig/AudioExtension.qml"
test -f "$extensionShellConfig/AudioExtension.qml"
grep -Fq 'AudioExtension.qml' "$shellConfig/PopupAudio.qml"
if grep -Fq 'Audio.monitor' "$shellConfig/Audio.qml" "$shellConfig/PopupAudio.qml"; then
    echo 'the audio popup still carries OpenXLR monitor code' >&2
    exit 1
fi

# The extension's helper packages reach the shell PATH.
jq -r '.Service.Environment[] | select(startswith("PATH=")) | ltrimstr("PATH=")' "$extensionShellFile" |
    grep -Fq 'jq'

# The generated token file carries every token the sources read.
tokens=$(jq -r '.Service.Environment[] | select(startswith("SHELL_TOKENS=")) | ltrimstr("SHELL_TOKENS=")' "$shellFile")
jq -e '
    (.colors.dark | has("barBackground") and has("accent") and has("surfaceHover"))
    and (.colors.light | has("barBackground"))
    and (.fonts.interface.size > 0)
    and (.barHeight % 2 == 0)
    and (.popupWidth | has("audio") and has("audioDevices") and has("wifi"))
    and (.spacing.small > 0)
    and (.cornerRoundingPower >= 1 and .cornerRoundingPower <= 10)
    and (.audioExtension == false)
    and (.powerProfiles == true)
' "$tokens" >/dev/null
extensionTokens=$(jq -r '.Service.Environment[] | select(startswith("SHELL_TOKENS=")) | ltrimstr("SHELL_TOKENS=")' "$extensionShellFile")
jq -e '.audioExtension == true' "$extensionTokens" >/dev/null

# The bar restarts on failure and is wanted by the graphical session.
grep -Fq '"Restart":"on-failure"' "$shellFile"
grep -Fq 'bar.qml' "$shellFile"

# A crash must re-lock; a clean unlock exit must not restart. sd-switch
# restarts a changed unit while it is running, and a running lock has to
# survive that.
grep -Fq '"After":["graphical-session.target"]' "$lockFile"
grep -Fq '"Restart":"on-failure"' "$lockFile"
grep -Fq '"X-SwitchMethod":"keep-old"' "$lockFile"
grep -Fq 'quickshell.service' "$lockFile"
if grep -Fq 'KillSignal' "$lockFile"; then
    echo 'the lock must not be killed with a signal its client ignores' >&2
    exit 1
fi
# The target starts the lock through the data directory, out of the unit
# directory sd-switch scans for target wanted units.
test -e "$lockEnable"

# The lock authenticates against a PAM service the NixOS side provides.
service=$(grep -o 'config: "[a-z-]*"' "$shellConfig/lock.qml" | cut -d'"' -f2)
grep -Fq "pam.services.$service" "$pamModule"

# The lock prompt draws on the primary monitor the launcher names.
grep -Fq 'SHELL_LOCK_MONITOR' "$shellConfig/lock.qml"

# Item.enabled does not reach a child MouseArea, so a clickable container whose
# root is disabled must gate its own click area. Without this, a Wi-Fi or
# Bluetooth row stays clickable while its toggle job is in flight.
grep -Fq 'enabled: row.enabled' "$shellConfig/PopupAction.qml"
grep -Fq 'enabled: root.enabled' "$shellConfig/AudioControl.qml"

# Hyprland.activeToplevel keeps the last window when focus moves to an empty
# workspace, so the focused window must be gated on Wayland's active handle,
# which clears on deactivation, instead of the stale Hyprland object.
grep -Fq 'ToplevelManager.activeToplevel ? Hyprland.activeToplevel : null' "$shellConfig/Focused.qml"

touch "$out"