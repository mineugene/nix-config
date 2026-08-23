{
    config,
    lib,
    pkgs,
    ...
}:
let
    cfg = config.services.composeStacks;
    mkPosixScript = import ../../../lib/scripts.nix { inherit pkgs; };
    composeUpdateAll = mkPosixScript {
        name = "compose-update-all";
        src = ./scripts/update-all.sh;
    };
    stackType = lib.types.submodule {
        options = {
            composeFileContent = lib.mkOption {
                type = lib.types.str;
                description = "The full content of the docker-compose.yaml file.";
            };

            envFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                    Path to an environment file on the target system.
                    Use for secrets that should not be in the nix store.
                '';
            };

            extraFiles = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = ''
                    Additional files to place in the working directory.
                    Keys are relative paths, values are file contents.
                '';
            };

            dependsOn = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                    Names of other compose stacks this stack depends on.
                    The resulting systemd unit will be ordered after and
                    require the corresponding compose-<name>.service units.
                    Use this when a stack references resources (e.g. external
                    networks) created by another stack.
                '';
            };

        };
    };

    mkExtraFileCommands =
        workingDir: extraFiles:
        lib.concatLists (
            lib.mapAttrsToList (
                path: content:
                let
                    storePath = pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] path) content;
                    targetPath = "${workingDir}/${path}";
                    targetDir = builtins.dirOf targetPath;
                in
                [
                    "+${lib.getExe' pkgs.coreutils "mkdir"} -p -- ${lib.escapeShellArg targetDir}"
                    "+${lib.getExe' pkgs.coreutils "cp"} --remove-destination -- ${lib.escapeShellArg storePath} ${lib.escapeShellArg targetPath}"
                ]
            ) extraFiles
        );

    mkStackPaths =
        name: stackCfg:
        let
            baseFile = pkgs.writeText "docker-compose-${name}.yaml" stackCfg.composeFileContent;
        in
        {
            composeArgs = " -f ${baseFile}";
            workingDir = "/var/lib/compose/${name}";
            dockerCompose = lib.getExe' pkgs.docker-compose "docker-compose";
        };

    envFileAttrs =
        stackCfg:
        lib.optionalAttrs (stackCfg.envFile != null) {
            EnvironmentFile = stackCfg.envFile;
        };

    mkComposeService =
        name: stackCfg:
        let
            paths = mkStackPaths name stackCfg;
            depUnits = map (dep: "compose-${dep}.service") stackCfg.dependsOn;
        in
        {
            description = "Docker Compose stack: ${name}";
            after = [
                "docker.service"
                "network-online.target"
            ]
            ++ depUnits;
            requires = [ "docker.service" ] ++ depUnits;
            partOf = [ "docker.service" ];
            wants = [ "network-online.target" ];
            wantedBy = [
                "docker.service"
                "multi-user.target"
            ];

            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                StateDirectory = "compose/${name}";
                WorkingDirectory = paths.workingDir;
                ExecStart = "${paths.dockerCompose} --project-directory ${paths.workingDir}${paths.composeArgs} up -d --remove-orphans";
                ExecStop = "${paths.dockerCompose} --project-directory ${paths.workingDir}${paths.composeArgs} down";
                ExecReload = "${paths.dockerCompose} --project-directory ${paths.workingDir}${paths.composeArgs} up -d --remove-orphans";
            }
            // envFileAttrs stackCfg;
        };

    mkUpdateService =
        name: stackCfg:
        let
            paths = mkStackPaths name stackCfg;
        in
        {
            description = "Pull + recreate Docker Compose stack: ${name}";
            after = [
                "docker.service"
                "network-online.target"
                "compose-${name}.service"
            ];
            requires = [ "docker.service" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
                Type = "oneshot";
                WorkingDirectory = paths.workingDir;
                ExecStart = [
                    "${paths.dockerCompose} --project-directory ${paths.workingDir}${paths.composeArgs} pull"
                    "${paths.dockerCompose} --project-directory ${paths.workingDir}${paths.composeArgs} up -d --remove-orphans"
                ];
            }
            // envFileAttrs stackCfg;
        };
in
{
    options.services.composeStacks = lib.mkOption {
        type = lib.types.attrsOf stackType;
        default = { };
        description = "Docker Compose stacks managed as systemd services.";
    };

    config = lib.mkIf (cfg != { }) {
        assertions = [
            {
                assertion = config.virtualisation.docker.enable;
                message = "services.composeStacks requires virtualisation.docker.enable = true";
            }
        ];

        systemd.services =
            (lib.mapAttrs' (
                name: stackCfg:
                let
                    service = mkComposeService name stackCfg;
                    extraFileServices = mkExtraFileCommands "/var/lib/compose/${name}" stackCfg.extraFiles;
                in
                lib.nameValuePair "compose-${name}" (
                    service
                    // {
                        serviceConfig = service.serviceConfig // {
                            ExecStartPre = extraFileServices;
                        };
                    }
                )
            ) cfg)
            // (lib.mapAttrs' (
                name: stackCfg: lib.nameValuePair "compose-${name}-update" (mkUpdateService name stackCfg)
            ) cfg)
            // {
                # Aggregator: pulls + recreates every stack sequentially.
                # Sequential so a flaky pull on one stack does not race with
                # another stack's restart and double-trigger docker daemon work.
                compose-update = {
                    description = "Refresh all Docker Compose stacks";
                    after = [
                        "docker.service"
                        "network-online.target"
                    ];
                    requires = [ "docker.service" ];
                    wants = [ "network-online.target" ];
                    path = [ pkgs.systemd ];
                    serviceConfig = {
                        Type = "oneshot";
                        ExecStart = lib.singleton (
                            "${lib.getExe composeUpdateAll} ${
                                lib.escapeShellArgs (map (name: "compose-${name}-update.service") (lib.attrNames cfg))
                            }"
                        );
                    };
                };
            };

    };
}
