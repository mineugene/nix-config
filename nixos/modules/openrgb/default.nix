# Headless OpenRGB lighting control.
#
# The server has no display and no desktop session, so nothing ever drives
# RGB lighting; controllers power on in whatever stored pattern they shipped
# with. This module installs OpenRGB, makes the SMBus visible so motherboard
# and RAM controllers are detected (USB controllers need no extra setup), and
# runs a boot-time oneshot that blanks every detected device.
{ pkgs, ... }:
{
    # Exposes /dev/i2c-* (loads i2c-dev) and lays down udev rules so OpenRGB
    # can reach SMBus RGB controllers. The chipset SMBus driver (i2c-i801 on
    # Intel, i2c-piix4 on AMD) autoloads on its own.
    hardware.i2c.enable = true;

    # The SMBus is normally claimed by the ACPI driver, which blocks OpenRGB
    # from probing motherboard/RAM RGB over i2c. "lax" relaxes the resource
    # check enough to allow access while keeping the conflict warnings.
    #
    # Tradeoff: the SMBus is then shared with whatever ACPI uses it for (some
    # boards read fan/thermal sensors there). On a headless box this is low
    # risk, but drop this param if sensor readings misbehave -- USB RGB will
    # still be blanked; only SMBus board/RAM RGB needs it.
    boot.kernelParams = [ "acpi_enforce_resources=lax" ];

    environment.systemPackages = [ pkgs.openrgb ];

    # OpenRGB's packaged udev rules grant its USB/HID and i2c nodes to the
    # local user, handy for manual `openrgb` debugging (the oneshot below runs
    # as root and does not depend on them).
    services.udev.packages = [ pkgs.openrgb ];

    # Blank all RGB once at boot, then exit. systemd-udev-settle gives USB HID
    # and i2c controllers time to enumerate first; it is deprecated in general
    # but pragmatic here, where the whole job is a one-time hardware probe.
    systemd.services.openrgb-off = {
        description = "Blank all detected RGB lighting (headless)";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-udev-settle.service" ];
        wants = [ "systemd-udev-settle.service" ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # --noautoconnect operates on the hardware directly instead of
            #   reaching for a running OpenRGB server (there is none).
            # Two passes cover both controller families: "Direct" drives LEDs
            #   live, "Static" writes black to device flash so it sticks after
            #   OpenRGB exits. The "-" prefix ignores the failure a device
            #   raises for a mode it does not implement, so the other pass (and
            #   the rest of the devices) still run.
            ExecStart = [
                "-${pkgs.openrgb}/bin/openrgb --noautoconnect --mode direct --color 000000"
                "-${pkgs.openrgb}/bin/openrgb --noautoconnect --mode static --color 000000"
            ];
        };
    };
}
