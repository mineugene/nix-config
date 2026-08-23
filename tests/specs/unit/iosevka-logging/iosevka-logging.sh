#!/bin/sh
set -eu
: "${patcherSource:?}" "${loggingTest:?}" "${out:?}"
cp "$patcherSource" font-patcher
chmod u+w font-patcher
runHook postPatch

python3 "$loggingTest"

touch "$out"
