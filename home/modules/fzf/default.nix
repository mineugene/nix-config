{ lib, options, ... }:
let
    # home-manager >= 26.05 moved the per-widget settings into nested attrsets
    # (programs.fzf.fileWidget.{command,options}, etc). Older releases expose
    # only the flat *Widget* names, where writing the new names is an eval error.
    # Detect the schema this home-manager ships and emit whichever it declares.
    hasNestedWidgets = options.programs.fzf ? fileWidget;

    fileWidgetCommand = "fd --hidden --strip-cwd-prefix --color=auto";
    fileWidgetOptions = [
        "--preview='bat -n --color=always {}'"
        "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
    ];

    historyWidgetOptions = [
        "--preview 'echo {}'"
        "--preview-window up:3:hidden:wrap"
        "--bind 'ctrl-/:toggle-preview'"
        # OSC 52 works on Linux and WSL without a desktop clipboard utility.
        "--bind 'ctrl-y:execute-silent(printf \"\\033]52;c;%s\\a\" \"$(printf %s {2..} | base64 -w 0)\" > /dev/tty)+abort'"
        "--bind 'ctrl-x:execute-silent(sed -i \"/{2..}/d\" $HISTFILE)+reload(fc -rl 1)'"
        "--color header:italic"
        "--header 'CTRL-Y: copy | CTRL-X: delete'"
    ];

    changeDirWidgetCommand = "fd --type=directory --type=symlink --hidden --strip-cwd-prefix --color=auto";
    changeDirWidgetOptions = [
        "--preview 'lsd --tree --depth=3 --color=always $(IGNORE=$(git -C {} rev-parse --show-toplevel 2>/dev/null)/.gitignore; if [ -f \"$IGNORE\" ]; then xargs printf \" --ignore-glob=%s\" < \"$IGNORE\"; fi) {}'"
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
            # tokyo-night theme
            "--color=fg:#a9b1d6,bg:#1a1b26,hl:#f7768e"
            "--color=fg+:#c0caf5,bg+:#283457,hl+:#f7768e"
            "--color=border:#3b4261,header:#73daca,gutter:#1a1b26"
            "--color=spinner:#e0af68,info:#7dcfff"
            "--color=pointer:#bb9af7,marker:#ff9e64,prompt:#565f89"
            # layout
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
    }
    // lib.optionalAttrs hasNestedWidgets {
        fileWidget = {
            command = fileWidgetCommand;
            options = fileWidgetOptions;
        };
        historyWidget.options = historyWidgetOptions;
        changeDirWidget = {
            command = changeDirWidgetCommand;
            options = changeDirWidgetOptions;
        };
    }
    // lib.optionalAttrs (!hasNestedWidgets) {
        inherit
            fileWidgetCommand
            fileWidgetOptions
            historyWidgetOptions
            changeDirWidgetCommand
            changeDirWidgetOptions
            ;
    };
}
