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

        completionInit = ''
            zstyle ':completion:*' menu select
            [[ -d $ZSH_COMPDUMP ]] || mkdir -p $ZSH_COMPDUMP
            zstyle :compinstall filename "$ZDOTDIR/zshrc"
            autoload -Uz compinit

            # Regenerate zcompdump only when stale (older than 20 minutes) or zsh version changed
            _comp_files=($ZSH_COMPDUMP/zcompdump(Nm-20))
            if (( $#_comp_files )); then
              compinit -d "$ZSH_COMPDUMP/zcompdump-''${ZSH_VERSION}"
            else
              compinit -C -d "$ZSH_COMPDUMP/zcompdump-''${ZSH_VERSION}"
            fi
        '';

        initContent = lib.mkMerge [
            (lib.mkOrder 550 ''
                # Autoload custom functions and widgets via fpath
                fpath=("${config.xdg.configHome}/zsh/functions" "${config.xdg.configHome}/zsh/widgets" "$ZSH_RUNTIMEPATH/completions" $fpath)
            '')
            (lib.mkOrder 1000 ''
                # Propagate session env to systemd user units so user services
                # (mako, yubikey-touch-notify, etc.) see WAYLAND_DISPLAY/DBus.
                if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]] && command -v systemctl >/dev/null 2>&1; then
                    systemctl --user import-environment \
                        WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS 2>/dev/null
                fi

                # Exclude directory separator from WORDCHARS
                WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

                # Bracketed paste: strip Windows CR and prevent command execution on paste
                autoload -Uz bracketed-paste-magic
                zle -N bracketed-paste bracketed-paste-magic
                zstyle :bracketed-paste-magic active-widgets '.self-insert'
                _fix-paste() { PASTED=''${PASTED//$'\r'/}; }
                zstyle :bracketed-paste-magic paste-finish _fix-paste

                # Autosuggestion config
                export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25
                export ZSH_AUTOSUGGEST_HISTORY_IGNORE='git *(--force|--force-with-lease)'

                # Syntax highlighting config
                export ZSH_HIGHLIGHT_MAXLENGTH=512
            '')
        ];
    };
}
