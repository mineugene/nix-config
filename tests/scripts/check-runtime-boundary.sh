#!/bin/sh
set -u

root=$1
status=0

if find "$root/flake.nix" "$root/home" "$root/lib" "$root/nixos" "$root/outputs" "$root/overlays" \
    -type f -name '*.nix' \
    -exec grep -nHE 'writeShellScript(Bin)?|(^|[^[:alnum:]_])(bash|sh)[[:space:]]+-c([[:space:]]|$)' {} +; then
    printf '%s\n' 'runtime shell program embedded in Nix' >&2
    status=1
fi

exit "$status"
