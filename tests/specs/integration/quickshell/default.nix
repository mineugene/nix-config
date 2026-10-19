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
        pkgs.nodejs
        pkgs.qt6.qtdeclarative
        pkgs.quickshell
        pkgs.pipewire
        pkgs.pulseaudio
        pkgs.wireplumber
        pkgs.dbus
    ];
    inherit
        qmlLint
        shellConfig
        extensionShellConfig
        lockEnable
        pamModule
        ;
    dbusConfig = "${pkgs.dbus}/share/dbus-1/session.conf";
    audioRoutingModel = ../../../../home/modules/hyprland/shell/qml/AudioRouting.js;
    audioRoutingModelTest = ./audio-routing-test.js;
    audioDefaultsTest = ./audio-defaults.qml;
    audioCaptureCheck = ./audio-capture.sh;
    captureRoutingConfig = pkgs.replaceVars ./capture-routing.conf {
        restoreScript = ../../../../nixos/modules/openxlr/restore-capture-target.lua;
    };
    audioTestTokens = ./test-Tokens.qml;
    audioTestDesktop = ./test-Desktop.qml;
    audioDefaultsCheck = ./audio-defaults.sh;
    tooltipCheck = ./tooltip.sh;
    tooltipTest = ./tooltip-test.qml;
    tooltipTokens = ./tooltip-Tokens.qml;
    revealCheck = ./reveal.sh;
    revealTest = ./reveal-test.qml;
    revealTokens = ./reveal-Tokens.qml;
    fontConfig = pkgs.makeFontsConf {
        fontDirectories = [ pkgs.dejavu_fonts ];
    };
    quickshellModules = "${pkgs.quickshell}/lib/qt-6/qml";
    qtModules = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
    shellFile = pkgs.writeText "quickshell.json" (builtins.toJSON shellService);
    extensionShellFile = pkgs.writeText "quickshell-extension.json" (
        builtins.toJSON extensionShellService
    );
    lockFile = pkgs.writeText "shell-lock.json" (builtins.toJSON lockService);
} (builtins.readFile ./quickshell.sh)
