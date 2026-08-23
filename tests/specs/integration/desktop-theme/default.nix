{
    pkgs,
    homePackages,
    defaultMode,
    swayncDarkTheme,
    swayncLightTheme,
}:
let
    desktopTheme = builtins.head (builtins.filter (pkg: pkg.name == "desktop-theme") homePackages);
    schemaDir = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
in
pkgs.runCommandLocal "desktop-theme-command-check" {
    nativeBuildInputs = [
        desktopTheme
        pkgs.glib
        pkgs.gsettings-desktop-schemas
    ];
    inherit
        defaultMode
        swayncDarkTheme
        swayncLightTheme
        schemaDir
        ;
} (builtins.readFile ./desktop-theme.sh)
