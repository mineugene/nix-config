{ config, pkgs, ... }:
{
    home.packages = with pkgs; [
        docker-compose
    ];

    home.sessionVariables.DOCKER_CONFIG = "${config.xdg.configHome}/docker";
}
