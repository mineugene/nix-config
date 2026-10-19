{
    config,
    lib,
    pkgs,
    ...
}:
let
    monitorTopology = import ./monitor-topology.nix { inherit pkgs; };
    homePackage =
        name: builtins.head (builtins.filter (package: lib.getName package == name) config.home.packages);
    reloadHyprland = pkgs.writeShellApplication {
        name = "reload-hyprland";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.hyprland
            pkgs.jq
        ];
        text = builtins.readFile ./scripts/reload-hyprland.sh;
    };
    programs = {
        terminal = lib.getExe config.programs.ghostty.package;
        browser = lib.getExe (homePackage "chromium");
        lock = lib.getExe (homePackage "shell-lock");
        ui_launcher = lib.getExe (homePackage "ui-launcher");
        ui_clipboard = lib.getExe (homePackage "ui-clipboard");
        ui_power = lib.getExe (homePackage "ui-power");
        shell_audio = lib.getExe (homePackage "shell-audio");
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
    # The SDR-in-HDR knobs are emitted only when set.
    monitorRule =
        m:
        lib.filterAttrs (_: value: value != null) {
            inherit (m) output scale cm;
            mode = "${toString m.width}x${toString m.height}@${builtins.toJSON m.refreshHz}";
            bitdepth = 10;
            sdrsaturation = m.sdrSaturation;
            sdr_min_luminance = m.sdrMinLuminance;
            sdr_max_luminance = m.sdrMaxLuminance;
        };
    luaData =
        value:
        builtins.replaceStrings [ "@value@" ] [ (lib.generators.toLua { } value) ] (
            builtins.readFile ./lua/data.lua.in
        );
    monitorLua = luaData (if display.monitors == [ ] then null else map monitorRule display.monitors);
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

    options.mine.desktop.hyprland.reloadOnActivation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
            Reload the running compositor after Home Manager activation when
            the generated Hyprland configuration changes. Off by default: a
            reload re-applies the remembered monitor layout, which moves the
            pointer to the primary monitor.
        '';
    };

    config.home.activation.reloadHyprland = lib.mkIf config.mine.desktop.hyprland.reloadOnActivation (
        lib.hm.dag.entryAfter [ "linkGeneration" ] "run ${lib.getExe reloadHyprland}"
    );

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
                content = luaData programs;
            };
        };
        settings = {
            config = {
                general = {
                    # Hyprland insets gaps_in against every facing edge, so the
                    # gap between two windows is twice its value; half of gaps_out
                    # makes inner and outer gaps render the same width. The bar
                    # reserves the top gap itself, so the top outer gap is zero.
                    gaps_in = theme.bar.outerMargin / 2;
                    gaps_out = {
                        top = 0;
                        right = theme.bar.outerMargin;
                        bottom = theme.bar.outerMargin;
                        left = theme.bar.outerMargin;
                    };
                    border_size = theme.border.width;
                    col = {
                        active_border = toRgba themeColors.accent "cc";
                        inactive_border = toRgba themeColors.border "cc";
                    };
                };
                decoration = {
                    rounding = theme.radius.general;
                    rounding_power = theme.cornerRoundingPower;
                    shadow.enabled = false;
                    blur = {
                        enabled = true;
                        passes = 2;
                        size = 6;
                    };
                };
                render.cm_auto_hdr = 1;
                input = {
                    accel_profile = "flat";
                    sensitivity = -0.25;
                    follow_mouse = 0;
                };
                cursor.hide_on_key_press = true;
                ecosystem = {
                    no_donation_nag = true;
                    no_update_news = true;
                };
                misc = {
                    background_color = toRgba desktopBackground "ff";
                    disable_hyprland_logo = true;
                    disable_splash_rendering = true;
                    force_default_wallpaper = 0;
                    key_press_enables_dpms = true;
                    mouse_move_enables_dpms = true;
                    # A lock client that dies without unlocking leaves Hyprland
                    # holding the lock, which denies every later lock client.
                    allow_session_lock_restore = true;
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
                        damping = 50;
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
                # Shell popups are layer surfaces. Only their alpha should
                # animate: a popup settles its height just after it maps, and
                # an animated resize reads as a scale. Keeping the size and
                # position nodes disabled makes that settle instant, and the
                # fade nodes carry the shared motion token, one speed unit per
                # 100ms.
                {
                    leaf = "layersIn";
                    enabled = false;
                }
                {
                    leaf = "layersOut";
                    enabled = false;
                }
                {
                    leaf = "fadeLayersIn";
                    enabled = true;
                    speed = theme.animation.normal / 100;
                    bezier = "default";
                }
                {
                    leaf = "fadeLayersOut";
                    enabled = true;
                    speed = theme.animation.normal / 100;
                    bezier = "default";
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
                # The bar reserves the top gap, so the single window is flush
                # with every screen edge.
                gaps_out = 0;
            };
            layer_rule = [
                (blurLayer "rofi-blur" "rofi")
            ];
            window_rule = {
                name = "single-window";
                match = {
                    float = false;
                    workspace = "w[tv1]";
                };
                # A single tiled window sits flush with the screen edges, so its
                # ring is the only cue for which window has focus. Keep the border
                # and dim it: a bright edge risks burn-in on an OLED panel, while
                # removing it loses the cue. The alpha keeps the ring near 15%
                # luminance over the background.
                border_size = theme.border.width;
                border_color = "${toRgba themeColors.accent "59"} ${toRgba themeColors.border "59"}";
                rounding = theme.radius.general;
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
