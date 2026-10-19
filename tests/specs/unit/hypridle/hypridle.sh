#!/bin/sh
set -eu
: "${config:?}" "${out:?}"

if grep -Eiq 'suspend|hibernate|systemctl[[:space:]].*sleep' "$config"; then
    echo 'hypridle config contains an automatic sleep action' >&2
    exit 1
fi

grep -Fq 'start shell-lock.service' "$config"
grep -Fq 'timeout=900' "$config"
grep -Fq 'lock-session' "$config"

touch "$out"
