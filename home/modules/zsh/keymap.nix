{ lib, ... }:
{
    programs.zsh.initContent = lib.mkOrder 1000 (builtins.readFile ./keymap.zsh);
}
