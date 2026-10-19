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

    programs.zsh.initContent = lib.mkOrder 1000 (builtins.readFile ./widgets.zsh);
}
