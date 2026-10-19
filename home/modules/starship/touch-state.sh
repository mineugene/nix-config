#!/bin/sh
set -eu

state_file=${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch/active
case ${1-} in
    check) test -s "$state_file" ;;
    '') cat "$state_file" ;;
    *) exit 2 ;;
esac
