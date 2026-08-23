{ pkgs, src }:
pkgs.runCommandLocal "zsh-syntax-check" {
    nativeBuildInputs = [
        pkgs.dash
        pkgs.findutils
        pkgs.zsh
    ];
    inherit src;
} (builtins.readFile ./zsh-syntax-check.sh)
