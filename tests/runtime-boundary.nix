{ pkgs, src }:
pkgs.runCommandLocal "runtime-boundary-check"
    {
        nativeBuildInputs = [
            pkgs.dash
            pkgs.findutils
            pkgs.gnugrep
        ];
        inherit src;
        testScript = ./scripts/check-runtime-boundary.sh;
    }
    ''
        set -eu

        dash "$testScript" "$src"
        touch "$out"
    ''
