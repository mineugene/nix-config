{
    programs.zsh.shellAliases = {
        ta = "tmux attach-session";
        tl = "tmux list-sessions";
        tk = "tmux kill-session -t";
        tka = "tmux kill-server";
        tn = "tmux new-session -s";
        td = "tmux detach-client";
    };
}
