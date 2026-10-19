#!/bin/sh
set -eu
: "${filetypeCheck:?}" "${yaziTheme:?}" "${yaziSettings:?}" "${yaziInitSource:?}" "${iconPad:?}" "${lsdPreview:?}"
: "${lsdIcons:?}" "${renderCheck:?}" "${out:?}"
# Every filetype rule must set url or mime.
awk -f "$filetypeCheck" "$yaziTheme"

mkdir -p "$TMPDIR/yazi/plugins" "$TMPDIR/xdg/lsd" "$TMPDIR/yz/0-dir/hosts"
cp "$yaziTheme" "$TMPDIR/yazi/theme.toml"
cp "$yaziSettings" "$TMPDIR/yazi/yazi.toml"
cp "$yaziInitSource" "$TMPDIR/yazi/init.lua"
ln -s "$iconPad" "$TMPDIR/yazi/plugins/icon-pad.yazi"
ln -s "$lsdPreview" "$TMPDIR/yazi/plugins/lsd-preview.yazi"
# The fixture pins a supplementary-plane icon instead of relying on lsd's
# default theme, so the four-byte padding path is always exercised.
cp "$lsdIcons" "$TMPDIR/xdg/lsd/icons.yaml"
export YAZI_CONFIG_HOME="$TMPDIR/yazi" XDG_CONFIG_HOME="$TMPDIR/xdg" TERM=xterm-256color
: > "$TMPDIR/yz/0-dir/hosts/tree-leaf"
: > "$TMPDIR/yz/a.rs"
: > "$TMPDIR/yz/b.md"
cd "$TMPDIR/yz" || exit 1
# The entry argument pins the startup cwd and hover: without it
# yazi's initial hover races between the first and last entry.
python3 "$renderCheck" "$TMPDIR/render.log" || {
    cat "$TMPDIR/render.log" >&2
    exit 1
}

touch "$out"
