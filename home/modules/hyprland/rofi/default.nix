{
    config,
    lib,
    pkgs,
    ...
}:
let
    desktopTheme = builtins.head (
        builtins.filter (package: package.name == "desktop-theme") config.home.packages
    );
    rofi = config.programs.rofi.package;
    theme = config.mine.desktop.theme;
    paletteValues = colors: {
        inherit (colors)
            accent
            border
            foreground
            muted
            surfaceHover
            ;
        surfaceTranslucent = "${colors.surface}cc";
        interfaceFontFamily = theme.fonts.interface.family;
        interfaceFontSize = toString theme.fonts.interface.size;
        # A list is scanned rather than read, and rofi sizes its rows and its
        # icons from the font, so two steps down shortens the whole window.
        interfaceFontSizeSmall = toString (theme.fonts.interface.size - 2);
        monospaceFontFamily = theme.fonts.monospace.family;
        radiusCard = toString theme.radius.card;
        borderWidth = toString theme.border.width;
        spacingSmall = toString theme.spacing.small;
        spacingNormal = toString theme.spacing.normal;
        spacingLarge = toString theme.spacing.large;
    };
    uiClipboard = pkgs.writeShellApplication {
        name = "ui-clipboard";
        runtimeInputs = [
            desktopTheme
            pkgs.cliphist
            pkgs.coreutils
            pkgs.wl-clipboard
            rofi
        ];
        text = builtins.readFile ./scripts/ui-clipboard;
    };
    uiConfirm = pkgs.writeShellApplication {
        name = "ui-confirm";
        runtimeInputs = [
            desktopTheme
            rofi
        ];
        text = builtins.readFile ./scripts/ui-confirm;
    };
    uiLauncher = pkgs.writeShellApplication {
        name = "ui-launcher";
        runtimeInputs = [
            desktopTheme
            rofi
        ];
        text = builtins.readFile ./scripts/ui-launcher;
    };
    uiPower = pkgs.writeShellApplication {
        name = "ui-power";
        runtimeInputs = [
            config.programs.hyprlock.package
            desktopTheme
            pkgs.systemd
            pkgs.uwsm
            rofi
            uiConfirm
        ];
        text = builtins.readFile ./scripts/ui-power;
    };
    themeEntrypoints = builtins.listToAttrs (
        lib.concatMap
            (
                variant:
                map
                    (mode: {
                        name = "rofi/themes/${variant}-${mode}.rasi";
                        value.source = pkgs.replaceVars ./themes/entrypoint.rasi {
                            inherit mode variant;
                        };
                    })
                    [
                        "dark"
                        "light"
                    ]
            )
            [
                "launcher"
                "confirm"
                "clipboard"
                "power"
            ]
    );
in
{
    home.packages = [
        uiClipboard
        uiConfirm
        uiLauncher
        uiPower
    ];

    xdg.configFile = {
        "rofi/themes/base.rasi".source = ./themes/base.rasi;
        "rofi/themes/launcher.rasi".source = ./themes/launcher.rasi;
        "rofi/themes/confirm.rasi".source = ./themes/confirm.rasi;
        "rofi/themes/clipboard.rasi".source = ./themes/clipboard.rasi;
        "rofi/themes/power.rasi".source = ./themes/power.rasi;
        "rofi/themes/dark.rasi".source = pkgs.replaceVars ./themes/palette.rasi (
            paletteValues theme.colors.dark
        );
        "rofi/themes/light.rasi".source = pkgs.replaceVars ./themes/palette.rasi (
            paletteValues theme.colors.light
        );
    }
    // themeEntrypoints;
}
