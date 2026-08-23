{
    pkgs,
    nixosSystem,
    hyprlandNvidiaModule,
}:
let
    system = nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
            hyprlandNvidiaModule
            {
                nixpkgs.config.allowUnfree = true;
                system.stateVersion = "25.11";
            }
        ];
    };
    cfg = system.config;
    etc = cfg.environment.etc;
    ewwScss = etc."greetd/eww/eww.scss".source;
    ewwYuck = etc."greetd/eww/eww.yuck".source;
    greeterSessionExecutable = etc."greetd/greeter-session".source;
    greeterSessionSource = ../../../../nixos/modules/hyprland-nvidia/scripts/greeter-session.sh;
    wayfireConfig = etc."greetd/wayfire.ini".source;
    startGreeterSource = ../../../../nixos/modules/hyprland-nvidia/scripts/start-greeter.sh;
in
pkgs.runCommandLocal "hyprland-nvidia-check" {
    nativeBuildInputs = [
        pkgs.dbus
        pkgs.eww
        pkgs.wayfire
        pkgs.xvfb-run
        pkgs.shellcheck
        pkgs.dash
    ];
    inherit
        ewwScss
        ewwYuck
        greeterSessionExecutable
        greeterSessionSource
        wayfireConfig
        startGreeterSource
        ;
    dashCommand = "${pkgs.dash}/bin/dash";
    wayfireCommand = "${pkgs.wayfire}/bin/wayfire";
    dbusRunSession = "${pkgs.dbus}/bin/dbus-run-session";
    dbusConfig = "${pkgs.dbus}/share/dbus-1/session.conf";
    xvfbRun = "${pkgs.xvfb-run}/bin/xvfb-run";
    greeterPath = pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
    ];
    smokePath = pkgs.lib.makeBinPath [
        pkgs.dbus
        pkgs.eww
        pkgs.coreutils
    ];
    smokeScript = ./greeter-eww-smoke.sh;
    waitHelpers = ../../../support/wait.sh;
} (builtins.readFile ./hyprland-nvidia.sh)
