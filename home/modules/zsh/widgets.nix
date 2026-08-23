{ config, lib, ... }:
{
    assertions = [
        {
            assertion = config.programs.fzf.enable;
            message = "zsh widgets: programs.fzf.enable must be true (required by fzf widgets)";
        }
        {
            assertion = config.programs.git.enable;
            message = "zsh widgets: programs.git.enable must be true (required by git widgets)";
        }
        {
            assertion = config.programs.tmux.enable;
            message = "zsh widgets: programs.tmux.enable must be true (required by tmux-session-switcher)";
        }
    ];

    xdg.configFile = {
        "zsh/widgets/delete-char-or-send-eof".source = ./widgets/delete-char-or-send-eof;
        "zsh/widgets/repeat-last-command".source = ./widgets/repeat-last-command;
        "zsh/widgets/nix-flake-revert".source = ./widgets/nix-flake-revert;
        "zsh/widgets/fzf-git-branch".source = ./widgets/fzf-git-branch;
        "zsh/widgets/fzf-git-log".source = ./widgets/fzf-git-log;
        "zsh/widgets/fzf-git-stage-hunk".source = ./widgets/fzf-git-stage-hunk;
        "zsh/widgets/fzf-git-stash".source = ./widgets/fzf-git-stash;
        "zsh/widgets/fzf-git-commit".source = ./widgets/fzf-git-commit;
        "zsh/widgets/tmux-session-switcher".source = ./widgets/tmux-session-switcher;
        "zsh/widgets/cht-sh".source = ./widgets/cht-sh;
    };

    programs.zsh.initContent = lib.mkOrder 1000 ''
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
    '';
}
