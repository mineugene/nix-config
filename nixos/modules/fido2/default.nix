{ pkgs, ... }:
{
    environment.systemPackages = [ pkgs.libfido2 ];
    # libfido2 puts rules under etc/ instead of lib/, so services.udev.packages
    # won't find them. Load them via extraRules instead.
    services.udev.extraRules = builtins.readFile "${pkgs.libfido2}/etc/udev/rules.d/70-u2f.rules";
}
