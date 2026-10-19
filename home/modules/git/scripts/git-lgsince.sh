#!/bin/sh
set -eu

exec git log --oneline --after="$1" --before="$2"
