{
    pkgs,
    defaultGtk4Theme,
    gtk4Theme,
}:
assert defaultGtk4Theme == null;
assert gtk4Theme.name == "Adwaita";
pkgs.runCommandLocal "gtk4-theme-compatibility-check" { } "touch $out"
