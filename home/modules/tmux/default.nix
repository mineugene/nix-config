{ lib, pkgs, ... }:
let
    mkPosixScript = import ../../../lib/scripts.nix { inherit pkgs; };
    shortenPath = mkPosixScript {
        name = "shorten-path";
        src = ./scripts/shorten-path.sh;
    };
    displayName = mkPosixScript {
        name = "tmux-display-name";
        src = ./scripts/display-name.sh;
    };
    yubikeyTouch = mkPosixScript {
        name = "yubikey-touch-indicator";
        src = ./scripts/yubikey-touch-indicator.sh;
    };
in
{
    imports = [
        ./keymap.nix
    ];

    home.packages = [
        displayName
        shortenPath
        yubikeyTouch
    ];

    programs.tmux = {
        enable = true;

        prefix = "C-s";
        keyMode = "vi";

        aggressiveResize = true;
        baseIndex = 1;
        clock24 = true;
        disableConfirmationPrompt = false;
        escapeTime = 0;
        focusEvents = true;
        historyLimit = 9999;
        mouse = false;
        sensibleOnTop = true;
        terminal = "tmux-256color";

        extraConfig =
            builtins.replaceStrings
                [ "@displayName@" "@yubikeyTouch@" ]
                [ (lib.getExe displayName) (lib.getExe yubikeyTouch) ]
                (builtins.readFile ./tmux.conf);
    };
}
