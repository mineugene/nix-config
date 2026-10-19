{
    config,
    lib,
    pkgs,
    ...
}:
let
    cfg = config.mine.desktop.hyprland;
in
{
    options.mine.desktop.hyprland = {
        launchFromTty = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Start Hyprland from the login shell after a console autologin.";
        };
        launchTty = lib.mkOption {
            type = lib.types.str;
            default = "tty1";
            description = "Virtual terminal that starts Hyprland when launchFromTty is enabled.";
        };
    };

    config = lib.mkIf cfg.launchFromTty {
        programs.zsh.loginExtra = builtins.readFile (
            pkgs.replaceVars ./scripts/tty-launch.sh {
                tty = cfg.launchTty;
            }
        );
    };
}
