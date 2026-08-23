{ lib, ... }:
{
    programs.zsh.initContent = lib.mkOrder 1000 ''
        # --- Terminal setup ---
        export KEYTIMEOUT=1

        # ^S is XOFF: without this it freezes the terminal instead of reaching tmux or ZLE.
        [[ -t 0 ]] && stty -ixon 2>/dev/null

        # --- Widgets ---
        autoload -Uz edit-command-line
        autoload -Uz select-bracketed select-quoted
        autoload -Uz surround

        zle -N edit-command-line
        zle -N select-bracketed
        zle -N select-quoted
        zle -N delete-surround surround
        zle -N add-surround surround
        zle -N change-surround surround

        # --- Insert mode: line editing ---
        bindkey '^A' beginning-of-line
        bindkey '^E' end-of-line
        bindkey '^F' forward-char
        bindkey '^[f' forward-word
        bindkey '^B' backward-char
        bindkey '^[b' backward-word
        bindkey '^D' delete-char-or-send-eof
        bindkey '^W' backward-kill-word
        bindkey '^K' kill-line
        bindkey '^U' backward-kill-line
        bindkey '^Y' autosuggest-accept
        bindkey '^O' repeat-last-command
        bindkey '^L' clear-screen

        # --- Insert mode: completion ---
        bindkey '^N' expand-or-complete
        bindkey '^P' reverse-menu-complete

        # --- Insert mode: custom widgets ---
        bindkey '^[n' nix-flake-revert
        bindkey '^[t' tmux-session-switcher
        bindkey '^[h' cht-sh

        # --- History navigation (both modes) ---
        bindkey '^[[A' history-search-backward
        bindkey '^[[B' history-search-forward
        bindkey -M vicmd '^[[A' history-search-backward
        bindkey -M vicmd '^[[B' history-search-forward

        # --- Normal mode: selection and buffer editing ---
        bindkey -sM vicmd '^[' '^G'
        bindkey -M vicmd v visual-mode
        bindkey -M vicmd V visual-line-mode
        # Q is vim's ex-mode key: edit the buffer in $EDITOR.
        bindkey -M vicmd Q edit-command-line

        # --- Surround and text objects ---
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

        # --- Completion menu ---
        # Loading complist creates the menuselect keymap used below.
        zmodload zsh/complist
        bindkey -M menuselect 'h' vi-backward-char
        bindkey -M menuselect 'l' vi-forward-char
        bindkey -M menuselect 'k' up-line-or-history
        bindkey -M menuselect 'j' down-line-or-history
        bindkey -M menuselect '^N' down-line-or-history
        bindkey -M menuselect '^P' up-line-or-history
    '';
}
