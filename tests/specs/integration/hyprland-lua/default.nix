{
    pkgs,
    configuredMonitor,
    hyprlandFiles,
}:
let
    bindings = hyprlandFiles."hypr/bindings.lua".source;
    generatedMonitor = hyprlandFiles."hypr/generated/monitor.lua".source;
    generatedPrograms = hyprlandFiles."hypr/generated/programs.lua".source;
    monitors = hyprlandFiles."hypr/monitors.lua".source;
    root = hyprlandFiles."hypr/hyprland.lua".source;
in
pkgs.runCommandLocal "hyprland-lua-check" {
    nativeBuildInputs = [ pkgs.lua ];
    inherit
        bindings
        configuredMonitor
        generatedMonitor
        generatedPrograms
        monitors
        root
        ;
    hyprlandCommand = "${pkgs.hyprland}/bin/Hyprland";
    monitorEvents = ./monitor-events.lua;
} (builtins.readFile ./hyprland-lua.sh)
