{ lib, pkgs, ... }:
let
    hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
in
{
    services.hypridle = {
        enable = true;
        settings = {
            general.ignore_dbus_inhibit = false;
            listener = [
                {
                    timeout = 600;
                    on-timeout = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
                    on-resume = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
                }
            ];
        };
    };
}
