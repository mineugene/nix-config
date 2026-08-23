#!/bin/sh
set -u

rc=0

for unit do
    printf 'Refreshing %s\n' "$unit"
    if ! systemctl start --wait "$unit"; then
        rc=1
    fi
done

exit "$rc"
