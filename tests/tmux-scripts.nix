{ homePackages, pkgs }:
let
    findPackage =
        name: builtins.head (builtins.filter (package: pkgs.lib.getName package == name) homePackages);
    displayName = pkgs.lib.getExe (findPackage "tmux-display-name");
    shortenPath = pkgs.lib.getExe (findPackage "shorten-path");
    yubikeyTouch = pkgs.lib.getExe (findPackage "yubikey-touch-indicator");
in
pkgs.runCommandLocal "tmux-scripts-check"
    {
        nativeBuildInputs = [
            pkgs.coreutils
            pkgs.dash
            pkgs.gitMinimal
        ];
        inherit
            displayName
            shortenPath
            yubikeyTouch
            ;
        testScript = ./scripts/tmux-scripts.sh;
    }
    ''
        set -eu

        dash "$testScript" "$shortenPath" "$displayName" "$yubikeyTouch" "$TMPDIR/tmux-scripts"
        touch "$out"
    ''
