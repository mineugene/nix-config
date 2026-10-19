{
    pkgs,
    graphify,
    homePath,
}:
let
    python = "${graphify.pythonEnvironment}/bin/python${pkgs.python3.pythonVersion}";
    minimalPath = pkgs.lib.makeBinPath [
        pkgs.git
        pkgs.coreutils
    ];
in
pkgs.runCommandLocal "graphify-hook-check" {
    nativeBuildInputs = [
        pkgs.git
        pkgs.jq
        graphify
    ];
    inherit
        graphify
        homePath
        python
        minimalPath
        ;
    homeImports = ./graphify-home-imports.py;
    graphifyImports = ./graphify-imports.py;
    initialModule = ../../../fixtures/graphify-initial.py;
    changedModule = ../../../fixtures/graphify-changed.py;
    hookBefore = ../../../fixtures/graphify-hook-before.sh;
    hookAfter = ../../../fixtures/graphify-hook-after.sh;
    waitHelpers = ../../../support/wait.sh;
} (builtins.readFile ./graphify.sh)
