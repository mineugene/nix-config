{
    lib,
    pkgs,
    ...
}:
{
    programs.yazi = {
        enable = true;
        shellWrapperName = "y";
        extraPackages = [
            pkgs.lsd
            pkgs.wl-clipboard
        ];
        initLua = ./init.lua;
        settings.plugin.prepend_previewers = [
            {
                url = "*/";
                run = "lsd-preview";
            }
        ];
        plugins = {
            smart-enter = pkgs.yaziPlugins.smart-enter;
            lsd-preview = pkgs.writeTextDir "main.lua" (builtins.readFile ./lsd-preview.lua);
            icon-pad = {
                package = pkgs.writeTextDir "main.lua" (builtins.readFile ./icon-pad.lua);
                setup = true;
            };
        };
        keymap.mgr.prepend_keymap = [
            {
                on = "<Enter>";
                run = "plugin smart-enter";
                desc = "Enter directory or open file";
            }
        ];
    };

    # TokyoNight Night theme, originally vendored from
    # https://github.com/folke/tokyonight.nvim/blob/main/extras/yazi/tokyonight_night.toml
    # and updated for the yazi 26.x theme format.
    xdg.configFile."yazi/theme.toml".source = ./theme.toml;

    # Target the wrapper so quitting cds to the last directory.
    programs.zsh.shellAliases.fs = "y";

    # Alt-y launches yazi; the wrapper cds the shell to the directory
    # yazi quit in.
    programs.zsh.initContent = lib.mkOrder 1000 ''
        yazi-file-manager() {
            y
            [[ -n "$WIDGET" ]] && zle reset-prompt
        }
        zle -N yazi-file-manager
        bindkey -M viins '^[y' yazi-file-manager
        bindkey -M vicmd '^[y' yazi-file-manager
    '';
}
