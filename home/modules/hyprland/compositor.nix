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
        eww_audio = lib.getExe (homePackage "eww-audio");
        monitor_topology = lib.getExe monitorTopology;
        wl_copy = lib.getExe' pkgs.wl-clipboard "wl-copy";
        grim = lib.getExe pkgs.grim;
        slurp = lib.getExe pkgs.slurp;
        wpctl = lib.getExe' pkgs.wireplumber "wpctl";
    };
    theme = config.mine.desktop.theme;
    themeColors = theme.colors.${theme.defaultMode};
    desktopBackground = "#000000";
    display = config.mine.desktop.display;
    monitorRule =
        m:
        let
            mode = "${toString m.width}x${toString m.height}@${builtins.toJSON m.refreshHz}";
        in
        "  {\n"
        + "    output = ${builtins.toJSON m.output},\n"
        + "    mode = ${builtins.toJSON mode},\n"
        + "    scale = ${builtins.toJSON m.scale},\n"
        + "    bitdepth = 10,\n"
        + "    cm = ${builtins.toJSON m.cm},\n"
        + lib.optionalString (
            m.sdrBrightness != null
        ) "    sdrbrightness = ${builtins.toJSON m.sdrBrightness},\n"
        + lib.optionalString (
            m.sdrSaturation != null
        ) "    sdrsaturation = ${builtins.toJSON m.sdrSaturation},\n"
        + lib.optionalString (
            m.sdrMinLuminance != null
        ) "    sdr_min_luminance = ${builtins.toJSON m.sdrMinLuminance},\n"
        + lib.optionalString (
            m.sdrMaxLuminance != null
        ) "    sdr_max_luminance = ${builtins.toJSON m.sdrMaxLuminance},\n"
        + "  }";
    monitorLua =
        if display.monitors == [ ] then
            "return nil\n"
        else
            "return {\n${lib.concatStringsSep ",\n" (map monitorRule display.monitors)}\n}";
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
    options.mine.desktop.display.monitors = lib.mkOption {
        type = lib.types.listOf (
            lib.types.submodule {
                options = {
                    output = lib.mkOption {
                        type = lib.types.str;
                        description = "Verified Hyprland output name.";
                    };
                    width = lib.mkOption {
                        type = lib.types.ints.positive;
                        description = "Native width of the verified display.";
                    };
                    height = lib.mkOption {
                        type = lib.types.ints.positive;
                        description = "Native height of the verified display.";
                    };
                    refreshHz = lib.mkOption {
                        type = lib.types.number;
                        description = "Existing refresh rate of the verified display.";
                    };
                    scale = lib.mkOption {
                        type = lib.types.number;
                        description = "Existing scale of the verified display.";
                    };
                    cm = lib.mkOption {
                        type = lib.types.enum [
                            "auto"
                            "srgb"
                            "wide"
                            "hdredid"
                            "hdr"
                        ];
                        default = "auto";
                        description = ''
                            Color management preset for this display. The
                            default `auto` keeps a wide-gamut SDR desktop
                            and lets `render.cm_auto_hdr` switch to HDR only
                            for fullscreen HDR surfaces. Set `hdr` only after
                            validating capture workflows; it makes the whole
                            desktop HDR and tone-maps SDR content.
                        '';
                    };
                    sdrBrightness = lib.mkOption {
                        type = lib.types.nullOr lib.types.number;
                        default = null;
                        description = ''
                            Brightness multiplier for SDR content while the
                            display runs the `hdr` preset. Null keeps
                            Hyprland's default of 1.
                        '';
                    };
                    sdrSaturation = lib.mkOption {
                        type = lib.types.nullOr lib.types.number;
                        default = null;
                        description = ''
                            Saturation multiplier for SDR content while the
                            display runs the `hdr` preset. Null keeps
                            Hyprland's default of 1.
                        '';
                    };
                    sdrMinLuminance = lib.mkOption {
                        type = lib.types.nullOr lib.types.number;
                        default = null;
                        description = ''
                            Assumed black luminance in nits for SDR content
                            while the display runs the `hdr` preset. Null
                            keeps Hyprland's default of 0.2.
                        '';
                    };
                    sdrMaxLuminance = lib.mkOption {
                        type = lib.types.nullOr lib.types.number;
                        default = null;
                        description = ''
                            Assumed reference-white luminance in nits for SDR
                            content while the display runs the `hdr` preset.
                            Null keeps Hyprland's default of 80. The default
                            is dim on bright HDR panels; 200-250 approximates
                            paper white.
                        '';
                    };
                };
            }
        );
        default = [ ];
        description = ''
            Hardware-verified monitor rules for 10-bit automatic color
            management, one entry per display. Positions are not declared
            here; monitor-topology.service restores the remembered
            arrangement.
        '';
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
                      eww_audio = ${builtins.toJSON programs.eww_audio},
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
                    background_color = toRgba desktopBackground "ff";
                    disable_hyprland_logo = true;
                    disable_splash_rendering = true;
                    force_default_wallpaper = 0;
                    key_press_enables_dpms = true;
                    mouse_move_enables_dpms = true;
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
