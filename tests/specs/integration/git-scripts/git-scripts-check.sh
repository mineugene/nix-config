#!/bin/sh
set -eu
: "${testScript:?}" "${gitBreaking:?}" "${gitDesctag:?}" "${gitIgtrkPurge:?}" "${gitLgonly:?}" "${gitUnpsf:?}" "${out:?}"

dash "$testScript" "$gitBreaking" "$gitDesctag" "$gitIgtrkPurge" "$gitLgonly" "$gitUnpsf" "$TMPDIR/git-scripts"
dash "${aliasTest:?}" "${gitAliases:?}" "$TMPDIR/git-aliases"
touch "$out"
