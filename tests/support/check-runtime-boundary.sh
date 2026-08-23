#!/bin/sh
set -eu

root=$1
report=$(mktemp)
trap 'rm -f "$report"' 0
trap 'exit 1' HUP INT TERM

pattern="(python[0-9.]*|lua|node|perl)[[:space:]]+(-c|-e|--eval)([[:space:]]|$)|writeShellScript(Bin)?|(^|[^[:alnum:]_])(bash|sh)[[:space:]]+-c([[:space:]]|$)|(^|[[:space:].])(text|content|extraCss|extraLuaConfig|extraConfig|initContent|completionInit|buildPhase|installPhase|configurePhase|postPatch)[[:space:]]*=[[:space:]]*''|lib\\.mkOrder[[:space:]]+[0-9]+[[:space:]]+''|^[[:space:]]*''[[:space:]]*$|\\$\\(|''\\$\\{|[[:alnum:]_-]+\\(\\)[[:space:]]*\\{|;[[:space:]]*(then|do)([[:space:]]|$)|<<[[:space:]]*['\\\"]?[[:alnum:]_]+|^[[:space:]]*(bindkey|zle|compinit|autoload|[nvxi]?noremap|autocmd)[[:space:]]"

find "$root/flake.nix" "$root/home" "$root/lib" "$root/nixos" "$root/outputs" "$root/overlays" "$root/tests" \
    -type f -name '*.nix' -exec grep -nHE "$pattern" {} + > "$report" 2>&1 || :
if [ -s "$report" ]; then
    cat "$report" >&2
    printf '%s\n' 'source program embedded in Nix; use native options or a standalone source file' >&2
    exit 1
fi
