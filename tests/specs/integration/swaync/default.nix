{
    pkgs,
    swaync,
    swayncConfig,
    swayncService,
}:
pkgs.runCommandLocal "swaync-daemon-check" {
    nativeBuildInputs = [
        pkgs.check-jsonschema
        pkgs.glib.dev
        pkgs.gnugrep
        pkgs.python3
    ];
    config = swayncConfig;
    package = swaync.package;
    schema = "${swaync.package}/etc/xdg/swaync/configSchema.json";
    style = swaync.style;
    uiCheck = ./swaync-ui.py;
    serviceEnvironment = builtins.concatStringsSep " " (swayncService.Service.Environment or [ ]);
} (builtins.readFile ./swaync.sh)
