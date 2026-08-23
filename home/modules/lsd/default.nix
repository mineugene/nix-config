{ lib, pkgs, ... }:
let
    tree = pkgs.writeShellApplication {
        name = "lsd-tree";
        runtimeInputs = [
            pkgs.git
            pkgs.lsd
        ];
        text = builtins.readFile ./tree.sh;
    };
in
{
    programs.lsd = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableZshIntegration = false;
        settings = {
            color.when = "auto";
            blocks = [
                "permission"
                "user"
                "group"
                "date"
                "size"
                "name"
            ];
            size = "short";
            sorting.dir-grouping = "first";
            symlink-arrow = false;
            icons.when = "never";
        };
        colors = {
            user = "dark_red";
            group = "dark_yellow";
            permission = lib.genAttrs [
                "read"
                "write"
                "exec"
                "exec-sticky"
                "no-access"
                "octal"
                "acl"
                "context"
            ] (_: "dark_grey");
            date = {
                hour-old = "white";
                day-old = "dark_cyan";
                older = "dark_grey";
            };
            size = {
                none = "grey";
                small = "dark_cyan";
                medium = "cyan";
                large = "magenta";
            };
            inode = {
                valid = "cyan";
                invalid = "grey";
            };
            links = {
                valid = "white";
                invalid = "grey";
            };
            tree-edge = "grey";
            git-status = {
                default = "grey";
                unmodified = "dark_grey";
                ignored = "grey";
                new-in-index = "dark_cyan";
                new-in-workdir = "dark_cyan";
                typechange = "dark_yellow";
                deleted = "dark_red";
                renamed = "dark_cyan";
                modified = "dark_magenta";
                conflicted = "dark_red";
            };
        };
    };

    home.packages = [ tree ];

    programs.zsh.shellAliases = {
        ls = "lsd -lA";
        tree = lib.getExe tree;
    };
}
