{
    config,
    lib,
    pkgs,
    ...
}:
let
    eww = lib.getExe config.programs.eww.package;
    swayncClient = lib.getExe' config.services.swaync.package "swaync-client";
    popupNames = [
        "audio"
        "calendar"
        "hardware"
        "network"
    ];
    popupToggleScript =
        builtins.replaceStrings
            [
                "@awk@"
                "@eww@"
                "@popupNames@"
            ]
            [
                (lib.getExe pkgs.gawk)
                eww
                (lib.concatStringsSep " " popupNames)
            ]
            (builtins.readFile ./config/scripts/popup-toggle);
    popupToggle = pkgs.writeShellApplication {
        name = "popup-toggle";
        text = popupToggleScript;
    };
    theme = config.mine.desktop.theme;
    desktopTheme = builtins.head (
        builtins.filter (package: package.name == "desktop-theme") config.home.packages
    );
    hyprlandInitial = builtins.toJSON {
        workspaces = builtins.genList (index: {
            id = index + 1;
            occupied = false;
            active = false;
            urgent = false;
        }) 9;
        title = "";
        class = "";
    };
    hyprlandListener = pkgs.writeShellApplication {
        name = "eww-hyprland-listener";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.hyprland
            pkgs.jq
            pkgs.socat
        ];
        text = builtins.readFile ./scripts/hyprland-listener.sh;
    };
    workspaceCommand = pkgs.writeShellApplication {
        name = "eww-workspace";
        runtimeInputs = [ pkgs.hyprland ];
        text = builtins.readFile ./scripts/workspace.sh;
    };
    audioCommand = pkgs.writeShellApplication {
        name = "eww-audio";
        runtimeInputs = [
            pkgs.gawk
            pkgs.jq
            pkgs.wireplumber
        ];
        text = builtins.readFile ./scripts/audio.sh;
    };
    hardwareStatus = pkgs.writeShellApplication {
        name = "eww-hardware-status";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.hyprland
            pkgs.jq
        ];
        text = builtins.readFile ./scripts/hardware-status.sh;
    };
    networkListener = pkgs.writeShellApplication {
        name = "eww-network-listener";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
            pkgs.networkmanager
        ];
        text = builtins.readFile ./scripts/network-listener.sh;
    };
    themeListener = pkgs.writeShellApplication {
        name = "eww-theme-listener";
        runtimeInputs = [
            desktopTheme
            pkgs.coreutils
            pkgs.inotify-tools
        ];
        text = builtins.readFile ./scripts/theme-listener.sh;
    };
in
{
    home.packages = [
        audioCommand
        hardwareStatus
        networkListener
        popupToggle
    ];

    programs.eww = {
        enable = true;
        systemd.enable = true;
    };

    systemd.user.services.eww.Service = {
        ExecStartPost = "${eww} --no-daemonize open bar";
        Restart = "on-failure";
        RestartSec = 2;
    };

    xdg.configFile = {
        "eww/eww.yuck".source = ./config/eww.yuck;
        "eww/eww.scss".source = ./config/eww.scss;
        "eww/popups/common.yuck".source = ./config/popups/common.yuck;
        "eww/popups/audio.yuck".source = pkgs.replaceVars ./config/popups/audio.yuck {
            audio = lib.getExe audioCommand;
            popupRight = toString theme.bar.outerMargin;
            popupTop = toString (theme.bar.outerMargin + theme.bar.height + theme.spacing.small);
            spacingNormal = toString theme.spacing.normal;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/popups/calendar.yuck".source = pkgs.replaceVars ./config/popups/calendar.yuck {
            date = lib.getExe' pkgs.coreutils "date";
            popupTop = toString (theme.bar.outerMargin + theme.bar.height + theme.spacing.small);
        };
        "eww/popups/hardware.yuck".source = pkgs.replaceVars ./config/popups/hardware.yuck {
            popupTop = toString (theme.bar.outerMargin + theme.bar.height + theme.spacing.small);
            spacingNormal = toString theme.spacing.normal;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/popups/network.yuck".source = pkgs.replaceVars ./config/popups/network.yuck {
            popupRight = toString theme.bar.outerMargin;
            popupTop = toString (theme.bar.outerMargin + theme.bar.height + theme.spacing.small);
            spacingNormal = toString theme.spacing.normal;
        };
        "eww/bar.yuck".source = pkgs.replaceVars ./config/bar.yuck {
            barHeight = toString theme.bar.height;
            barOuterMargin = toString theme.bar.outerMargin;
            spacingNormal = toString theme.spacing.normal;
        };
        "eww/modules/audio.yuck".source = pkgs.replaceVars ./config/modules/audio.yuck {
            audio = lib.getExe audioCommand;
            popupToggle = lib.getExe popupToggle;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/modules/clock.yuck".source = pkgs.replaceVars ./config/modules/clock.yuck {
            date = lib.getExe' pkgs.coreutils "date";
            popupToggle = lib.getExe popupToggle;
        };
        "eww/modules/hardware.yuck".source = pkgs.replaceVars ./config/modules/hardware.yuck {
            hardwareStatus = lib.getExe hardwareStatus;
            popupToggle = lib.getExe popupToggle;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/modules/network.yuck".source = pkgs.replaceVars ./config/modules/network.yuck {
            networkListener = lib.getExe networkListener;
            popupToggle = lib.getExe popupToggle;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/modules/notifications.yuck".source = pkgs.replaceVars ./config/modules/notifications.yuck {
            inherit swayncClient;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/scripts/popup-toggle" = {
            text = popupToggleScript;
            executable = true;
        };
        "eww/modules/theme.yuck".source = pkgs.replaceVars ./config/modules/theme.yuck {
            defaultMode = theme.defaultMode;
            desktopTheme = lib.getExe desktopTheme;
            themeListener = lib.getExe themeListener;
        };
        "eww/modules/tray.yuck".source = pkgs.replaceVars ./config/modules/tray.yuck {
            spacingSmall = toString theme.spacing.small;
        };
        "eww/modules/workspaces.yuck".source = pkgs.replaceVars ./config/modules/workspaces.yuck {
            inherit hyprlandInitial;
            hyprlandListener = lib.getExe hyprlandListener;
            spacingSmall = toString theme.spacing.small;
            workspaceCommand = lib.getExe workspaceCommand;
        };
        "eww/modules/window.yuck".source = ./config/modules/window.yuck;
        "eww/theme.scss".source = config.xdg.configFile."mineugene-desktop/theme/tokens.scss".source;
    };
}
