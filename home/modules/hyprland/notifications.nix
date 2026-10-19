{ lib, ... }:
{
    services = {
        cliphist.enable = true;
        dunst.enable = lib.mkForce false;
        polkit-gnome.enable = true;
    };
}
