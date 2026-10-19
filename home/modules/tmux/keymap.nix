{
    programs.tmux.extraConfig = builtins.readFile ./keymap.conf;
}
