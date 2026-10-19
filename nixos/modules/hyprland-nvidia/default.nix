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
    greeterRegreetCss = pkgs.replaceVars ./greeter/regreet.css {
        inherit (colors)
            accent
            background
            border
            foreground
            surface
            ;
    };
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
        "greetd/sessions/wayland-sessions/hyprland-uwsm.desktop".text = lib.generators.toINI { } {
            "Desktop Entry" = {
                Name = "Hyprland (uwsm-managed)";
                Comment = "An intelligent dynamic tiling Wayland compositor";
                Exec = "${uwsm} start -g -1 -e -D Hyprland hyprland.desktop";
                TryExec = uwsm;
                DesktopNames = "Hyprland";
                Type = "Application";
            };
        };
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
