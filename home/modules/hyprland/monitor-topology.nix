{ pkgs }:
pkgs.writeShellApplication {
    name = "monitor-topology";
    runtimeInputs = [
        pkgs.coreutils
        pkgs.hyprland
        pkgs.jq
    ];
    text = builtins.readFile ./scripts/monitor-topology.sh;
}
