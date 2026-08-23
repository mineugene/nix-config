{ pkgs, ... }:
let
    imageName = "localhost:5000/lifecycle-fixture";
    mkImage =
        tag: version:
        pkgs.dockerTools.buildLayeredImage {
            name = imageName;
            inherit tag;
            contents = [ pkgs.busybox ];
            config = {
                Cmd = [
                    "sleep"
                    "infinity"
                ];
                StopSignal = "SIGKILL";
                Labels.lifecycle-version = version;
            };
        };
    initialImage = mkImage "latest" "one";
    updatedImage = mkImage "next" "two";
    image = "${imageName}:latest";
    network = "lifecycle-shared";
in
pkgs.testers.runNixOSTest {
    name = "service-lifecycle";

    nodes.machine = { lib, ... }: {
        imports = [ ../../../../nixos/modules/compose ];

        virtualisation = {
            memorySize = 2048;
            diskSize = 4096;
            cores = 2;
            docker.enable = true;
        };
        services.dockerRegistry.enable = true;
        environment.etc."lifecycle.env".text = "FIXTURE_VALUE=initial\n";

        services.composeStacks = {
            alpha.composeFileContent = builtins.toJSON {
                services.fixture = {
                    inherit image;
                    container_name = "lifecycle-alpha";
                    networks = [ "shared" ];
                };
                networks.shared.name = network;
            };
            beta = {
                dependsOn = [ "alpha" ];
                envFile = "/etc/lifecycle.env";
                extraFiles."nested/config.txt" = "declarative fixture\n";
                composeFileContent = builtins.toJSON {
                    services.fixture = {
                        inherit image;
                        container_name = "lifecycle-beta";
                        environment.FIXTURE_VALUE = "\${FIXTURE_VALUE}";
                        volumes = [ "./nested/config.txt:/fixture/config.txt:ro" ];
                        networks = [ "shared" ];
                    };
                    networks.shared = {
                        name = network;
                        external = true;
                    };
                };
            };
        };

        systemd.services = {
            fixture-images = {
                after = [ "docker.service" ];
                requires = [ "docker.service" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    ExecStart = [
                        "${lib.getExe pkgs.docker} load -i ${initialImage}"
                        "${lib.getExe pkgs.docker} load -i ${updatedImage}"
                    ];
                };
            };
            compose-alpha = {
                after = [ "fixture-images.service" ];
                requires = [ "fixture-images.service" ];
            };
            compose-beta = {
                after = [ "fixture-images.service" ];
                requires = [ "fixture-images.service" ];
            };
        };
    };

    testScript = builtins.readFile ./service-lifecycle.py;
}
