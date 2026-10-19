{
    security.rtkit.enable = true;

    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
    };

    services.openxlr.enable = true;

    services.pipewire.wireplumber.extraConfig."90-openxlr-capture-routing" = {
        "stream.rules" = [
            {
                matches = [ { "media.class" = "Stream/Input/Audio"; } ];
                actions."update-props" = {
                    "node.dont-fallback" = true;
                    "node.linger" = true;
                };
            }
        ];
        "wireplumber.components" = [
            {
                name = "${./restore-capture-target.lua}";
                type = "script/lua";
            }
        ];
    };

    # WirePlumber runs USB control transfers on its main thread and cannot act
    # on SIGTERM until they return, so a wedged device costs the full default
    # 90 s stop timeout on every restart.
    systemd.user.services.wireplumber.serviceConfig.TimeoutStopSec = "20s";
}
