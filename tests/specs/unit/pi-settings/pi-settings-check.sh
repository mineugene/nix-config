#!/bin/sh
set -eu
: "${piSettingsTest:?}" "${configure:?}" "${settingsFilter:?}" "${declaredFilter:?}" "${out:?}"

dash "$piSettingsTest" "$configure" "$settingsFilter" "$declaredFilter"
touch "$out"
