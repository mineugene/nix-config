{
    pkgs,
    lib,
    ...
}:
{
    programs.vim = {
        enable = true;
        settings = {
            background = "dark";
            expandtab = true;
            hidden = true;
            ignorecase = true;
            number = true;
            relativenumber = true;
            shiftwidth = 4;
            smartcase = true;
            tabstop = 4;
        };
        extraConfig = builtins.readFile ./vimrc.vim;
        plugins = with pkgs.vimPlugins; [
            auto-pairs
            splitjoin-vim
            targets-vim
            vim-commentary
            vim-indent-object
            vim-mucomplete
            vim-repeat
            vim-sleuth
            vim-surround
            vim-unimpaired
        ];
    };

    home.file.".vim/colors/tokyonight.vim".source = ./colors/tokyonight.vim;

    home.sessionVariables = {
        EDITOR = lib.mkDefault "vim";
        VISUAL = lib.mkDefault "vim";
    };

    home.shellAliases = {
        vi = lib.mkDefault "command vim";
    };

}
