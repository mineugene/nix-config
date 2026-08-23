{
    defaultGtk4Theme,
    gtk4Css,
    gtk4Theme,
    pkgs,
}:
assert defaultGtk4Theme == null;
assert gtk4Theme == null;
assert gtk4Css == null;
pkgs.runCommandLocal "gtk4-theme-compatibility-check" { } "touch $out"
