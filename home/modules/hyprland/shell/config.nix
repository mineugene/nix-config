{
    config,
    lib,
    pkgs,
    osConfig ? { },
}:
let
    theme = config.mine.desktop.theme;
    # Popup widths are a text measure, not a fixed box: one column is one
    # interface font size, so a larger font widens the panel with it. Action
    # menus share a narrow width; every other popup shares a wider one.
    menuColumns = 20;
    panelColumns = 30;
    menuNames = [
        "menu"
        "power-profile"
        "profile"
    ];
    panelNames = [
        "audio"
        "audioDevices"
        "battery"
        "bluetooth"
        "calendar"
        "ethernet"
        "hardware"
        "notifications"
        "wifi"
    ];
    trueBlack =
        theme.bar.trueBlack || lib.any (monitor: monitor.cm == "hdr") config.mine.desktop.display.monitors;
    tokens = {
        defaultMode = theme.defaultMode;
        colors = lib.recursiveUpdate theme.colors {
            dark.barBackground = if trueBlack then "#000000" else theme.colors.dark.background;
            light.barBackground = theme.colors.light.background;
        };
        fonts = {
            interface = {
                inherit (theme.fonts.interface) family size;
            };
            monospace.family = theme.fonts.monospace.family;
        };
        radius = theme.radius;
        cornerRoundingPower = theme.cornerRoundingPower;
        borderWidth = theme.border.width;
        spacing = theme.spacing;
        barHeight = theme.bar.height;
        # The bar reserves this gap under itself, so the compositor adds no
        # top gap of its own.
        barGap = theme.bar.outerMargin;
        popupPadding = theme.popup.padding;
        animation = theme.animation;
        popupWidth =
            lib.genAttrs menuNames (_: menuColumns * theme.fonts.interface.size)
            // lib.genAttrs panelNames (_: panelColumns * theme.fonts.interface.size);
        username = config.home.username;
        audioExtension = config.mine.desktop.audio.extension != null;
        # The profile cell is wired only where the host enables the daemon; the
        # runtime probe then hides it while the daemon is not answering.
        powerProfiles = osConfig.services.power-profiles-daemon.enable or false;
    };
    # An extension overlays its sources onto the base shell directory; with no
    # extension the directory is the base tree unchanged.
    extension = config.mine.desktop.audio.extension;
    link = directory: name: {
        inherit name;
        path = directory + "/${name}";
    };
in
{
    # The sources are read in place; the generated design tokens reach them
    # through the file `SHELL_TOKENS` names.
    qml =
        if extension == null then
            builtins.path {
                path = ./qml;
                name = "quickshell-desktop";
            }
        else
            pkgs.linkFarm "quickshell-desktop" (
                map (link ./qml) (builtins.attrNames (builtins.readDir ./qml))
                ++ map (link extension.qml) (builtins.attrNames (builtins.readDir extension.qml))
            );
    tokens = pkgs.writeText "quickshell-tokens.json" (builtins.toJSON tokens);
}
