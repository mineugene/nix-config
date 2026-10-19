{
    config,
    lib,
    pkgs,
    ...
}:
let
    cfg = config.programs.azure-artifacts-credprovider;
    credentialProviderPlugin = "${cfg.package}/lib/azure-artifacts-credprovider/CredentialProvider.Microsoft.dll";
in
{
    options.programs.azure-artifacts-credprovider = {
        enable = lib.mkEnableOption ''
            the Azure Artifacts Credential Provider so `dotnet`/`nuget` can
            authenticate against Azure DevOps Artifacts feeds via device-code
            flow (`--interactive`) or a pre-set PAT.
        '';

        package = lib.mkPackageOption pkgs "azure-artifacts-credprovider" { };

    };

    config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];

        home.sessionVariables = {
            NUGET_PLUGIN_PATHS = credentialProviderPlugin;
            ARTIFACTS_CREDENTIALPROVIDER_MSAL_ALLOW_BROKER = "false";
        };
    };
}
