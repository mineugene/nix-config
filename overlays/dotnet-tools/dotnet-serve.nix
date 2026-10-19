{
    lib,
    buildDotnetGlobalTool,
    dotnetCorePackages,
    versionCheckHook,
}:
buildDotnetGlobalTool {
    pname = "dotnet-serve";
    version = "1.10.194";
    nugetHash = "sha256-CscuL5AT7nEJyBuQVKCyBfsP3T86SwlQ22MCfSpueqM=";

    dotnet-sdk = dotnetCorePackages.sdk_10_0;
    dotnet-runtime = dotnetCorePackages.sdk_10_0;

    nativeInstallCheckInputs = [ versionCheckHook ];
    doInstallCheck = true;
    versionCheckProgram = "${placeholder "out"}/bin/dotnet-serve";
    versionCheckProgramArg = "--version";

    meta = {
        description = "Command-line HTTP server for static files";
        homepage = "https://github.com/natemcmaster/dotnet-serve";
        license = lib.licenses.asl20;
        mainProgram = "dotnet-serve";
    };
}
