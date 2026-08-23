{ config, pkgs, ... }:
let
    brave = pkgs.brave.override { commandLineArgs = "--ozone-platform=wayland"; };
    theme = config.mine.desktop.theme;
    ansiPalette = [
        "0=#15161e"
        "1=${theme.colors.dark.red}"
        "2=${theme.colors.dark.green}"
        "3=${theme.colors.dark.yellow}"
        "4=${theme.colors.dark.accent}"
        "5=${theme.colors.dark.accentAlt}"
        "6=${theme.colors.dark.cyan}"
        "7=#a9b1d6"
        "8=#414868"
        "9=#ff899d"
        "10=#9fe044"
        "11=#faba4a"
        "12=#8db0ff"
        "13=#c7a9ff"
        "14=#a4daff"
        "15=${theme.colors.dark.foreground}"
    ];
    ghosttyTheme = colors: {
        palette = ansiPalette;
        background = colors.background;
        foreground = colors.foreground;
        cursor-color = colors.foreground;
        selection-background = colors.surfaceHover;
        selection-foreground = colors.foreground;
    };
in
{
    home.packages = [ brave ];

    programs.ghostty = {
        enable = true;
        settings = {
            font-family = theme.fonts.monospace.family;
            font-size = 12;
            window-padding-x = theme.spacing.large;
            window-padding-y = theme.spacing.normal;
            theme = "light:mineugene-light,dark:mineugene-dark";
            window-theme = "system";
            cursor-style = "block";
            cursor-style-blink = false;
            shell-integration-features = "no-cursor";
            mouse-hide-while-typing = true;
        };
        themes = {
            mineugene-dark = ghosttyTheme theme.colors.dark;
            mineugene-light = ghosttyTheme theme.colors.light;
        };
    };

    xdg.mimeApps = {
        enable = true;
        defaultApplications = {
            "text/html" = [ "brave-browser.desktop" ];
            "x-scheme-handler/http" = [ "brave-browser.desktop" ];
            "x-scheme-handler/https" = [ "brave-browser.desktop" ];
        };
    };
}
