#!/bin/sh
set -eu

sed -i "/$1/d" "$2"
