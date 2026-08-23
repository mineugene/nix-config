#!/bin/sh
set -eu

: "${manifest:?}" "${out:?}"
cp "$manifest" "$out"
