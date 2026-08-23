#!/bin/sh
set -eu
: "${src:?}" "${out:?}"

find "$src/home" "$src/lib" "$src/nixos" "$src/overlays" "$src/tests" -type f \
    \( -name '*.sh' -o -path '*/scripts/*' \) ! -name '*.py' \
    -exec dash "$src/tests/support/check-posix-shell.sh" {} +
touch "$out"
