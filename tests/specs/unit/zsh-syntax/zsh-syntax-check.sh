#!/bin/sh
set -eu
: "${src:?}" "${out:?}"

find "$src/home" "$src/tests" -type f \( -name '*.zsh' -o -path '*/zsh/widgets/*' \) \
    -exec dash "$src/tests/support/check-zsh.sh" {} +
touch "$out"
