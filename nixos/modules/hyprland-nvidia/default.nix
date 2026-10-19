{ ... }:
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
        pam.services.shell-lock = { };
        rtkit.enable = true;
    };
}
