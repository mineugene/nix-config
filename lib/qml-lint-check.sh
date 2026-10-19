#!/bin/sh
set -eu
: "${shellConfig:?}" "${qmlLint:?}" "${qtModules:?}" "${quickshellModules:?}" "${out:?}"

sh "$qmlLint" "$shellConfig" "$qtModules" "$quickshellModules"
touch "$out"