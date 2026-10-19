{ pkgs, src }:
pkgs.runCommandLocal "posix-shell-check" {
    nativeBuildInputs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.dash
        pkgs.findutils
        pkgs.gnused
        pkgs.shellcheck
    ];
    inherit src;
} (builtins.readFile ./posix-shell-check.sh)
