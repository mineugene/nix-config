{
    config,
    lib,
    pkgs,
    publicModules,
    ...
}:
{
    imports = [
        publicModules.bat
        publicModules.bottom
        publicModules.fd
        publicModules.fzf
        publicModules.git
        publicModules.git-ignore
        publicModules.gpg
        publicModules.less
        publicModules.lsd
        publicModules.neovim
        publicModules.nixfmt
        publicModules.rsync
        publicModules.ssh
        publicModules.starship
        publicModules.tmux
        publicModules.vim
        publicModules.yazi
        publicModules.zoxide
        publicModules.zsh
    ];

    home.stateVersion = lib.mkDefault "25.11";
    home.sessionVariables = {
        WGETRC = "${config.xdg.configHome}/wget/wgetrc";
    };
    home.packages = with pkgs; [
        jq
        ripgrep
        sd
        unzip
        wget
        zip
    ];

    programs.home-manager.enable = true;
    programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
    };

    xdg.enable = true;
    xdg.configFile."wget/wgetrc".text = lib.generators.toKeyValue { } {
        hsts_file = "${config.xdg.cacheHome}/wget/wget-hsts";
    };
}
