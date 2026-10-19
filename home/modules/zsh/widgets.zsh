autoload -Uz \
    delete-char-or-send-eof \
    repeat-last-command \
    nix-flake-revert \
    fzf-git-branch \
    fzf-git-log \
    fzf-git-stage-hunk \
    fzf-git-stash \
    fzf-git-commit \
    tmux-session-switcher \
    cht-sh

zle -N delete-char-or-send-eof
zle -N repeat-last-command
zle -N nix-flake-revert
zle -N fzf-git-branch
zle -N fzf-git-log
zle -N fzf-git-stage-hunk
zle -N fzf-git-stash
zle -N fzf-git-commit
zle -N tmux-session-switcher
zle -N cht-sh

fzf-git-prefix() {
    local key
    read -k 1 key
    case "$key" in
        $'\x02') zle fzf-git-branch ;;       # C-B
        $'\x0c') zle fzf-git-log ;;          # C-L
        $'\x01') zle fzf-git-stage-hunk ;;   # C-A
        $'\x13') zle fzf-git-stash ;;        # C-S
        $'\x03') zle fzf-git-commit ;;       # C-C
        *) zle -M "fzf-git: unknown key" ;;
    esac
}
zle -N fzf-git-prefix
bindkey '^G' fzf-git-prefix
