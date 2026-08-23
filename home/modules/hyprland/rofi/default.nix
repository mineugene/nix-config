{
    config,
    lib,
    pkgs,
    ...
}:
let
    desktopTheme = lib.getExe (
        builtins.head (builtins.filter (package: package.name == "desktop-theme") config.home.packages)
    );
    lock = lib.getExe config.programs.hyprlock.package;
    rofi = lib.getExe config.programs.rofi.package;
    theme = config.mine.desktop.theme;
    paletteValues = colors: {
        inherit (colors)
            accent
            accentAlt
            background
            border
            cyan
            foreground
            green
            muted
            red
            surface
            surfaceAlt
            surfaceHover
            yellow
            ;
        surfaceTranslucent = "${colors.surface}cc";
        interfaceFontFamily = theme.fonts.interface.family;
        interfaceFontSize = toString theme.fonts.interface.size;
        monospaceFontFamily = theme.fonts.monospace.family;
        radiusSmall = toString theme.radius.small;
        radiusCard = toString theme.radius.card;
        radiusPill = toString theme.radius.pill;
        borderWidth = toString theme.border.width;
        spacingSmall = toString theme.spacing.small;
        spacingNormal = toString theme.spacing.normal;
        spacingLarge = toString theme.spacing.large;
        popupPadding = toString theme.popup.padding;
    };
    uiClipboard = pkgs.writeShellApplication {
        name = "ui-clipboard";
        text =
            builtins.replaceStrings
                [
                    "@cliphist@"
                    "@desktopTheme@"
                    "@mktemp@"
                    "@rofi@"
                    "@wlCopy@"
                ]
                [
                    (lib.getExe pkgs.cliphist)
                    desktopTheme
                    (lib.getExe' pkgs.coreutils "mktemp")
                    rofi
                    (lib.getExe' pkgs.wl-clipboard "wl-copy")
                ]
                (builtins.readFile ./scripts/ui-clipboard);
    };
    uiConfirm = pkgs.writeShellApplication {
        name = "ui-confirm";
        text =
            builtins.replaceStrings
                [
                    "@desktopTheme@"
                    "@rofi@"
                ]
                [
                    desktopTheme
                    rofi
                ]
                (builtins.readFile ./scripts/ui-confirm);
    };
    uiLauncher = pkgs.writeShellApplication {
        name = "ui-launcher";
        text =
            builtins.replaceStrings
                [
                    "@desktopTheme@"
                    "@rofi@"
                ]
                [
                    desktopTheme
                    rofi
                ]
                (builtins.readFile ./scripts/ui-launcher);
    };
    uiPower = pkgs.writeShellApplication {
        name = "ui-power";
        text =
            builtins.replaceStrings
                [
                    "@confirm@"
                    "@desktopTheme@"
                    "@lock@"
                    "@rofi@"
                    "@systemctl@"
                    "@uwsm@"
                ]
                [
                    (lib.getExe uiConfirm)
                    desktopTheme
                    lock
                    rofi
                    (lib.getExe' pkgs.systemd "systemctl")
                    (lib.getExe pkgs.uwsm)
                ]
                (builtins.readFile ./scripts/ui-power);
    };
    themeEntrypoints = builtins.listToAttrs (
        lib.concatMap
            (
                variant:
                map
                    (mode: {
                        name = "rofi/themes/${variant}-${mode}.rasi";
                        value.text = ''
                            @import "${mode}.rasi"
                            @import "base.rasi"
                            @import "${variant}.rasi"
                        '';
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
