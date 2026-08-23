#!/bin/sh
# Eww has no animation primitive, so a frame index is read from the clock
# rather than counted: a counter drifts whenever a tick is late or dropped,
# while a clock read is correct on every tick regardless of scheduling.
set -eu

clock=${EWW_ANIMATION_DATE:-date}

usage() {
    printf 'usage: eww-animation-frame PERIOD_MS FRAMES\n' >&2
    exit 2
}

[ "$#" -eq 2 ] || usage

for argument in "$1" "$2"; do
    case $argument in
        "" | *[!0-9]*) usage ;;
    esac
    [ "$argument" -gt 0 ] || usage
done

now=$("$clock" +%s%3N)
printf '%s\n' "$((now / $1 % $2))"
