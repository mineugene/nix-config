{
    config,
    lib,
    pkgs,
    ...
}:
let
    palettes = import ./palette.nix;
    theme = config.mine.desktop.theme;
    selectedColors = theme.colors.${theme.defaultMode};
    modeColorTokenValues = {
        darkAccent = theme.colors.dark.accent;
        darkAccentAlt = theme.colors.dark.accentAlt;
        darkBackground = theme.colors.dark.background;
        darkBorder = theme.colors.dark.border;
        darkCyan = theme.colors.dark.cyan;
        darkForeground = theme.colors.dark.foreground;
        darkGreen = theme.colors.dark.green;
        darkMuted = theme.colors.dark.muted;
        darkRed = theme.colors.dark.red;
        darkSurface = theme.colors.dark.surface;
        darkSurfaceAlt = theme.colors.dark.surfaceAlt;
        darkSurfaceHover = theme.colors.dark.surfaceHover;
        darkYellow = theme.colors.dark.yellow;
        lightAccent = theme.colors.light.accent;
        lightAccentAlt = theme.colors.light.accentAlt;
        lightBackground = theme.colors.light.background;
        lightBorder = theme.colors.light.border;
        lightCyan = theme.colors.light.cyan;
        lightForeground = theme.colors.light.foreground;
        lightGreen = theme.colors.light.green;
        lightMuted = theme.colors.light.muted;
        lightRed = theme.colors.light.red;
        lightSurface = theme.colors.light.surface;
        lightSurfaceAlt = theme.colors.light.surfaceAlt;
        lightSurfaceHover = theme.colors.light.surfaceHover;
        lightYellow = theme.colors.light.yellow;
    };
    numericTokenValues = builtins.mapAttrs (_: toString) {
        interfaceFontSize = theme.fonts.interface.size;
        radiusSmall = theme.radius.small;
        radiusCard = theme.radius.card;
        radiusPill = theme.radius.pill;
        borderWidth = theme.border.width;
        spacingSmall = theme.spacing.small;
        spacingNormal = theme.spacing.normal;
        spacingLarge = theme.spacing.large;
        barHeight = theme.bar.height;
        barOuterMargin = theme.bar.outerMargin;
        popupPadding = theme.popup.padding;
        animationFast = theme.animation.fast;
        animationNormal = theme.animation.normal;
        animationSlow = theme.animation.slow;
    };
    tokenValues =
        selectedColors
        // numericTokenValues
        // {
            interfaceFontFamily = theme.fonts.interface.family;
            monospaceFontFamily = theme.fonts.monospace.family;
        };
    scssTokenValues = tokenValues // modeColorTokenValues;
    swayncTheme =
        colors:
        pkgs.replaceVars ../swaync/theme.css {
            inherit (colors)
                accent
                background
                foreground
                muted
                red
                surface
                surfaceAlt
                surfaceHover
                yellow
                ;
            borderTranslucent = "${colors.border}cc";
            surfaceTranslucent = "${colors.surface}cc";
        };
    swayncClient = lib.getExe' config.services.swaync.package "swaync-client";
    swayncDarkTheme = swayncTheme theme.colors.dark;
    swayncLightTheme = swayncTheme theme.colors.light;
    desktopTheme = pkgs.writeShellApplication {
        name = "desktop-theme";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.dconf
            pkgs.glib
            pkgs.gsettings-desktop-schemas
        ];
        text = ''
            export DESKTOP_THEME_DEFAULT_MODE=${lib.escapeShellArg theme.defaultMode}
            export DESKTOP_THEME_GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas
            export DESKTOP_THEME_SWAYNC_CLIENT="''${DESKTOP_THEME_SWAYNC_CLIENT:-${swayncClient}}"
            export DESKTOP_THEME_SWAYNC_DARK_THEME=${lib.escapeShellArg swayncDarkTheme}
            export DESKTOP_THEME_SWAYNC_LIGHT_THEME=${lib.escapeShellArg swayncLightTheme}
            export GIO_EXTRA_MODULES=${pkgs.dconf.lib}/lib/gio/modules
            ${builtins.readFile ./desktop-theme.sh}
        '';
    };
in
{
    options.mine.desktop.theme = {
        defaultMode = lib.mkOption {
            type = lib.types.enum [
                "dark"
                "light"
            ];
            default = "dark";
            description = "Desktop theme used when no runtime state exists and for statically generated consumer files.";
        };

        colors = lib.mkOption {
            type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
            default = palettes;
            description = "Semantic colors shared by desktop UI components.";
        };

        fonts = {
            interface = {
                family = lib.mkOption {
                    type = lib.types.str;
                    default = "IosevkaNF";
                    description = "Interface font family.";
                };
                size = lib.mkOption {
                    type = lib.types.ints.positive;
                    default = 13;
                    description = "Interface font size in pixels.";
                };
            };
            monospace.family = lib.mkOption {
                type = lib.types.str;
                default = "IosevkaTermNF";
                description = "Monospace font family.";
            };
        };

        radius = {
            small = lib.mkOption {
                type = lib.types.ints.positive;
                default = 4;
                description = "Small control radius in pixels.";
            };
            card = lib.mkOption {
                type = lib.types.ints.positive;
                default = 6;
                description = "Card radius in pixels.";
            };
            pill = lib.mkOption {
                type = lib.types.ints.positive;
                default = 999;
                description = "Pill radius in pixels.";
            };
        };

        border.width = lib.mkOption {
            type = lib.types.ints.positive;
            default = 1;
            description = "Thin border width in pixels.";
        };

        spacing = {
            small = lib.mkOption {
                type = lib.types.ints.positive;
                default = 4;
                description = "Small spacing in pixels.";
            };
            normal = lib.mkOption {
                type = lib.types.ints.positive;
                default = 8;
                description = "Normal spacing in pixels.";
            };
            large = lib.mkOption {
                type = lib.types.ints.positive;
                default = 12;
                description = "Large spacing in pixels.";
            };
        };

        bar = {
            height = lib.mkOption {
                type = lib.types.ints.positive;
                default = 30;
                description = "Desktop bar height in pixels.";
            };
            outerMargin = lib.mkOption {
                type = lib.types.ints.positive;
                default = 6;
                description = "Desktop bar outer margin in pixels.";
            };
        };

        popup.padding = lib.mkOption {
            type = lib.types.ints.positive;
            default = 12;
            description = "Standard popup padding in pixels.";
        };

        animation = {
            fast = lib.mkOption {
                type = lib.types.ints.positive;
                default = 100;
                description = "Fast animation duration in milliseconds.";
            };
            normal = lib.mkOption {
                type = lib.types.ints.positive;
                default = 200;
                description = "Normal animation duration in milliseconds.";
            };
            slow = lib.mkOption {
                type = lib.types.ints.positive;
                default = 300;
                description = "Slow animation duration in milliseconds.";
            };
        };
    };

    config = {
        home.packages = [ desktopTheme ];

        systemd.user.services.desktop-theme = {
            Unit = {
                Description = "Apply the persisted desktop color scheme";
                After = [ "graphical-session.target" ];
                Before = [ "swaync.service" ];
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                Type = "oneshot";
                ExecStart = "${lib.getExe desktopTheme} apply";
                RemainAfterExit = true;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };

        xdg.configFile = {
            "mineugene-desktop/theme/swaync-dark.css".source = swayncDarkTheme;
            "mineugene-desktop/theme/swaync-light.css".source = swayncLightTheme;
            "mineugene-desktop/theme/tokens.scss".source = pkgs.replaceVars ./tokens.scss scssTokenValues;
            "mineugene-desktop/theme/tokens.rasi".source = pkgs.replaceVars ./tokens.rasi tokenValues;
        };
    };
}
