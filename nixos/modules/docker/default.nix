{ activeUser, pkgs, ... }:
{
    virtualisation.docker.enable = true;
    # docker_28 (the upstream default) is unmaintained since Nov 2025 and
    # flagged insecure by nixpkgs; pin the current maintained release.
    virtualisation.docker.package = pkgs.docker_29;

    # Docker owns its transient veth interfaces. Letting dhcpcd configure them
    # causes address churn and can crash dhcpcd while containers restart.
    networking.dhcpcd.denyInterfaces = [ "veth*" ];

    # Add the active user to the docker group so they can use docker without sudo
    users.users.${activeUser}.extraGroups = [ "docker" ];
}
