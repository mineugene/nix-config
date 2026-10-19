#!/bin/sh
set -eu

exec git log --oneline --grep="^$1" --extended-regexp
