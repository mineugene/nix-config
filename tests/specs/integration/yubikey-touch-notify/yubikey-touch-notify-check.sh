#!/bin/sh
set -eu
: "${testScript:?}" "${command:?}" "${out:?}"

"$testScript" "$command" "$TMPDIR/yubikey-touch-notify"
touch "$out"
