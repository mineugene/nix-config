{
    config,
    lib,
    pkgs,
    ...
}:
let
    brave = pkgs.brave.override { commandLineArgs = "--ozone-platform=wayland"; };
    monitorTopology = pkgs.writeShellApplication {
        name = "monitor-topology";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.hyprland
            pkgs.jq
        ];
        text = builtins.readFile ./scripts/monitor-topology.sh;
    };
    homePackage =
        name: builtins.head (builtins.filter (package: package.name == name) config.home.packages);
    programs = {
        terminal = lib.getExe config.programs.ghostty.package;
        browser = lib.getExe brave;
        lock = lib.getExe config.programs.hyprlock.package;
        ui_launcher = lib.getExe (homePackage "ui-launcher");
        ui_clipboard = lib.getExe (homePackage "ui-clipboard");
        ui_power = lib.getExe (homePackage "ui-power");
        monitor_topology = lib.getExe monitorTopology;
        wl_copy = lib.getExe' pkgs.wl-clipboard "wl-copy";
        grim = lib.getExe pkgs.grim;
        slurp = lib.getExe pkgs.slurp;
        wpctl = lib.getExe' pkgs.wireplumber "wpctl";
    };
    theme = config.mine.desktop.theme;
    themeColors = theme.colors.${theme.defaultMode};
    display = config.mine.desktop.display;
    monitorLua =
        if display.hdrMonitor == null then
            "return nil\n"
        else
            let
                mode = "${toString display.hdrMonitor.width}x${toString display.hdrMonitor.height}@${builtins.toJSON display.hdrMonitor.refreshHz}";
            in
            ''
                return {
                  output = ${builtins.toJSON display.hdrMonitor.output},
                  mode = ${builtins.toJSON mode},
                  scale = ${builtins.toJSON display.hdrMonitor.scale},
                  bitdepth = 10,
                  cm = "auto",
                }
            '';
    pointerCursor = config.home.pointerCursor;
    toRgba = color: alpha: "rgba(${lib.removePrefix "#" color}${alpha})";
    blurLayer = name: namespace: {
        inherit name;
        match.namespace = namespace;
        blur = true;
        ignore_alpha = 0.2;
        no_anim = true;
    };
in
{
    options.mine.desktop.display.hdrMonitor = lib.mkOption {
        type = lib.types.nullOr (
            lib.types.submodule {
                options = {
                    output = lib.mkOption {
                        type = lib.types.str;
                        description = "Verified Hyprland output name for the HDR display.";
                    };
                    width = lib.mkOption {
                        type = lib.types.ints.positive;
                        description = "Native width of the verified HDR display.";
                    };
                    height = lib.mkOption {
                        type = lib.types.ints.positive;
                        description = "Native height of the verified HDR display.";
                    };
                    refreshHz = lib.mkOption {
                        type = lib.types.number;
                        description = "Existing refresh rate of the verified HDR display.";
                    };
                    scale = lib.mkOption {
                        type = lib.types.number;
                        description = "Existing scale of the verified HDR display.";
                    };
                };
            }
        );
        default = null;
        description = "Hardware-verified monitor policy for 10-bit automatic HDR.";
    };

    config.home.packages = [ monitorTopology ];

    config.systemd.user.services.monitor-topology = {
        Unit = {
            Description = "Remember and restore Hyprland monitor topologies";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
        };
        Service = {
            ExecStart = "${lib.getExe monitorTopology} watch";
            Restart = "on-failure";
            RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
    };

    config.wayland.windowManager.hyprland = {
        configType = "lua";
        enable = true;
        package = null;
        portalPackage = null;
        systemd.enable = false;
        xwayland.enable = false;
        extraLuaFiles = {
            bindings = ./lua/bindings.lua;
            monitors = ./lua/monitors.lua;
            "generated.monitor" = {
                autoLoad = false;
                content = monitorLua;
            };
            "generated.programs" = {
                autoLoad = false;
                content = ''
                    return {
                      terminal = ${builtins.toJSON programs.terminal},
                      browser = ${builtins.toJSON programs.browser},
                      lock = ${builtins.toJSON programs.lock},
                      ui_launcher = ${builtins.toJSON programs.ui_launcher},
                      ui_clipboard = ${builtins.toJSON programs.ui_clipboard},
                      ui_power = ${builtins.toJSON programs.ui_power},
                      monitor_topology = ${builtins.toJSON programs.monitor_topology},
                      wl_copy = ${builtins.toJSON programs.wl_copy},
                      grim = ${builtins.toJSON programs.grim},
                      slurp = ${builtins.toJSON programs.slurp},
                      wpctl = ${builtins.toJSON programs.wpctl},
                    }
                '';
            };
        };
        settings = {
            config = {
                general = {
                    gaps_in = theme.spacing.small;
                    gaps_out = theme.bar.outerMargin;
                    border_size = theme.border.width;
                    col = {
                        active_border = toRgba themeColors.accent "cc";
                        inactive_border = toRgba themeColors.border "cc";
                    };
                };
                decoration = {
                    rounding = theme.radius.card;
                    shadow.enabled = false;
                    blur = {
                        enabled = true;
                        passes = 2;
                        size = theme.radius.card;
                    };
                };
                render.cm_auto_hdr = 1;
                input = {
                    accel_profile = "flat";
                    sensitivity = -0.25;
                };
                misc = {
                    background_color = toRgba themeColors.background "ff";
                    disable_hyprland_logo = true;
                    disable_splash_rendering = true;
                    force_default_wallpaper = 0;
                };
                animations.enabled = true;
            };
            curve = {
                _args = [
                    "swift"
                    {
                        type = "spring";
                        mass = 1;
                        stiffness = 600;
                        dampening = 50;
                    }
                ];
            };
            animation = [
                {
                    leaf = "global";
                    enabled = true;
                    speed = 3;
                    bezier = "default";
                }
                {
                    leaf = "windows";
                    enabled = true;
                    speed = 2.5;
                    spring = "swift";
                }
                {
                    leaf = "windowsIn";
                    enabled = true;
                    speed = 2.2;
                    spring = "swift";
                    style = "popin 96%";
                }
                {
                    leaf = "windowsOut";
                    enabled = true;
                    speed = 1.4;
                    bezier = "default";
                    style = "popin 96%";
                }
                {
                    leaf = "workspaces";
                    enabled = true;
                    speed = 2;
                    bezier = "default";
                }
            ];
            workspace_rule = {
                workspace = "w[tv1]";
                gaps_in = 0;
                gaps_out = 0;
            };
            layer_rule = [
                (blurLayer "rofi-blur" "rofi")
                (blurLayer "swaync-notification-blur" "swaync-notification-window")
                (blurLayer "swaync-control-center-blur" "swaync-control-center")
            ];
            window_rule = {
                name = "single-window-no-gaps";
                match = {
                    float = false;
                    workspace = "w[tv1]";
                };
                border_size = 0;
                rounding = 0;
            };
            env = [
                {
                    _args = [
                        "XCURSOR_SIZE"
                        (toString pointerCursor.size)
                    ];
                }
                {
                    _args = [
                        "XCURSOR_THEME"
                        pointerCursor.name
                    ];
                }
            ];
        };
    };
}
