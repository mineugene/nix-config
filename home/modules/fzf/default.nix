{ lib, pkgs, ... }:
let
    copyHistory = pkgs.writeShellApplication {
        name = "fzf-copy-history";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./copy-history.sh;
    };
    deleteHistory = pkgs.writeShellApplication {
        name = "fzf-delete-history";
        runtimeInputs = [ pkgs.gnused ];
        text = builtins.readFile ./delete-history.sh;
    };
    tree = pkgs.writeShellApplication {
        name = "lsd-tree";
        runtimeInputs = [
            pkgs.git
            pkgs.lsd
        ];
        text = builtins.readFile ../lsd/tree.sh;
    };
    previewDirectory = pkgs.writeShellApplication {
        name = "fzf-preview-directory";
        runtimeInputs = [ tree ];
        text = builtins.readFile ./preview-directory.sh;
    };
    historyWidgetOptions = [
        "--preview 'echo {}'"
        "--preview-window up:3:hidden:wrap"
        "--bind 'ctrl-/:toggle-preview'"
        # OSC 52 works on Linux and WSL without a desktop clipboard utility.
        "--bind 'ctrl-y:execute-silent(${lib.getExe copyHistory} {2..})+abort'"
        "--bind 'ctrl-x:execute-silent(${lib.getExe deleteHistory} {2..} \"$HISTFILE\")+reload(fc -rl 1)'"
        "--color header:italic"
        "--header 'CTRL-Y: copy | CTRL-X: delete'"
    ];

    changeDirWidgetOptions = [
        "--preview '${lib.getExe previewDirectory} {}'"
    ];

    # Home Manager emits session variables inside double quotes. Escape fzf
    # widget shell syntax so startup does not evaluate nested quotes/subst.
    escapeFzfOptions =
        values:
        lib.escape [
            "\\"
            "\""
            "$"
            "`"
        ] (lib.concatStringsSep " " values);
in
{
    home.sessionVariables = {
        FZF_ALT_C_OPTS = lib.mkForce (escapeFzfOptions changeDirWidgetOptions);
        FZF_CTRL_R_OPTS = lib.mkForce (escapeFzfOptions historyWidgetOptions);
    };

    programs.fzf = {
        enable = true;
        enableZshIntegration = true;

        defaultCommand = "fd --type=file --type=symlink --follow --max-depth=32 --hidden --strip-cwd-prefix --color=auto";

        defaultOptions = [
            # --- Tokyo Night theme ---
            "--color=fg:#a9b1d6,bg:#1a1b26,hl:#f7768e"
            "--color=fg+:#c0caf5,bg+:#283457,hl+:#f7768e"
            "--color=border:#3b4261,header:#73daca,gutter:#1a1b26"
            "--color=spinner:#e0af68,info:#7dcfff"
            "--color=pointer:#bb9af7,marker:#ff9e64,prompt:#565f89"
            # --- Layout ---
            "--no-mouse"
            "--cycle"
            "--multi"
            "--scroll-off=1"
            "--layout=reverse"
            "--height=60%"
            "--no-scrollbar"
            "--no-border"
            "--info=inline:'    '"
            "--prompt='  > '"
            "--pointer='▌ '"
            "--marker='◇ '"
        ];

        fileWidget = {
            command = "fd --hidden --strip-cwd-prefix --color=auto";
            options = [
                "--preview='bat -n --color=always {}'"
                "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
            ];
        };
        historyWidget.options = historyWidgetOptions;
        changeDirWidget = {
            command = "fd --type=directory --type=symlink --hidden --strip-cwd-prefix --color=auto";
            options = changeDirWidgetOptions;
        };
    };
}
