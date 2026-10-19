{ pkgs }:
pkgs.runCommandLocal "source-helpers-check" {
    nativeBuildInputs = [
        pkgs.coreutils
        pkgs.dash
        pkgs.git
        pkgs.gnused
    ];
    treeSource = ../../../../home/modules/lsd/tree.sh;
    previewSource = ../../../../home/modules/fzf/preview-directory.sh;
    deleteSource = ../../../../home/modules/fzf/delete-history.sh;
    touchSource = ../../../../home/modules/starship/touch-state.sh;
    resolveSource = ../../../../home/modules/starship/resolve-config.sh;
} (builtins.readFile ./source-helpers.sh)
