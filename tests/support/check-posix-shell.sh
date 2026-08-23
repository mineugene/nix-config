#!/bin/sh
set -u

status=0

for script do
    first_line=$(head -n 1 "$script") || first_line=
    case $first_line in
        '#!/bin/sh')
            shellcheck --shell=sh "$script" || status=1
            dash -n "$script" || status=1
            ;;

        '#!/usr/bin/env bash')
            # Bash is allowed only where the second line documents why.
            case $(sed -n 2p "$script") in
                '# '*'require Bash.'|'# '*'requires Bash.') ;;
                *)
                    printf 'Bash source lacks a documented requirement: %s\n' "$script" >&2
                    status=1
                    ;;
            esac
            shellcheck --shell=bash "$script" || status=1
            bash -n "$script" || status=1
            ;;

        *)
            printf 'shell source lacks an interpreter declaration: %s\n' "$script" >&2
            status=1
            ;;
    esac
done

exit "$status"
