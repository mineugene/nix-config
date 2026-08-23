{
    config,
    lib,
    pkgs,
    ...
}:
let
    eww = lib.getExe config.programs.eww.package;
    # Icons are drawn at the largest step, and the stylesheet reserves 0.9em of
    # ink allowance for them. Both feed the measurement so the generated nudges
    # match what the bar actually renders.
    iconSize = theme.fonts.interface.size + 3;
    iconNudges =
        pkgs.runCommand "eww-icon-nudges.scss"
            {
                nativeBuildInputs = [
                    (pkgs.python3.withPackages (ps: [ ps.pygobject3 ]))
                    # Its setup hook puts the Pango typelibs on GI_TYPELIB_PATH,
                    # without which the introspection import fails in the sandbox.
                    pkgs.gobject-introspection
                    pkgs.gtk3
                    pkgs.pango
                ];
                # Fontconfig wants somewhere to cache; without it the build
                # still succeeds but floods the log with errors.
                XDG_CACHE_HOME = "cache";
                FONTCONFIG_FILE = pkgs.makeFontsConf {
                    fontDirectories = [ theme.fonts.monospace.package ];
                };
            }
            ''
                python3 ${./icon-metrics.py} \
                    --family ${lib.escapeShellArg theme.fonts.monospace.family} \
                    --size ${toString iconSize} \
                    --cell ${toString (0.9 * iconSize)} \
                    ${./config/modules} > "$out"
            '';
    swayncClient = lib.getExe' config.services.swaync.package "swaync-client";
    popupNames = [
        "audio"
        "calendar"
        "hardware"
        "menu"
        "network"
        "profile"
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
    openBars = pkgs.writeShellApplication {
        name = "eww-open-bars";
        runtimeInputs = [
            config.programs.eww.package
            config.wayland.windowManager.hyprland.package
            pkgs.jq
        ];
        text = builtins.readFile ./scripts/open-bars.sh;
    };
    popupToggle = pkgs.writeShellApplication {
        name = "popup-toggle";
        text = popupToggleScript;
    };
    theme = config.mine.desktop.theme;
    uiPower = lib.getExe (
        builtins.head (builtins.filter (package: package.name == "ui-power") config.home.packages)
    );
    desktopTheme = builtins.head (
        builtins.filter (package: package.name == "desktop-theme") config.home.packages
    );
    metricFields = {
        usage = null;
        temp_c = null;
        load1 = null;
        frequency_mhz = null;
    };
    hardwareInitial = builtins.toJSON {
        cpu = metricFields;
        gpu = {
            index = null;
            usage = null;
            vram_used_mib = null;
            vram_total_mib = null;
            temp_c = null;
            power_w = null;
        };
        memory = {
            usage = null;
            used_gib = null;
            total_gib = null;
        };
        display = {
            name = null;
            width = null;
            height = null;
            refresh_hz = null;
            bit_depth = null;
            color_management_mode = null;
            automatic_hdr = null;
            vrr = null;
        };
        uptime_seconds = null;
    };
    # Popup widths are text measures, not fixed boxes: a column is one
    # interface font size, so a larger font widens the panel with it.
    popupWidth = columns: toString (theme.fonts.interface.size * columns);
    # Seeded per link, matching the listener: a control that has not heard from
    # the listener yet must be hidden rather than claim a link that may not
    # exist on this machine.
    networkLinkInitial = kind: {
        inherit kind;
        available = false;
        state = "unavailable";
        connected = false;
        internet = false;
        interface = "";
        name = "Unavailable";
        signal = null;
        ip = "";
        rx_bytes_per_second = 0;
        tx_bytes_per_second = 0;
    };
    networkInitial = builtins.toJSON {
        wifi = networkLinkInitial "wifi";
        ethernet = networkLinkInitial "ethernet";
        primary = networkLinkInitial "ethernet";
    };
    audioStreamInitial = {
        available = false;
        muted = false;
        volume = 0;
        description = "Unavailable";
    };
    audioInitial = builtins.toJSON {
        available = false;
        sink = audioStreamInitial;
        # The capture fields are seeded too: a control that has not heard from
        # the poll yet must not claim the microphone is in use.
        source = audioStreamInitial // {
            active = false;
            clients = [ ];
        };
    };
    hyprlandInitial = builtins.toJSON {
        workspaces = builtins.genList (index: {
            id = index + 1;
            occupied = false;
            active = false;
            urgent = false;
            group_start = false;
            group_end = false;
            classes = "empty";
        }) 9;
        title = "";
        app = "";
        address = "";
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
    menuCommand = pkgs.writeShellApplication {
        name = "eww-menu";
        runtimeInputs = [
            pkgs.btop
            config.programs.eww.package
            config.programs.ghostty.package
            pkgs.hyprland
        ];
        runtimeEnv.EWW_MENU_TERMINAL_DEFAULT = lib.getExe config.programs.ghostty.package;
        text = builtins.readFile ./scripts/menu.sh;
    };
    animationFrame = pkgs.writeShellApplication {
        name = "eww-animation-frame";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./scripts/animation-frame.sh;
    };
    bluetoothCommand = pkgs.writeShellApplication {
        name = "eww-bluetooth";
        runtimeInputs = [
            pkgs.bluez
            pkgs.coreutils
        ];
        text = builtins.readFile ./scripts/bluetooth.sh;
    };
    audioCommand = pkgs.writeShellApplication {
        name = "eww-audio";
        runtimeInputs = [
            config.programs.eww.package
            pkgs.coreutils
            pkgs.gawk
            pkgs.jq
            pkgs.pipewire
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
            pkgs.findutils
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
        animationFrame
        audioCommand
        bluetoothCommand
        hardwareStatus
        menuCommand
        networkListener
        popupToggle
    ];

    programs.eww = {
        enable = true;
        systemd.enable = true;
    };

    systemd.user.services.eww.Service = {
        ExecStartPost = lib.getExe openBars;
        Restart = "on-failure";
        RestartSec = 2;
    };

    xdg.configFile = {
        "eww/eww.yuck".source = pkgs.replaceVars ./config/eww.yuck {
            spacingSmall = toString theme.spacing.small;
        };
        "eww/eww.scss".source = ./config/eww.scss;
        "eww/icon-nudges.scss".source = iconNudges;
        "eww/popups/common.yuck".source = pkgs.replaceVars ./config/popups/common.yuck {
            popupToggle = lib.getExe popupToggle;
        };
        "eww/popups/audio.yuck".source = pkgs.replaceVars ./config/popups/audio.yuck {
            popupWidth = popupWidth 26;
            audio = lib.getExe audioCommand;
            popupTop = toString theme.spacing.small;
            spacingNormal = toString theme.spacing.normal;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/popups/calendar.yuck".source = pkgs.replaceVars ./config/popups/calendar.yuck {
            popupWidth = popupWidth 25;
            date = lib.getExe' pkgs.coreutils "date";
            popupTop = toString theme.spacing.small;
        };
        "eww/popups/hardware.yuck".source = pkgs.replaceVars ./config/popups/hardware.yuck {
            popupWidth = popupWidth 34;
            popupTop = toString theme.spacing.small;
            spacingNormal = toString theme.spacing.normal;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/popups/network.yuck".source = pkgs.replaceVars ./config/popups/network.yuck {
            popupWidth = popupWidth 28;
            popupTop = toString theme.spacing.small;
            spacingNormal = toString theme.spacing.normal;
        };
        "eww/popups/menu.yuck".source = pkgs.replaceVars ./config/popups/menu.yuck {
            popupWidth = popupWidth 25;
            menuCommand = lib.getExe menuCommand;
            popupToggle = lib.getExe popupToggle;
            popupTop = toString theme.spacing.small;
        };
        "eww/popups/profile.yuck".source = pkgs.replaceVars ./config/popups/profile.yuck {
            popupWidth = popupWidth 17;
            inherit uiPower;
            popupTop = toString theme.spacing.small;
        };
        "eww/bar.yuck".source = pkgs.replaceVars ./config/bar.yuck {
            barHeight = toString theme.bar.height;
        };
        "eww/modules/audio.yuck".source = pkgs.replaceVars ./config/modules/audio.yuck {
            inherit audioInitial;
            audio = lib.getExe audioCommand;
            popupToggle = lib.getExe popupToggle;
        };
        "eww/modules/bluetooth.yuck".source = pkgs.replaceVars ./config/modules/bluetooth.yuck {
            bluetooth = lib.getExe bluetoothCommand;
        };
        "eww/modules/clock.yuck".source = pkgs.replaceVars ./config/modules/clock.yuck {
            date = lib.getExe' pkgs.coreutils "date";
            popupToggle = lib.getExe popupToggle;
        };
        "eww/modules/hardware.yuck".source = pkgs.replaceVars ./config/modules/hardware.yuck {
            inherit hardwareInitial;
            hardwareStatus = lib.getExe hardwareStatus;
            popupToggle = lib.getExe popupToggle;
            spacingSmall = toString theme.spacing.small;
        };
        "eww/modules/network.yuck".source = pkgs.replaceVars ./config/modules/network.yuck {
            inherit networkInitial;
            animationFrame = lib.getExe animationFrame;
            networkListener = lib.getExe networkListener;
            popupToggle = lib.getExe popupToggle;
        };
        "eww/modules/menu.yuck".source = pkgs.replaceVars ./config/modules/menu.yuck {
            popupToggle = lib.getExe popupToggle;
        };
        "eww/modules/profile.yuck".source = pkgs.replaceVars ./config/modules/profile.yuck {
            popupToggle = lib.getExe popupToggle;
            username = config.home.username;
        };
        "eww/modules/notifications.yuck".source = pkgs.replaceVars ./config/modules/notifications.yuck {
            inherit swayncClient;
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
            workspaceCommand = lib.getExe workspaceCommand;
        };
        "eww/modules/window.yuck".source = ./config/modules/window.yuck;
        "eww/theme.scss".source = config.xdg.configFile."mineugene-desktop/theme/tokens.scss".source;
    };
}
