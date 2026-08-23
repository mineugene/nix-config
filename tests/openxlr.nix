{
    pkgs,
    nixosSystem,
    openxlrModule,
}:
let
    system = nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
            openxlrModule
            {
                system.stateVersion = "25.11";
            }
        ];
    };
    cfg = system.config;
    daemon = cfg.systemd.user.services.openxlr-daemon;
in
assert cfg.security.rtkit.enable;
assert cfg.services.pipewire.enable;
assert cfg.services.pipewire.alsa.enable;
assert cfg.services.pipewire.alsa.support32Bit;
assert cfg.services.pipewire.pulse.enable;
assert cfg.services.pipewire.wireplumber.enable;
assert cfg.services.openxlr.enable;
assert daemon.serviceConfig.ExecStart == "${cfg.services.openxlr.package}/bin/openxlr-daemon";
assert daemon.environment.OPENXLR_BUILD_MIXER == "1";
pkgs.runCommandLocal "openxlr-check" { } ''
    touch "$out"
''
