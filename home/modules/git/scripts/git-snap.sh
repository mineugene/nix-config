#!/bin/sh
set -eu

exec git archive --format=tar.gz \
    -o "${PWD##*/}-$(date +%Y%m%d-%H%M%S).tar.gz" HEAD
