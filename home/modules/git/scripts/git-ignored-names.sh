#!/bin/sh
set -eu

case $1 in
    untracked) shift; git ls-files --others --ignored --exclude-standard -z "$@" ;;
    tracked) shift; git ls-files --cached --ignored --exclude-standard -z "$@" ;;
    *) exit 2 ;;
esac | xargs -0 -n1 basename
