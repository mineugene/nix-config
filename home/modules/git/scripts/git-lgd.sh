#!/bin/sh
set -eu

exec git log --oneline -- "$1/"
