#!/bin/sh
# shellcheck disable=SC2016
set -eu
: "${testScript:?}" "${src:?}" "${out:?}"

dash "$testScript" "$src"
root=$(mktemp -d)
trap 'rm -rf "$root"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$root/home" "$root/lib" "$root/nixos" "$root/outputs" "$root/overlays" "$root/tests"
: > "$root/flake.nix"
printf '%s\n' '{ description = "Documentation"; text = builtins.readFile ./program.sh; }' > "$root/home/valid.nix"
dash "$testScript" "$root"

for source in \
    'pkgs.writeShellScript "helper" "true"' \
    "{ text = ''echo bad''; }" \
    "{ initContent = lib.mkOrder 1000 ''echo bad''; }" \
    'if test -e "$path"; then' \
    'python3 - <<PY' \
    'python3 -c "print(1)"' \
    'local callback = "$(command)"' \
    'bindkey "^G" widget'; do
    printf '%s\n' "$source" > "$root/tests/embedded.nix"
    if dash "$testScript" "$root" > "$root/report" 2>&1; then
        printf 'boundary check accepted embedded source: %s\n' "$source" >&2
        exit 1
    fi
    grep -q 'source program embedded in Nix' "$root/report"
done

touch "$out"
