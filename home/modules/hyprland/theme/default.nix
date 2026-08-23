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
    capitalize = name: lib.toUpper (builtins.substring 0 1 name) + builtins.substring 1 (-1) name;
    # One token per mode and palette entry, named like darkAccentAlt.
    modeColorTokenValues = lib.concatMapAttrs (
        mode: lib.mapAttrs' (name: lib.nameValuePair "${mode}${capitalize name}")
    ) { inherit (theme.colors) dark light; };
    scssTokenValues =
        builtins.mapAttrs (_: toString) {
            interfaceFontSize = theme.fonts.interface.size;
            radiusCard = theme.radius.card;
            radiusPill = theme.radius.pill;
            borderWidth = theme.border.width;
            spacingSmall = theme.spacing.small;
            spacingNormal = theme.spacing.normal;
            barHeight = theme.bar.height;
            popupPadding = theme.popup.padding;
            animationFast = theme.animation.fast;
        }
        // modeColorTokenValues
        // {
            inherit (selectedColors) surface surfaceHover;
            interfaceFontFamily = theme.fonts.interface.family;
            monospaceFontFamily = theme.fonts.monospace.family;
            darkBarBackground = if theme.bar.trueBlack then "#000000" else theme.colors.dark.background;
            lightBarBackground = theme.colors.light.background;
        };
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
        runtimeEnv = {
            DESKTOP_THEME_DEFAULT_MODE = theme.defaultMode;
            DESKTOP_THEME_GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
            DESKTOP_THEME_SWAYNC_CLIENT_DEFAULT = swayncClient;
            DESKTOP_THEME_SWAYNC_DARK_THEME = swayncDarkTheme;
            DESKTOP_THEME_SWAYNC_LIGHT_THEME = swayncLightTheme;
            GIO_EXTRA_MODULES = "${pkgs.dconf.lib}/lib/gio/modules";
        };
        text = builtins.readFile ./desktop-theme.sh;
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
                    default = "IosevkaAileNF";
                    description = "Interface font family.";
                };
                package = lib.mkPackageOption pkgs "iosevka-aile-nf" { } // {
                    description = "Package providing the interface family.";
                };
                size = lib.mkOption {
                    type = lib.types.ints.positive;
                    default = 13;
                    description = "Interface font size in pixels.";
                };
            };
            monospace = {
                family = lib.mkOption {
                    type = lib.types.str;
                    default = "IosevkaTermNF";
                    description = "Monospace font family.";
                };
                package = lib.mkPackageOption pkgs "iosevka-term-nf" { } // {
                    description = "Package providing the monospace family.";
                };
            };
        };

        # Fixed design scale shared by every consumer, not a user setting.
        radius = lib.mkOption {
            internal = true;
            # The card radius is half the active-workspace marker diameter.
            default = rec {
                card = (theme.bar.height - 2 * theme.spacing.small) / 2;
                small = card;
                pill = 999;
            };
        };

        border = lib.mkOption {
            internal = true;
            default.width = 1;
        };

        spacing = lib.mkOption {
            internal = true;
            default = {
                small = 8;
                normal = 16;
                large = 24;
            };
        };

        bar = {
            height = lib.mkOption {
                type = lib.types.ints.positive;
                # Sized from the interface font rather than fixed, so the bar
                # follows the text. Twice the font size is always even and the
                # even padding keeps it so, which matters because a pill's end
                # cap is only a true half circle when the height it is clamped
                # to divides evenly.
                default = config.mine.desktop.theme.fonts.interface.size * 2 + 12;
                defaultText = lib.literalExpression "fonts.interface.size * 2 + 12";
                description = "Desktop bar height in pixels. Must be even.";
            };
            outerMargin = lib.mkOption {
                internal = true;
                default = 6;
            };
            trueBlack = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                    Use a true-black dark-mode bar canvas for OLED displays.
                    Light mode still uses its palette background.
                '';
            };
        };

        popup = lib.mkOption {
            internal = true;
            default.padding = 24;
        };

        animation = lib.mkOption {
            internal = true;
            default = {
                fast = 100;
                normal = 200;
            };
        };
    };

    config = {
        # A pill's end cap is only a true half circle when the height it clamps
        # to divides evenly, and the control sizes are the bar height less each
        # (even) spacing step.
        assertions = [
            {
                assertion = lib.mod theme.bar.height 2 == 0;
                message = "mine.desktop.theme.bar.height must be even to keep pill end caps circular, got ${toString theme.bar.height}.";
            }
        ];

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
        };
    };
}
