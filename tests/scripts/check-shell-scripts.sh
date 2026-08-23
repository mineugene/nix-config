#!/bin/sh
set -u

status=0

for script do
    first_line=$(head -n 1 "$script") || first_line=
    case $first_line in
        '#!/bin/sh' | '#!/usr/bin/env bash') shellcheck "$script" || status=1 ;;
        *)
            printf 'shell source lacks an interpreter declaration: %s\n' "$script" >&2
            status=1
            ;;
    esac
done

exit "$status"
