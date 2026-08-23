{ config, ... }:
{
    programs.less.enable = true;
    programs.zsh.shellAliases = {
        less = "less -R --quit-if-one-screen";
    };

    home.sessionVariables = {
        LESSHISTFILE = "${config.xdg.stateHome}/less/history";
    };
}
