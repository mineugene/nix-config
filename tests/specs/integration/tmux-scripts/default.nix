{
    homePackages,
    pkgs,
    tmuxSessionSwitcher,
}:
let
    findPackage =
        name: builtins.head (builtins.filter (package: pkgs.lib.getName package == name) homePackages);
    displayName = pkgs.lib.getExe (findPackage "tmux-display-name");
    shortenPath = pkgs.lib.getExe (findPackage "shorten-path");
    yubikeyTouch = pkgs.lib.getExe (findPackage "yubikey-touch-indicator");
in
pkgs.runCommandLocal "tmux-scripts-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.dash
        pkgs.gitMinimal
        pkgs.jq
        pkgs.python3
        pkgs.tmux
        pkgs.zsh
    ];
    inherit
        displayName
        shortenPath
        yubikeyTouch
        tmuxSessionSwitcher
        ;
    testScript = ./tmux-scripts.sh;
    switcherTest = ./tmux-session-switcher.py;
    switcherStub = ../../../fixtures/tmux-switcher-stub.sh;
    tmuxWrapper = ../../../fixtures/tmux-switcher-tmux.sh;
    zleSetup = ./tmux-switcher-zle.zsh;
} (builtins.readFile ./tmux-scripts-check.sh)
