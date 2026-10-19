{ homePackages, pkgs }:
let
    findScript =
        name:
        pkgs.lib.getExe (
            builtins.head (builtins.filter (package: pkgs.lib.getName package == name) homePackages)
        );
    gitBreaking = findScript "git-breaking";
    gitDesctag = findScript "git-desctag";
    gitIgtrkPurge = findScript "git-igtrk-purge";
    gitLgonly = findScript "git-lgonly";
    gitUnpsf = findScript "git-unpsf";
    aliasScripts =
        map (name: builtins.head (builtins.filter (package: pkgs.lib.getName package == name) homePackages))
            [
                "git-snap"
                "git-ignored-names"
                "git-lgcc"
                "git-lgd"
                "git-lgsince"
            ];
in
pkgs.runCommandLocal "git-scripts-check" {
    nativeBuildInputs = [
        pkgs.dash
        pkgs.git
        pkgs.jq
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnutar
        pkgs.gzip
        pkgs.gnugrep
    ]
    ++ aliasScripts;
    inherit
        gitBreaking
        gitDesctag
        gitIgtrkPurge
        gitLgonly
        gitUnpsf
        ;
    testScript = ./git-scripts.sh;
    aliasTest = ./git-aliases.sh;
    gitAliases = (pkgs.formats.json { }).generate "git-aliases.json" (
        import ../../../../home/modules/git/aliases.nix
    );
} (builtins.readFile ./git-scripts-check.sh)
