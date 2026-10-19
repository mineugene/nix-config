{
    homePackages,
    pkgs,
}:
let
    homePackage = name: builtins.head (builtins.filter (package: package.name == name) homePackages);
in
pkgs.runCommandLocal "rofi-command-check" {
    nativeBuildInputs = map homePackage [
        "ui-clipboard"
        "ui-confirm"
        "ui-launcher"
        "ui-power"
    ];
} (builtins.readFile ./rofi.sh)
