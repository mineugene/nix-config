#!/bin/sh
set -eu
: "${testScript:?}" "${shortenPath:?}" "${displayName:?}" "${yubikeyTouch:?}" "${switcherTest:?}" "${tmuxSessionSwitcher:?}" "${out:?}"

dash "$testScript" "$shortenPath" "$displayName" "$yubikeyTouch" "$TMPDIR/tmux-scripts"
python3 "$switcherTest" "$tmuxSessionSwitcher"
touch "$out"
