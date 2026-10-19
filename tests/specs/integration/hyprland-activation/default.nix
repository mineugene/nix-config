{
    pkgs,
    activation,
    defaultActivation,
    reloadScript,
}:
let
    script = builtins.readFile reloadScript;
in
assert activation ? reloadHyprland;
assert !(defaultActivation ? reloadHyprland);
assert builtins.elem "linkGeneration" activation.reloadHyprland.after;
assert pkgs.lib.hasInfix "reload-hyprland" activation.reloadHyprland.data;
assert pkgs.lib.hasInfix "instances -j" script;
assert pkgs.lib.hasInfix "hyprland-activation" script;
assert pkgs.lib.hasInfix "--instance" script;
pkgs.runCommandLocal "hyprland-activation-check" { } "touch $out"
