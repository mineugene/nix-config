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
pkgs.runCommandLocal "yubikey-touch-notify-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.socat
    ];
    inherit command;
    testScript = ./yubikey-touch-notify.sh;
    waitHelpers = ../../../support/wait.sh;
} (builtins.readFile ./yubikey-touch-notify-check.sh)
