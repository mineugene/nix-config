{ pkgs, src }:
pkgs.runCommandLocal "runtime-boundary-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.dash
        pkgs.findutils
        pkgs.gnugrep
    ];
    inherit src;
    testScript = ../../../support/check-runtime-boundary.sh;
} (builtins.readFile ./runtime-boundary-check.sh)
