{ lib, pkgs, ... }:
let
    rofi = pkgs.rofi.override {
        rofi-unwrapped = pkgs.rofi-unwrapped.override { x11Support = false; };
    };
in
{
    programs.rofi = {
        enable = true;
        package = rofi;
        settings.terminal = lib.getExe pkgs.ghostty;
    };
}
