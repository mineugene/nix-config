{ pkgs }:
let
    fonts = map (name: pkgs.${name}) [
        "iosevka-nf"
        "iosevka-term-nf"
        "iosevka-aile-nf"
        "iosevka-etoile-nf"
    ];
    patcher = builtins.head (builtins.head fonts).nativeBuildInputs;
in
assert builtins.all (
    font:
    font.src.npm_config_loglevel == "warn"
    && pkgs.lib.hasInfix "--verbosity=4" font.src.buildPhase
    && !(pkgs.lib.hasInfix "--verbosity=9" font.src.buildPhase)
    && pkgs.lib.hasInfix "--quiet" font.buildPhase
    && !(pkgs.lib.hasInfix "echo \"Patching:" font.buildPhase)
) fonts;
pkgs.runCommandLocal "iosevka-logging-check" {
    nativeBuildInputs = [ pkgs.python3 ];
    patcherSource = "${patcher.src}/font-patcher";
    postPatch = patcher.postPatch;
    loggingTest = ./iosevka-logging.py;
} (builtins.readFile ./iosevka-logging.sh)
