{
    homePackages,
    pkgs,
    userService,
}:
let
    command = builtins.head (pkgs.lib.splitString " " (builtins.head userService.Service.ExecStart));
in
assert userService.Service.Restart == "on-failure";
assert userService.Install.WantedBy == [ "default.target" ];
pkgs.runCommandLocal "yubikey-touch-notify-check"
    {
        nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.socat
        ];
        inherit command;
        testScript = ./scripts/yubikey-touch-notify.sh;
    }
    ''
        set -eu

        "$testScript" "$command" "$TMPDIR/yubikey-touch-notify"
        touch "$out"
    ''
