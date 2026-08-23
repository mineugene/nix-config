#!/bin/sh
set -eu
: "${testScript:?}" "${updateAll:?}" "${out:?}"

dash "$testScript" "$updateAll" "$TMPDIR/compose"
touch "$out"
