#!/bin/sh
set -eu
: "${defaultMode:?}" "${schemaDir:?}" "${out:?}"

export HOME="$TMPDIR/home"
export XDG_CONFIG_HOME="$TMPDIR/config"
export XDG_STATE_HOME="$TMPDIR/state"
export GSETTINGS_BACKEND=keyfile
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$TMPDIR/bin"
test "$(desktop-theme get)" = "$defaultMode"

desktop-theme set dark
test "$(cat "$XDG_STATE_HOME/mineugene-desktop/theme")" = dark
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'"
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface gtk-theme)" = "'Adwaita-dark'"

desktop-theme set light
test "$(cat "$XDG_STATE_HOME/mineugene-desktop/theme")" = light
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface color-scheme)" = "'prefer-light'"
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface gtk-theme)" = "'Adwaita'"

desktop-theme toggle
test "$(desktop-theme get)" = dark
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'"

desktop-theme toggle
test "$(desktop-theme get)" = light
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface color-scheme)" = "'prefer-light'"

gsettings --schemadir "$schemaDir" set org.gnome.desktop.interface color-scheme prefer-dark
gsettings --schemadir "$schemaDir" set org.gnome.desktop.interface gtk-theme Adwaita-dark
desktop-theme apply
desktop-theme apply
test "$(desktop-theme get)" = light
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface color-scheme)" = "'prefer-light'"
test "$(gsettings --schemadir "$schemaDir" get org.gnome.desktop.interface gtk-theme)" = "'Adwaita'"

if desktop-theme set sepia >/dev/null 2>&1; then
    echo 'desktop-theme accepted an invalid mode' >&2
    exit 1
fi
if desktop-theme unknown >/dev/null 2>&1; then
    echo 'desktop-theme accepted an invalid command' >&2
    exit 1
fi
test "$(desktop-theme get)" = light

touch "$out"
