{ lib, pkgs, ... }:
let
    rustToolchain = pkgs.rust-bin.stable.latest.default.override {
        extensions = [
            "rust-analyzer"
            "rust-src"
        ];
    };
in
{
    home.packages = [
        rustToolchain
        pkgs.lldb
    ];

    programs.zsh.initContent = lib.mkOrder 551 (
        builtins.replaceStrings [ "@completionPath@" ] [ "${rustToolchain}/share/zsh/site-functions" ] (
            builtins.readFile ./completions.zsh
        )
    );
}
