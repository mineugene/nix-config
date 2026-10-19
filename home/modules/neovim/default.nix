{
    config,
    pkgs,
    lib,
    hostConfig ? {
        isWsl = false;
    },
    ...
}:
let
    neovim = pkgs.wrapNeovim pkgs.neovim-unwrapped {
        withNodeJs = false;
        withRuby = false;
    };

in
{
    imports = [
        ./dap.nix
        ./formatters.nix
        ./lsp.nix
    ];

    home.packages = [
        neovim
        pkgs.tree-sitter
    ]
    ++ lib.optionals hostConfig.isWsl [
        pkgs.nixd
    ];

    home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
    };

    home.shellAliases = {
        vim = "nvim";
    };
}
