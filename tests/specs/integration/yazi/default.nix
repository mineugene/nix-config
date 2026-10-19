{
    yazi,
    yaziTheme,
    yaziSettings,
    yaziInit,
    pkgs,
}:
pkgs.runCommandLocal "yazi-check" {
    # Run yazi against the theme, init.lua, and plugins in a pty to
    # prove the pinned binary parses and renders them.
    nativeBuildInputs = [
        pkgs.python3
        yazi.finalPackage
    ];
    inherit yaziTheme yaziSettings;
    yaziInitSource = pkgs.writeText "yazi-init.lua" "${yaziInit}\n";
    iconPad = yazi.plugins.icon-pad.package;
    lsdPreview = yazi.plugins.lsd-preview.package;
    filetypeCheck = ./yazi-filetypes.awk;
    lsdIcons = ../../../fixtures/lsd-icons.yaml;
    renderCheck = ./yazi-render.py;
} (builtins.readFile ./yazi.sh)
