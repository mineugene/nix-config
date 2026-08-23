{ lib, pkgs, ... }:
{
    # yubikey-personalization's udev rules use this as a fallback alongside
    # seat-based uaccess. Define it so udev can load those rules cleanly.
    users.groups.plugdev = { };

    services.pcscd.enable = true;
    services.udev.packages = [ pkgs.yubikey-personalization ];
    hardware.gpgSmartcards.enable = true;

    environment.systemPackages = [
        # Expose libpcsclite.so so scdaemon can find the pcsc-driver
        pkgs.pcsclite.lib

        # ykman for managing OpenPGP touch policy, FIDO2 creds, etc.
        pkgs.yubikey-manager
    ];

    programs.yubikey-touch-detector = {
        enable = true;
        # Disable built-in libnotify; the home-manager yubikey-touch-notify
        # module drives dunst (countdown, cancel, tmux/starship state file).
        libnotify = false;
        # Debug logging: records each assuan LEARN probe in the journal, so a
        # missed touch notification can be correlated with gpg-agent activity
        # after the fact (the probe race is timing-dependent, no local repro).
        verbose = true;
    };
    systemd.user.services.yubikey-touch-detector = {
        description = "Watch for pending YubiKey touch and expose events via unix socket";
        # Point at the XDG-located GNUPGHOME so the detector can find gpg-agent;
        # %h is expanded by systemd to the user's home directory.
        environment.GNUPGHOME = "%h/.local/share/gnupg";
        # default.target instead of graphical-session.target so the unit
        # autostarts on hosts without a graphical session (e.g. WSL).
        wantedBy = lib.mkForce [ "default.target" ];
        partOf = lib.mkForce [ ];
    };
}
