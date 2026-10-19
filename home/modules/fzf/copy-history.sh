#!/bin/sh
set -eu

encoded=$(printf '%s' "$@" | base64 -w 0)
printf '\033]52;c;%s\a' "$encoded" > /dev/tty
