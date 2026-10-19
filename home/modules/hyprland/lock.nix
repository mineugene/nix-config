{
    config,
    lib,
    pkgs,
    ...
}:
let
    monitorTopology = import ./monitor-topology.nix { inherit pkgs; };
    shellConfig = import ./shell/config.nix { inherit config lib pkgs; };
    lockLauncher = pkgs.writeShellApplication {
        name = "shell-lock-launch";
        runtimeInputs = [
            pkgs.quickshell
            monitorTopology
        ];
        runtimeEnv = {
            SHELL_LOCK_QML = "${shellConfig.qml}/lock.qml";
            SHELL_TOKENS = shellConfig.tokens;
        };
        text = builtins.readFile ./shell/scripts/lock-launch.sh;
    };
    lockCommand = pkgs.writeShellApplication {
        name = "shell-lock";
        runtimeInputs = [ pkgs.systemd ];
        text = builtins.readFile ./shell/scripts/lock.sh;
    };
in
{
    home.packages = [ lockCommand ];

    # The compositor owns the session lock: it starts after the graphical
    # session is up so the screen is covered as soon as autologin reaches the
    # desktop.
    systemd.user.services.shell-lock = {
        Unit = {
            Description = "Quickshell session lock";
            After = [ "graphical-session.target" ];
            # Own the screen before any other session surface appears.
            Before = [
                "desktop-theme.service"
                "quickshell.service"
            ];
            PartOf = [ "graphical-session.target" ];
            # sd-switch restarts a changed unit while it is running. A lock is
            # already covering the screen then, so the switch must leave it up.
            X-SwitchMethod = "keep-old";
        };
        Service = {
            Type = "simple";
            ExecStart = lib.getExe lockLauncher;
            # A crash must re-lock; a clean exit is a successful unlock and
            # must not restart.
            Restart = "on-failure";
            RestartSec = 1;
        };
    };

    # sd-switch starts every unit that an active target wants on each switch,
    # which is precisely when an unlocked session has no lock running.
    # Enabling it from the data directory keeps systemd's start ordering while
    # leaving the wants link out of the directory sd-switch reads.
    xdg.dataFile."systemd/user/graphical-session.target.wants/shell-lock.service".source =
        config.xdg.configFile."systemd/user/shell-lock.service".source;
}
