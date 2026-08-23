{
    config,
    lib,
    pkgs,
    ...
}:
let
    regreetPackage = config.services.displayManager.regreet.package;
    uwsm = lib.getExe pkgs.uwsm;
    mkPosixScript = import ../../../lib/scripts.nix { inherit pkgs; };
    date = lib.getExe' pkgs.coreutils "date";
    fastfetch = lib.getExe pkgs.fastfetch;
    colors = (import ../../../home/modules/hyprland/theme/palette.nix).dark;
    greeterEwwYuck = pkgs.replaceVars ./greeter/eww.yuck { inherit date fastfetch; };
    greeterEwwScss = pkgs.replaceVars ./greeter/eww.scss {
        inherit (colors)
            border
            foreground
            surface
            ;
    };
    greeterRegreetCss = ''
        * {
            font-size: 13px;
        }

        window {
            background-color: ${colors.background};
            color: ${colors.foreground};
        }

        overlay > frame.background:nth-child(2) {
            background-color: ${colors.surface};
            border: 1px solid ${colors.border};
            border-radius: 6px;
        }

        overlay > frame.background:nth-child(3) {
            opacity: 0;
        }

        button {
            border-radius: 4px;
        }

        button.suggested-action {
            background-color: ${colors.accent};
            color: ${colors.background};
        }
    '';
    greeterSession = mkPosixScript {
        name = "greeter-session";
        src = ./scripts/greeter-session.sh;
    };
    startGreeter = mkPosixScript {
        name = "start-greeter";
        src = ./scripts/start-greeter.sh;
    };
in
{
    programs.hyprland = {
        enable = true;
        withUWSM = true;
        xwayland.enable = false;
    };

    # The NixOS Hyprland module installs both XDPH and the GTK fallback portal.
    xdg.portal.config.hyprland.default = [
        "hyprland"
        "gtk"
    ];

    environment.etc = {
        "greetd/eww/eww.scss".source = greeterEwwScss;
        "greetd/eww/eww.yuck".source = greeterEwwYuck;
        "greetd/greeter-session".source = lib.getExe greeterSession;
        "greetd/wayfire.ini".source = ./greeter/wayfire.ini;
        "greetd/sessions/wayland-sessions/hyprland-uwsm.desktop".text = ''
            [Desktop Entry]
            Name=Hyprland (uwsm-managed)
            Comment=An intelligent dynamic tiling Wayland compositor
            Exec=${uwsm} start -g -1 -e -D Hyprland hyprland.desktop
            TryExec=${uwsm}
            DesktopNames=Hyprland
            Type=Application
        '';
    };

    services.displayManager.regreet = {
        enable = true;
        cursorTheme = {
            package = pkgs.capitaine-cursors;
            name = "capitaine-cursors-white";
        };
        extraCss = greeterRegreetCss;
        font.size = 13;
        settings = {
            GTK.application_prefer_dark_theme = true;
            widget.clock = {
                format = "";
                label_width = 0;
            };
        };
    };

    services.greetd = {
        enable = true;
        useTextGreeter = false;
        settings.default_session.command = lib.getExe startGreeter;
    };

    environment.systemPackages = [
        pkgs.eww
        pkgs.wayfire
        pkgs.wlr-randr
        regreetPackage
    ];

    systemd.services.greetd.path = [
        pkgs.coreutils
        pkgs.dbus
        pkgs.eww
        pkgs.gawk
        pkgs.wayfire
        pkgs.wlr-randr
        regreetPackage
        greeterSession
    ];

    services.xserver = {
        enable = false;
        videoDrivers = [ "nvidia" ];
    };

    hardware.nvidia = {
        modesetting.enable = true;
        nvidiaSettings = false;
        open = true;
        powerManagement.enable = true;
    };

    security = {
        pam.services.hyprlock = { };
        rtkit.enable = true;
    };
}
