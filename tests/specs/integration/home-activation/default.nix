{
    nixpkgs,
    home-manager,
    system,
    pkgsConfig ? { },
    publicHomeModules,
}:
let
    pkgs = import nixpkgs ({ inherit system; } // pkgsConfig);
    inherit (pkgs) lib;
    fixtureHome = "/home/home-activation-check";
    mkHome =
        declared:
        home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs.hostConfig = {
                isWsl = true;
                users.home-activation-check.windowsUsername = "activation-check";
            };
            modules = [
                publicHomeModules.pi
                publicHomeModules.rtk
                publicHomeModules.starship
                {
                    home.username = "home-activation-check";
                    home.homeDirectory = fixtureHome;
                    home.stateVersion = "25.11";
                    programs.pi-coding-agent.pidevSettings = declared;
                }
            ];
        };
    home = mkHome {
        declared = {
            keep = "new";
        };
    };
    emptyHome = mkHome { };
    cfg = home.config;
    order = map (entry: entry.name) (cfg.lib.dag.topoSort cfg.home.activation).result;
    before =
        first: second:
        lib.lists.findFirstIndex (name: name == first) (-1) order
        < lib.lists.findFirstIndex (name: name == second) (-1) order;
    entry = name: pkgs.writeText "activation-${name}.sh" cfg.home.activation.${name}.data;
in
assert lib.assertMsg (before "linkGeneration" "configurePiDev")
    "Pi activation must follow linkGeneration";
assert lib.assertMsg (before "linkGeneration" "resolveStarshipConfig")
    "Starship materialization must follow linkGeneration";
assert lib.assertMsg (before "writeBoundary" "rtkTelemetry")
    "RTK activation must follow writeBoundary";
# Run actual entries with Home Manager's run helper and a relocated synthetic
# home. Profile installation, linkGeneration and user services are not executed.
pkgs.runCommandLocal "home-activation-check" {
    nativeBuildInputs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.diffutils
        pkgs.findutils
        pkgs.gettext
        pkgs.gnugrep
        pkgs.jq
        pkgs.ncurses
    ];
    inherit fixtureHome;
    testRunner = ./home-activation.sh;
    hmInit = pkgs.writeText "home-manager-activation-lib.sh" cfg.lib.bash.initHomeManagerLib;
    piEntry = entry "configurePiDev";
    piEmptyEntry = pkgs.writeText "activation-configurePiDev-empty.sh" emptyHome.config.home.activation.configurePiDev.data;
    starshipEntry = entry "resolveStarshipConfig";
    starshipConfig = cfg.home.file.${cfg.programs.starship.configPath}.source;
    rtkEntry = entry "rtkTelemetry";
    rtkExecutable = lib.getExe pkgs.rtk;
} (builtins.readFile ./home-activation.sh)
