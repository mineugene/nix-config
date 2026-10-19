{ lib, config, ... }:
{
    # iwd owns Wi-Fi association, systemd-networkd owns link addressing, and
    # systemd-resolved owns name resolution. NetworkManager is deliberately
    # absent so nothing else arbitrates the same links.
    networking = {
        networkmanager.enable = lib.mkDefault false;
        useNetworkd = true;
        useDHCP = true;
        wireless.iwd.enable = true;
    };

    # systemd-resolved owns resolution and cannot run alongside a host-provided
    # resolv.conf, so it stays off wherever the host's file is used instead.
    services.resolved.enable = !config.networking.useHostResolvConf;

    # The desktop bar runs privileged iwd actions (radio, connect, forget)
    # through pkexec, which needs a setuid binary; NixOS only installs one when
    # the wrapper is enabled. Hosts that would rather run iwd unprivileged can
    # override this, since iwd's D-Bus policy already authorizes wheel.
    security.polkit.enablePkexecWrapper = lib.mkDefault true;
}
