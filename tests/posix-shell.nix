{ pkgs, src }:
pkgs.runCommandLocal "posix-shell-check"
    {
        nativeBuildInputs = [
            pkgs.coreutils
            pkgs.dash
            pkgs.findutils
            pkgs.shellcheck
        ];
        inherit src;
    }
    ''
        set -eu

        find "$src/home" "$src/lib" "$src/nixos" "$src/tests" -type f \( -name '*.sh' -o -path '*/scripts/*' \) \
            -exec dash "$src/tests/scripts/check-posix-shell.sh" {} +

        touch "$out"
    ''
