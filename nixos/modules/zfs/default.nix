# Shared ZFS + ZRAM + NVMe configuration for NixOS workstation hosts.
#
# Dataset properties (compression=lz4, encryption, atime, xattr, acltype)
# are set at pool creation time -- see the provisioning notes in each host's
# configuration file.
{ pkgs, ... }:
{
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs = {
        forceImportRoot = false;
        package = pkgs.zfs_unstable;
        # Keep the console passphrase prompt as a fallback for encrypted pools
        # normally unlocked through NBDE. This is inert on hosts whose pools
        # have no keylocation=prompt dataset.
        requestEncryptionCredentials = true;
    };
    # Default linuxPackages (LTS) is always ZFS-compatible. Pin explicitly
    # (e.g. pkgs.linuxPackages_6_12) only if a non-LTS kernel is needed.

    services.zfs = {
        trim.enable = true;
        autoScrub.enable = true;
        autoSnapshot = {
            enable = true;
            frequent = 4;
            hourly = 24;
            daily = 7;
            weekly = 4;
            monthly = 12;
        };
    };

    # ZRAM compressed swap (first swap tier, backed by RAM).
    zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
    };

    boot.kernel.sysctl = {
        # With ZRAM, higher swappiness tells the kernel to prefer compressed
        # RAM over dropping file caches (kernel 5.8+ range: 0-200).
        "vm.swappiness" = 180;
        # ZFS manages its own cache (ARC), so reduce pressure to reclaim VFS
        # dentries/inodes.
        "vm.vfs_cache_pressure" = 50;
    };
}
