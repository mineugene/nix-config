{
    pkgs,
    qmlLint,
    shellConfig,
    shellService,
    extensionShellConfig,
    extensionShellService,
    lockService,
    lockEnable,
    pamModule,
}:
pkgs.runCommandLocal "quickshell-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.jq
        pkgs.qt6.qtdeclarative
    ];
    inherit
        qmlLint
        shellConfig
        extensionShellConfig
        lockEnable
        pamModule
        ;
    quickshellModules = "${pkgs.quickshell}/lib/qt-6/qml";
    qtModules = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
    shellFile = pkgs.writeText "quickshell.json" (builtins.toJSON shellService);
    extensionShellFile = pkgs.writeText "quickshell-extension.json" (
        builtins.toJSON extensionShellService
    );
    lockFile = pkgs.writeText "shell-lock.json" (builtins.toJSON lockService);
} (builtins.readFile ./quickshell.sh)
