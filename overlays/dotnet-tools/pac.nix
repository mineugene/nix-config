{
    lib,
    buildDotnetGlobalTool,
    dotnetCorePackages,
    versionCheckHook,
}:
buildDotnetGlobalTool {
    pname = "pac";
    nugetName = "Microsoft.PowerApps.CLI.Tool";
    version = "2.13.1";
    nugetHash = "sha256-WlEQQS9jO4df0qTKBGhtKjaa8IR8ISdMvZq5qFLevy8=";

    dotnet-sdk = dotnetCorePackages.sdk_10_0;
    # The tool targets net10.0; `buildDotnetGlobalTool` defaults the wrapper
    # runtime to the package set's plain `dotnet-sdk` (8.0), which cannot load
    # a net10.0 app, so pin the runtime explicitly.
    dotnet-runtime = dotnetCorePackages.sdk_10_0;

    nativeInstallCheckInputs = [ versionCheckHook ];
    doInstallCheck = true;
    versionCheckProgram = "${placeholder "out"}/bin/pac";
    versionCheckProgramArg = "--version";

    meta = {
        description = "Microsoft Power Platform CLI";
        homepage = "https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction";
        license = lib.licenses.unfree;
        mainProgram = "pac";
    };
}
