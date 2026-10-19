{
    lib,
    buildDotnetGlobalTool,
    dotnetCorePackages,
    versionCheckHook,
}:
buildDotnetGlobalTool {
    pname = "easydotnet";
    nugetName = "EasyDotnet";
    version = "3.4.26";
    nugetHash = "sha256-Sn4zzJ4nWkkp5o/aJ9HV8m+JW4DWx09/MsNEbWU1qYU=";

    dotnet-sdk = dotnetCorePackages.sdk_10_0;
    executables = [ "dotnet-easydotnet" ];

    nativeInstallCheckInputs = [ versionCheckHook ];
    doInstallCheck = true;
    versionCheckProgram = "${placeholder "out"}/bin/dotnet-easydotnet";
    versionCheckProgramArg = "-v";

    meta = {
        description = ".NET workflow server for easy-dotnet.nvim";
        homepage = "https://github.com/GustavEikaas/easy-dotnet-server";
        license = lib.licenses.mit;
        mainProgram = "dotnet-easydotnet";
    };
}
