#!/bin/sh
set -eu

export LSD_TREE_DIRECTORY="$1"
exec lsd-tree --color=always "$1"
