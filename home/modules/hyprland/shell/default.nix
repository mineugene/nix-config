{
    config,
    lib,
    pkgs,
    osConfig ? { },
    ...
}:
let
    shellConfig = import ./config.nix {
        inherit
            config
            lib
            pkgs
            osConfig
            ;
    };
    homePackage =
        name: builtins.head (builtins.filter (package: package.name == name) config.home.packages);
    desktopTheme = homePackage "desktop-theme";
    monitorTopology = homePackage "monitor-topology";
    uiPower = homePackage "ui-power";
    uiKill = homePackage "ui-kill";
    script =
        {
            name,
            file,
            inputs ? [ ],
            env ? { },
            extra ? { },
        }:
        pkgs.writeShellApplication (
            {
                inherit name;
                runtimeInputs = inputs;
                runtimeEnv = env;
                text = builtins.readFile file;
            }
            // extra
        );
    audioCommand = script {
        name = "shell-audio";
        file = ./scripts/audio.sh;
        inputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.wireplumber
        ];
    };
    bluetoothCommand = script {
        name = "shell-bluetooth";
        file = ./scripts/bluetooth.sh;
        inputs = [
            desktopTheme
            monitorTopology
            pkgs.bluez
            pkgs.coreutils
            pkgs.gnused
            pkgs.jq
            pkgs.rofi
        ];
    };
    hardwareStatus = script {
        name = "shell-hardware-status";
        file = ./scripts/hardware-status.sh;
        inputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.hyprland
            pkgs.jq
        ]
        ++ config.mine.desktop.hardware.extraPackages;
        # Seconds between readings; the bar meters and the hardware dashboard
        # share the one stream.
        env = {
            SHELL_HARDWARE_INTERVAL = "1.5";
        }
        // lib.optionalAttrs (config.mine.desktop.hardware.coolingCommand != null) {
            SHELL_HARDWARE_COOLING_CMD = config.mine.desktop.hardware.coolingCommand;
        }
        // lib.optionalAttrs (config.mine.desktop.hardware.cpuPowerCommand != null) {
            SHELL_HARDWARE_CPU_POWER_CMD = config.mine.desktop.hardware.cpuPowerCommand;
        };
    };
    menuCommand = script {
        name = "shell-menu";
        file = ./scripts/menu.sh;
        inputs = [
            pkgs.bottom
            config.programs.ghostty.package
            pkgs.hyprland
        ];
        env.SHELL_MENU_TERMINAL_DEFAULT = lib.getExe config.programs.ghostty.package;
    };
    networkListener = script {
        name = "shell-network-listener";
        file = ./scripts/network-listener.sh;
        inputs = [
            desktopTheme
            monitorTopology
            pkgs.coreutils
            pkgs.findutils
            pkgs.gawk
            pkgs.gnugrep
            pkgs.iproute2
            pkgs.iwd
            pkgs.jq
            pkgs.rofi
            pkgs.systemd
        ];
    };
    powerStatus = script {
        name = "shell-power-status";
        file = ./scripts/power-status.sh;
        inputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.jq
            pkgs.systemd
        ];
    };
    themeListener = script {
        name = "shell-theme-listener";
        file = ./scripts/theme-listener.sh;
        inputs = [
            desktopTheme
            pkgs.coreutils
            pkgs.inotify-tools
        ];
    };
    workspaceCommand = script {
        name = "shell-workspace";
        file = ./scripts/workspace.sh;
        inputs = [ pkgs.hyprland ];
    };
    # The shell finds its helpers on PATH instead of embedding store paths in
    # the QML sources. A configured extension contributes its own helpers.
    extensionPackages =
        if config.mine.desktop.audio.extension == null then
            [ ]
        else
            config.mine.desktop.audio.extension.packages;
    shellPath = lib.makeBinPath (
        [
            audioCommand
            bluetoothCommand
            desktopTheme
            hardwareStatus
            menuCommand
            monitorTopology
            networkListener
            powerStatus
            themeListener
            uiKill
            uiPower
            workspaceCommand
            pkgs.coreutils
        ]
        ++ extensionPackages
    );
in
{
    options.mine.desktop.audio.extension = lib.mkOption {
        type = lib.types.nullOr (
            lib.types.submodule {
                options = {
                    qml = lib.mkOption {
                        type = lib.types.path;
                        description = ''
                            Directory of QML and JavaScript sources merged into the
                            desktop shell configuration. `AudioExtension.qml` in this
                            directory is the entry point the audio popup renders below
                            its PipeWire sections.
                        '';
                    };
                    packages = lib.mkOption {
                        type = lib.types.listOf lib.types.package;
                        default = [ ];
                        description = ''
                            Packages added to the desktop shell's PATH for the
                            extension's helper commands.
                        '';
                    };
                };
            }
        );
        default = null;
        description = ''
            Optional audio popup extension for a mixer other than PipeWire. When
            set, the popup renders the supplied component below its PipeWire
            sections and the shell PATH gains the helper packages. When null the
            popup is unchanged.
        '';
    };

    options.mine.desktop.hardware = {
        extraPackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = ''
                Packages added to the hardware helper's PATH. Use this to
                supply an optional sensor tool the default backend probes for,
                such as liquidctl for a USB AIO cooler.
            '';
        };
        coolingCommand = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
                Executable that reports the cooler's fan and pump speeds when
                the default hwmon and liquidctl scan cannot name them. It
                prints `cpu_fan_rpm=<n>` and `aio_pump_rpm=<n>`, one per line,
                and any value it omits is left unavailable. Supply an absolute
                executable path, for example `lib.getExe` of a package or a
                store path to a script.
            '';
        };
        cpuPowerCommand = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
                Executable that prints the CPU package power in watts when
                hwmon and RAPL cannot be read, for example because the energy
                counter is root-only. Supply an absolute executable path.
            '';
        };
    };

    config = {
        home.packages = [
            audioCommand
            bluetoothCommand
            hardwareStatus
            menuCommand
            networkListener
            powerStatus
            themeListener
            workspaceCommand
            pkgs.quickshell
        ];

        systemd.user.services.quickshell = {
            Unit = {
                Description = "Quickshell desktop bar";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                ExecStart = "${lib.getExe pkgs.quickshell} --no-duplicate --path ${shellConfig.qml}/bar.qml";
                Environment = [
                    "PATH=${shellPath}"
                    "SHELL_TOKENS=${shellConfig.tokens}"
                ];
                Restart = "on-failure";
                RestartSec = 2;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };

        xdg.configFile."quickshell/desktop".source = shellConfig.qml;
    };
}
