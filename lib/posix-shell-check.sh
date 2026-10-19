#!/bin/sh
set -eu
: "${src:?}" "${validator:?}" "${out:?}"

find "$src" -type f \( -name '*.sh' -o -path '*/scripts/*' \) ! -name '*.py' \
    -exec dash "$validator" {} +
touch "$out"