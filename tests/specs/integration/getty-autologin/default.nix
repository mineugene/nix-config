{
    pkgs,
    nixosSystem,
    gettyAutologinModule,
    loginGuard,
}:
let
    system = nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
            gettyAutologinModule
            {
                system.stateVersion = "25.11";
                mine.autologin.user = "autologin-check";
            }
        ];
    };
in
pkgs.runCommandLocal "getty-autologin-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.gnugrep
    ];
    unitFile =
        pkgs.writeText "getty-tty1.service"
            system.config.systemd.units."getty@tty1.service".text;
    loginGuardFile = pkgs.writeText "zlogin" loginGuard;
} (builtins.readFile ./getty-autologin.sh)
