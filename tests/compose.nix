{
    composeModule,
    nixosSystem,
    pkgs,
}:
let
    system = nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
            composeModule
            {
                virtualisation.docker.enable = true;
                services.composeStacks = {
                    alpha = {
                        composeFileContent = "services: {}";
                        extraFiles."nested/config.txt" = "value\n";
                    };
                    beta = {
                        composeFileContent = "services: {}";
                        dependsOn = [ "alpha" ];
                    };
                };
                system.stateVersion = "25.11";
            }
        ];
    };
    cfg = system.config;
    extraFileCommands = cfg.systemd.services.compose-alpha.serviceConfig.ExecStartPre;
    updateService = cfg.systemd.services.compose-update;
    updateCommand = builtins.head updateService.serviceConfig.ExecStart;
in
assert builtins.length extraFileCommands == 2;
assert builtins.any (pkgs.lib.hasInfix "/bin/mkdir ") extraFileCommands;
assert builtins.any (pkgs.lib.hasInfix "/bin/cp ") extraFileCommands;
assert builtins.elem pkgs.systemd updateService.path;
assert pkgs.lib.hasInfix
    "/bin/compose-update-all compose-alpha-update.service compose-beta-update.service"
    updateCommand;
pkgs.runCommandLocal "compose-check"
    {
        nativeBuildInputs = [
            pkgs.coreutils
            pkgs.dash
        ];
        testScript = ./scripts/compose-update-all.sh;
        updateAll = builtins.head (pkgs.lib.splitString " " updateCommand);
    }
    ''
        set -eu

        dash "$testScript" "$updateAll" "$TMPDIR/compose"
        touch "$out"
    ''
