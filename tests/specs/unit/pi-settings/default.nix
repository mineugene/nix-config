{ pkgs }:
pkgs.runCommandLocal "pi-settings-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.dash
        pkgs.jq
    ];
    piSettingsTest = ./pi-settings.sh;
    configure = ../../../../home/modules/pi/configure-settings.sh;
    settingsFilter = ../../../../home/modules/pi/settings.jq;
    declaredFilter = ../../../../home/modules/pi/declared-settings.jq;
} (builtins.readFile ./pi-settings-check.sh)
