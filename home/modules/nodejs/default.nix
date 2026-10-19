{ config, pkgs, ... }:
{
    home.packages = with pkgs; [
        nodejs_24
        typescript-language-server
        vscode-js-debug
    ];

    home.sessionVariables = {
        NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
        NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
    };
}
