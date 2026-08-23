#!/bin/sh
set -eu

config_path=$1
cp -L "$config_path" "$config_path.tmp"
mv -f "$config_path.tmp" "$config_path"
