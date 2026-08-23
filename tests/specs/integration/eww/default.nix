{
    pkgs,
    eww,
    ewwFiles,
    homePackages,
}:
let
    homePackage = name: builtins.head (builtins.filter (package: package.name == name) homePackages);
    animationFrame = homePackage "eww-animation-frame";
    audio = ewwFiles."eww/modules/audio.yuck".source;
    audioCommand = homePackage "eww-audio";
    audioPopup = ewwFiles."eww/popups/audio.yuck".source;
    bluetooth = ewwFiles."eww/modules/bluetooth.yuck".source;
    bluetoothCommand = homePackage "eww-bluetooth";
    bar = ewwFiles."eww/bar.yuck".source;
    calendar = ewwFiles."eww/popups/calendar.yuck".source;
    clock = ewwFiles."eww/modules/clock.yuck".source;
    commonPopups = ewwFiles."eww/popups/common.yuck".source;
    hardware = ewwFiles."eww/modules/hardware.yuck".source;
    hardwarePopup = ewwFiles."eww/popups/hardware.yuck".source;
    menu = ewwFiles."eww/modules/menu.yuck".source;
    menuCommand = homePackage "eww-menu";
    menuPopup = ewwFiles."eww/popups/menu.yuck".source;
    profilePopup = ewwFiles."eww/popups/profile.yuck".source;
    hardwareStatus = homePackage "eww-hardware-status";
    network = ewwFiles."eww/modules/network.yuck".source;
    networkListener = homePackage "eww-network-listener";
    networkPopup = ewwFiles."eww/popups/network.yuck".source;
    notifications = ewwFiles."eww/modules/notifications.yuck".source;
    popupToggle = pkgs.lib.getExe (homePackage "popup-toggle");
    profile = ewwFiles."eww/modules/profile.yuck".source;
    scss = ewwFiles."eww/eww.scss".source;
    tray = ewwFiles."eww/modules/tray.yuck".source;
    theme = ewwFiles."eww/theme.scss".source;
    themeWidget = ewwFiles."eww/modules/theme.yuck".source;
    window = ewwFiles."eww/modules/window.yuck".source;
    workspaces = ewwFiles."eww/modules/workspaces.yuck".source;
    hyprlandListenerSource = ../../../../home/modules/hyprland/eww/scripts/hyprland-listener.sh;
    audioSource = ../../../../home/modules/hyprland/eww/scripts/audio.sh;
    yuck = ewwFiles."eww/eww.yuck".source;
in
pkgs.runCommandLocal "eww-base-bar-check" {
    nativeBuildInputs = [
        eww.package
        pkgs.coreutils
        pkgs.dash
        pkgs.dbus
        pkgs.gnused
        pkgs.jq
        pkgs.python3
        pkgs.util-linux
        pkgs.xvfb-run
        animationFrame
        audioCommand
        bluetoothCommand
        hardwareStatus
        menuCommand
        networkListener
    ];
    inherit
        audio
        audioPopup
        bluetooth
        bar
        calendar
        clock
        commonPopups
        hardware
        hardwarePopup
        menu
        menuPopup
        profilePopup
        network
        networkPopup
        notifications
        popupToggle
        profile
        scss
        theme
        themeWidget
        tray
        window
        audioSource
        hyprlandListenerSource
        workspaces
        yuck
        ;
    hardwareStatusCommand = pkgs.lib.getExe hardwareStatus;
    ewwCommand = pkgs.lib.getExe eww.package;
    dbusConfig = "${pkgs.dbus}/share/dbus-1/session.conf";
    smokeScript = ./eww-smoke.sh;
    waitHelpers = ../../../support/wait.sh;
    audioListenerTest = ./audio-listener.py;
    audioSubscriber = ../../../fixtures/audio-subscriber.py;
    audioControl = ../../../fixtures/audio-control.py;
} (builtins.readFile ./eww.sh)
