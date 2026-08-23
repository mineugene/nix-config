{ lib, ... }:
{
    programs.zsh.initContent = lib.mkOrder 1000 ''
        export KEYTIMEOUT=1

        autoload -Uz edit-command-line
        autoload -Uz select-bracketed select-quoted
        autoload -Uz surround

        zle -N edit-command-line
        zle -N select-bracketed
        zle -N select-quoted
        zle -N delete-surround surround
        zle -N add-surround surround
        zle -N change-surround surround

        bindkey '^A' beginning-of-line
        bindkey '^E' end-of-line
        bindkey '^D' delete-char-or-send-eof
        bindkey '^W' backward-kill-word
        bindkey '^K' kill-line
        bindkey '^U' backward-kill-line
        bindkey '^Y' autosuggest-accept
        bindkey '^O' repeat-last-command
        bindkey '^N' expand-or-complete
        bindkey '^P' reverse-menu-complete
        bindkey '^F' forward-char
        bindkey '^[f' forward-word
        bindkey '^B' backward-char
        bindkey '^[b' backward-word
        bindkey '^L' clear-screen
        bindkey '^[[A' history-search-backward
        bindkey '^[[B' history-search-forward

        bindkey '^[n' nix-flake-revert
        bindkey '^[t' tmux-session-switcher
        bindkey '^[h' cht-sh

        bindkey -sM vicmd '^[' '^G'
        bindkey -M vicmd v edit-command-line

        for keymap in viopp visual; do
            bindkey -M $keymap -- '-' vi-up-line-or-history
            for char in {a,i}''${(s..)^:-\'\"\`\|,./:;=+@}; do
                bindkey -M $keymap $char select-quoted
            done
            for char in {a,i}''${(s..)^:-'()[]{}<>bB'}; do
                bindkey -M $keymap $char select-bracketed
            done
        done
        bindkey -M vicmd cs change-surround
        bindkey -M vicmd ds delete-surround
        bindkey -M vicmd ys add-surround
        bindkey -M visual S add-surround
    '';
}
