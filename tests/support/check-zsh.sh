#!/bin/sh
set -u

status=0
for source do
    zsh -n "$source" || status=1
done
exit "$status"
