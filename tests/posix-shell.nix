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

        find "$src" -type f -name '*.sh' \
            -exec dash "$src/tests/scripts/check-posix-shell.sh" {} +

        touch "$out"
    ''
