{
    hypridleConfig,
    pkgs,
}:
pkgs.runCommandLocal "hypridle-idle-policy-check" {
    config = hypridleConfig;
} (builtins.readFile ./hypridle.sh)
