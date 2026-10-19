yazi-file-manager() {
    y
    [[ -n "$WIDGET" ]] && zle reset-prompt
}
zle -N yazi-file-manager
bindkey -M viins '^[y' yazi-file-manager
bindkey -M vicmd '^[y' yazi-file-manager
