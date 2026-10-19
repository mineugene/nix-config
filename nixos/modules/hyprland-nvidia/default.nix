{
    imports = [ ../hyprland ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
        modesetting.enable = true;
        nvidiaSettings = false;
        open = true;
        powerManagement.enable = true;
    };
}
