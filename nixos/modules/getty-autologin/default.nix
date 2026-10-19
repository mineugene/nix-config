{
    config,
    lib,
    pkgs,
    ...
}:
let
    cfg = config.mine.autologin;
    agetty = lib.getExe' pkgs.util-linux "agetty";
    # The template getty@.service sets ExecStart with a systemd drop-in; an
    # instance override replaces it, so the exec line must be re-stated in full.
    autologinExecStart =
        "${agetty}"
        + " --login-program ${config.services.getty.loginProgram}"
        + " --issue-file /etc/issue:/etc/issue.d:/run/issue:/run/issue.d"
        + " --autologin ${cfg.user}"
        + " --noclear --keep-baud %I 115200,38400,9600 $TERM";
in
{
    options.mine.autologin = {
        user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "User logged in automatically on the console; null leaves a login prompt.";
        };
        tty = lib.mkOption {
            type = lib.types.str;
            default = "tty1";
            description = "Virtual terminal that autologins; every other terminal keeps a prompt.";
        };
    };

    config = lib.mkIf (cfg.user != null) {
        # An instance unit file would shadow getty@.service entirely and lose
        # its tty wiring, so this must extend the template as a drop-in.
        systemd.services."getty@${cfg.tty}" = {
            overrideStrategy = "asDropin";
            serviceConfig.ExecStart = [
                ""
                autologinExecStart
            ];
        };
    };
}
