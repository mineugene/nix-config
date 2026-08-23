#!/bin/sh
set -eu
: "${config:?}" "${out:?}"

if grep -Eiq 'suspend|hibernate|systemctl[[:space:]].*sleep' "$config"; then
    echo 'hypridle config contains an automatic sleep action' >&2
    exit 1
fi

touch "$out"
