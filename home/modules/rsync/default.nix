{ pkgs, ... }:
{
    home.packages = [ pkgs.rsync ];
    programs.zsh.shellAliases = {
        rsync = "rsync -rlpthvz --partial --info=progress2 --mkpath";
    };
}
