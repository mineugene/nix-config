{ pkgs, ... }:
{
    home.packages = with pkgs; [
        delve
        go
        gofumpt
        gopls
    ];

    home.sessionVariables = {
        # Auto-downloaded toolchains are pre-built dynamic ELFs that fail
        # on NixOS without nix-ld. Pin to the nix-installed Go instead.
        GOTOOLCHAIN = "local";
    };
}
