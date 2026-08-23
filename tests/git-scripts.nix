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
in
pkgs.runCommandLocal "git-scripts-check"
    {
        nativeBuildInputs = [
            pkgs.dash
            pkgs.git
        ];
        inherit
            gitBreaking
            gitDesctag
            gitIgtrkPurge
            gitLgonly
            gitUnpsf
            ;
        testScript = ./scripts/git-scripts.sh;
    }
    ''
        set -eu

        dash "$testScript" "$gitBreaking" "$gitDesctag" "$gitIgtrkPurge" "$gitLgonly" "$gitUnpsf" "$TMPDIR/git-scripts"
        touch "$out"
    ''
