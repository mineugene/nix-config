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
        publicModules.zoxide
        publicModules.zsh
    ];

    home.stateVersion = "25.11";
    home.sessionVariables = {
        ZSH_COMPDUMP = "${config.xdg.stateHome}/zsh";
        ZSH_RUNTIMEPATH = "${config.xdg.dataHome}/zsh";
        LESSHISTFILE = "${config.xdg.stateHome}/less/history";
        WGETRC = "${config.xdg.configHome}/wget/wgetrc";
    };
    home.packages = with pkgs; [
        jq
        ripgrep
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
    xdg.configFile."wget/wgetrc".text = "hsts_file=${config.xdg.cacheHome}/wget/wget-hsts\n";
}
