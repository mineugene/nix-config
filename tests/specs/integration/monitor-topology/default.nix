{
    pkgs,
    monitorTopology,
    monitorTopologyService,
}:
assert monitorTopologyService.Unit.PartOf == [ "graphical-session.target" ];
assert monitorTopologyService.Install.WantedBy == [ "graphical-session.target" ];
assert !(monitorTopologyService.Service ? ExecStartPre);
assert monitorTopologyService.Service.ExecStart == [ "${monitorTopology} watch" ];
assert monitorTopologyService.Service.Restart == "on-failure";
pkgs.runCommandLocal "monitor-topology-check" {
    nativeBuildInputs = [ pkgs.jq ];
    inherit monitorTopology;
    hyprlandCommand = "${pkgs.hyprland}/bin/Hyprland";
    dynamicMonitor = ./dynamic-monitor.lua;
    waitHelpers = ../../../support/wait.sh;
} (builtins.readFile ./monitor-topology.sh)
