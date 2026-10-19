{
    lib,
    pkgs,
    ...
}:
let
    hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
    loginctl = lib.getExe' pkgs.systemd "loginctl";
    systemctl = lib.getExe' pkgs.systemd "systemctl";
    lockCommand = "${systemctl} --user start shell-lock.service";
    requestLock = "${loginctl} lock-session";
in
{
    services.hypridle = {
        enable = true;
        settings = {
            general = {
                lock_cmd = lockCommand;
                before_sleep_cmd = requestLock;
                ignore_dbus_inhibit = false;
            };
            listener = [
                {
                    timeout = 900;
                    on-timeout = requestLock;
                }
                {
                    timeout = 600;
                    on-timeout = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
                    on-resume = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
                }
            ];
        };
    };
}
