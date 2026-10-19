{ pkgs }:
let
    mkScript =
        { name, src }:
        pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [
                pkgs.coreutils
                pkgs.gawk
                pkgs.gnugrep
                pkgs.jq
            ];
            text = builtins.readFile src;
        };
    hardwareStatus = mkScript {
        name = "shell-hardware-status";
        src = ../../../../home/modules/hyprland/shell/scripts/hardware-status.sh;
    };
    runtimeScripts =
        map
            (
                script:
                mkScript {
                    inherit (script) name;
                    src = ../../../../home/modules/hyprland/shell/scripts + "/${script.source}.sh";
                }
            )
            [
                {
                    name = "shell-audio";
                    source = "audio";
                }
                {
                    name = "shell-bluetooth";
                    source = "bluetooth";
                }
                {
                    name = "shell-network-listener";
                    source = "network-listener";
                }
                {
                    name = "shell-power-status";
                    source = "power-status";
                }
            ];
in
pkgs.runCommandLocal "shell-runtime-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.dash
        pkgs.findutils
        pkgs.gawk
        pkgs.gnused
        pkgs.jq
        pkgs.python3
        hardwareStatus
    ]
    ++ runtimeScripts;
    hardwareStatusCommand = pkgs.lib.getExe hardwareStatus;
    waitHelpers = ../../../support/wait.sh;
} (builtins.readFile ./scripts.sh)
