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
    monitorTopology = builtins.head (
        builtins.filter (package: lib.getName package == "monitor-topology") config.home.packages
    );
    lockCommand = builtins.head (
        builtins.filter (package: package.name == "shell-lock") config.home.packages
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
        radiusGeneral = toString theme.radius.general;
        radiusSmall = toString theme.radius.small;
        borderWidth = toString theme.border.width;
        spacingSmall = toString theme.spacing.small;
        spacingNormal = toString theme.spacing.normal;
        spacingLarge = toString theme.spacing.large;
    };
    uiClipboard = pkgs.writeShellApplication {
        name = "ui-clipboard";
        runtimeInputs = [
            desktopTheme
            monitorTopology
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
            monitorTopology
            rofi
        ];
        text = builtins.readFile ./scripts/ui-confirm;
    };
    uiLauncher = pkgs.writeShellApplication {
        name = "ui-launcher";
        runtimeInputs = [
            desktopTheme
            monitorTopology
            rofi
        ];
        text = builtins.readFile ./scripts/ui-launcher;
    };
    uiKill = pkgs.writeShellApplication {
        name = "ui-kill";
        runtimeInputs = [
            desktopTheme
            monitorTopology
            pkgs.coreutils
            pkgs.gawk
            pkgs.hyprland
            pkgs.jq
            pkgs.procps
            rofi
        ];
        text = builtins.readFile ./scripts/ui-kill;
    };
    uiPower = pkgs.writeShellApplication {
        name = "ui-power";
        runtimeInputs = [
            lockCommand
            desktopTheme
            monitorTopology
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
                "menu"
            ]
    );
in
{
    home.packages = [
        uiClipboard
        uiConfirm
        uiKill
        uiLauncher
        uiPower
    ];

    xdg.configFile = {
        "rofi/themes/base.rasi".source = ./themes/base.rasi;
        "rofi/themes/launcher.rasi".source = ./themes/launcher.rasi;
        "rofi/themes/confirm.rasi".source = ./themes/confirm.rasi;
        "rofi/themes/menu.rasi".source = ./themes/menu.rasi;
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
