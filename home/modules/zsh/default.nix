{
    config,
    lib,
    pkgs,
    zshGitEscapeMagicSrc,
    zshGitIgnoreSrc,
    ...
}:
{
    imports = [
        ./aliases.nix
        ./completions.nix
        ./keymap.nix
        ./options.nix
        ./widgets.nix
    ];

    home.sessionVariables = {
        ZSH_COMPDUMP = lib.mkDefault "${config.xdg.stateHome}/zsh";
        ZSH_RUNTIMEPATH = lib.mkDefault "${config.xdg.dataHome}/zsh";
    };

    programs.zsh = {
        enable = true;

        plugins = [
            {
                name = "autopair";
                src = pkgs.zsh-autopair;
                file = "share/zsh/zsh-autopair/autopair.zsh";
            }
            {
                name = "you-should-use";
                src = pkgs.zsh-you-should-use;
                file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
            }
            {
                name = "git-ignore";
                src = zshGitIgnoreSrc;
                file = "git-ignore.plugin.zsh";
            }
        ]
        ++ lib.optionals config.programs.git.enable [
            {
                name = "git-escape-magic";
                src = zshGitEscapeMagicSrc;
                file = "git-escape-magic";
            }
        ];

        dotDir = "${config.xdg.configHome}/zsh";
        defaultKeymap = "viins";
        enableCompletion = true;
        autosuggestion = {
            enable = true;
            strategy = [
                "history"
                "completion"
            ];
        };
        syntaxHighlighting = {
            enable = true;
            styles = {
                path = "none";
                path_prefix = "none";
            };
        };
        history = {
            path = "${config.xdg.stateHome}/zsh/history";
            size = 1000;
            save = 9999;
            ignoreDups = true;
            ignoreAllDups = true;
            ignoreSpace = true;
            extended = true;
            share = true;
        };

        completionInit = builtins.readFile ./completion-init.zsh;

        initContent = lib.mkMerge [
            (lib.mkOrder 550 (
                builtins.replaceStrings [ "@configHome@" ] [ config.xdg.configHome ] (builtins.readFile ./fpath.zsh)
            ))
            (lib.mkOrder 1000 (builtins.readFile ./init.zsh))
        ];
    };
}
