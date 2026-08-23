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

    programs.zsh.initContent = lib.mkOrder 551 ''
        fpath=(${rustToolchain}/share/zsh/site-functions $fpath)
    '';
}
