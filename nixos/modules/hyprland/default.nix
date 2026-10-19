# Hyprland session for hosts whose GPU driver comes from the kernel, such as
# an AMD APU. Hosts that need a vendor driver module import this and add it.
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

    services.xserver.enable = false;

    security = {
        pam.services.shell-lock = { };
        rtkit.enable = true;
    };
}
