{ pkgs }:
let
    mkScript =
        { name, src }:
        pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [
                pkgs.coreutils
                pkgs.gawk
                pkgs.jq
            ];
            text = builtins.readFile src;
        };
    hardwareStatus = mkScript {
        name = "eww-hardware-status";
        src = ../../../../home/modules/hyprland/eww/scripts/hardware-status.sh;
    };
    runtimeScripts =
        map
            (
                script:
                mkScript {
                    inherit (script) name;
                    src = ../../../../home/modules/hyprland/eww/scripts + "/${script.source}.sh";
                }
            )
            [
                {
                    name = "eww-animation-frame";
                    source = "animation-frame";
                }
                {
                    name = "eww-audio";
                    source = "audio";
                }
                {
                    name = "eww-bluetooth";
                    source = "bluetooth";
                }
                {
                    name = "eww-network-listener";
                    source = "network-listener";
                }
            ];
in
pkgs.runCommandLocal "eww-runtime-check" {
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
    EWW_RUNTIME_ONLY = "1";
    EWW_AUDIO_MONITOR_OUTPUTS = builtins.toJSON [
        {
            label = "Headphones";
            node = "alsa_output.usb-Check_Headphones-00.analog-stereo";
        }
        {
            label = "Speakers";
            node = "alsa_output.usb-Check_Speakers-00.analog-stereo";
        }
    ];
    hardwareStatusCommand = pkgs.lib.getExe hardwareStatus;
    hyprlandListenerSource = ../../../../home/modules/hyprland/eww/scripts/hyprland-listener.sh;
    audioSource = ../../../../home/modules/hyprland/eww/scripts/audio.sh;
    waitHelpers = ../../../support/wait.sh;
    audioListenerTest = ./audio-listener.py;
    audioSubscriber = ../../../fixtures/audio-subscriber.py;
    audioControl = ../../../fixtures/audio-control.py;
} (builtins.readFile ./eww.sh)
