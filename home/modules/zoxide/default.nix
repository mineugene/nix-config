{ config, ... }:
{
    programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
    };

    home.sessionVariables = {
        _ZO_DATA_DIR = "${config.xdg.dataHome}/zoxide";
        _ZO_ECHO = "1";
        _ZO_RESOLVE_SYMLINKS = "1";
    };

    programs.zsh.shellAliases = {
        cd = "z";
        cdi = "zi";
    };
}
