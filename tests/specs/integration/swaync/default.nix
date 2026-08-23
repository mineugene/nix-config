{
    pkgs,
    swaync,
    swayncConfig,
}:
pkgs.runCommandLocal "swaync-daemon-check" {
    nativeBuildInputs = [
        pkgs.check-jsonschema
        pkgs.glib.dev
        pkgs.python3
    ];
    config = swayncConfig;
    package = swaync.package;
    schema = "${swaync.package}/etc/xdg/swaync/configSchema.json";
    uiCheck = ./swaync-ui.py;
} (builtins.readFile ./swaync.sh)
