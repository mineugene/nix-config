{ config, pkgs, ... }:
let
    dotnet = pkgs.dotnetCorePackages.combinePackages [
        pkgs.dotnetCorePackages.sdk_8_0
        pkgs.dotnetCorePackages.sdk_9_0
        pkgs.dotnetCorePackages.sdk_10_0
    ];
in
{
    home.packages = with pkgs; [
        dotnet
        netcoredbg
        omnisharp-roslyn
    ];

    home.sessionVariables = {
        DOTNET_CLI_TELEMETRY_OPTOUT = "1";
        DOTNET_CLI_HOME = config.xdg.dataHome;
        OMNISHARPHOME = "${config.xdg.configHome}/omnisharp";
    };
}
