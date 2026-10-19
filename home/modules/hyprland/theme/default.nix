{
    config,
    lib,
    pkgs,
    ...
}:
let
    palettes = import ./palette.nix;
    theme = config.mine.desktop.theme;
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
                    default = "IBM Plex Sans Condensed";
                    description = "Interface font family.";
                };
                package = lib.mkPackageOption pkgs [ "ibm-plex" "sans-condensed" ] { } // {
                    description = "Package providing the interface family.";
                };
                size = lib.mkOption {
                    type = lib.types.ints.positive;
                    default = 13;
                    description = "Interface font size in pixels.";
                };
            };
            serif = {
                family = lib.mkOption {
                    type = lib.types.str;
                    default = "IBM Plex Serif";
                    description = "Serif font family.";
                };
                package = lib.mkPackageOption pkgs [ "ibm-plex" "serif" ] { } // {
                    description = "Package providing the serif family.";
                };
            };
            monospace = {
                family = lib.mkOption {
                    type = lib.types.str;
                    default = "Iosevka Term";
                    description = "Monospace font family.";
                };
                package = lib.mkPackageOption pkgs "iosevka-ss04" { } // {
                    description = "Package providing the monospace family.";
                };
            };
        };

        # Fixed design scale shared by every consumer, not a user setting.
        radius = lib.mkOption {
            internal = true;
            default = {
                general = 8;
                small = 4;
            };
        };

        # Hyprland's `decoration:rounding_power`: 1 is a straight chamfer, 2 a
        # circular arc, and higher values squarer superellipse corners. The
        # Quickshell bar mirrors it so both sets of corners match.
        cornerRoundingPower = lib.mkOption {
            type = lib.types.number;
            default = 2.0;
            description = ''
                Corner rounding power shared by Hyprland windows and the
                Quickshell bar. 1 is a straight chamfer, 2 a circular arc, and
                higher values squarer superellipse corners. Hyprland scales the
                configured radius by this value over two.
            '';
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
                # follows the text. The result must stay even so the square bar
                # cells sit on whole pixels.
                default = config.mine.desktop.theme.fonts.interface.size * 2 + 4;
                defaultText = lib.literalExpression "fonts.interface.size * 2 + 4";
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
            default.padding = 16;
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
        # The square meters are the bar height wide, and the workspace cells
        # are the bar height less one (even) spacing step.
        assertions = [
            {
                assertion = lib.mod theme.bar.height 2 == 0;
                message = "mine.desktop.theme.bar.height must be even to keep the square meters on whole pixels, got ${toString theme.bar.height}.";
            }
        ];

        home.packages = [ desktopTheme ];

        systemd.user.services.desktop-theme = {
            Unit = {
                Description = "Apply the persisted desktop color scheme";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                Type = "oneshot";
                ExecStart = "${lib.getExe desktopTheme} apply";
                RemainAfterExit = true;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };
    };
}
