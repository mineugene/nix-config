{ pkgs, src }:
pkgs.runCommandLocal "shell-scripts-check"
    {
        nativeBuildInputs = [
            pkgs.coreutils
            pkgs.dash
            pkgs.findutils
            pkgs.shellcheck
        ];
        inherit src;
        testScript = ./scripts/check-shell-scripts.sh;
    }
    ''
        set -eu

        find "$src/home" "$src/nixos" "$src/tests" -type f \( -name '*.sh' -o -path '*/scripts/*' \) \
            -exec dash "$testScript" {} +

        touch "$out"
    ''
