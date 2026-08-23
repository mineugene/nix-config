{
    config,
    hostConfig ? {
        isWsl = false;
    },
    osConfig ? { },
    lib,
    pkgs,
    ...
}:
lib.mkIf (osConfig.programs.yubikey-touch-detector.enable or false) (
    let
        backend = if hostConfig.isWsl then "wsl" else "linux";

        notifyScript = pkgs.writeShellApplication {
            name = "yubikey-touch-notify";
            runtimeInputs =
                with pkgs;
                [
                    socat
                    gnupg
                    coreutils
                    procps
                    tmux
                ]
                ++ lib.optionals (!hostConfig.isWsl) [
                    libnotify
                    dunst
                ];
            text = builtins.readFile ./notify.sh;
        };
    in
    {
        home.packages = lib.optionals (!hostConfig.isWsl) [ pkgs.libnotify ];

        services.dunst = lib.mkIf (!hostConfig.isWsl) {
            enable = true;
            # Build dunst without X11 support so it can only render via wlr-layer-shell.
            package = pkgs.dunst.override { withX11 = false; };
            settings = {
                global = {
                    font = "monospace 11";
                    origin = "top-right";
                    offset = "12x12";
                    frame_width = 1;
                    frame_color = "#bb9af7";
                    separator_color = "frame";
                    background = "#1a1b26";
                    foreground = "#c0caf5";
                    corner_radius = 4;
                    padding = 8;
                    horizontal_padding = 12;
                    markup = "full";
                    enable_recursive_icon_lookup = true;
                    follow = "mouse";
                    idle_threshold = 0;
                    show_age_threshold = -1;
                    sort = "no";
                    stack_duplicates = false;
                    indicate_hidden = false;
                };
                urgency_critical = {
                    background = "#f7768e";
                    foreground = "#1a1b26";
                    frame_color = "#e0af68";
                    timeout = 0;
                };
            };
        };

        systemd.user.services.yubikey-touch-notify = {
            Unit = {
                Description = "Render YubiKey touch alerts; write shared state file";
                After = [ "graphical-session.target" ];
                PartOf = [ ];
            };
            Service = {
                # Point tmux at the user's XDG-located socket; tmux's compiled
                # default is /tmp/tmux-$UID which doesn't exist on this system.
                Environment = "TMUX_TMPDIR=%t";
                ExecStart = "${notifyScript}/bin/yubikey-touch-notify ${backend}";
                Restart = "on-failure";
                RestartSec = "2s";
            };
            Install.WantedBy = [ "default.target" ];
        };
    }
)
