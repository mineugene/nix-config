#!/bin/sh
set -eu
: "${fontManifest:?}" "${fontTest:?}" "${out:?}"
python3 "$fontTest" "$fontManifest"
touch "$out"
