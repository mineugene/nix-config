{ pkgs, ... }:
{
    home.packages = [ pkgs.lsd ];

    xdg.configFile."lsd/colors.yaml".source = ./config/colors.yaml;
    xdg.configFile."lsd/config.yaml".source = ./config/config.yaml;

    programs.zsh.shellAliases = {
        ls = "lsd -lA";
        tree = "lsd --tree --depth=3 --blocks=date,size,name $(IGNORE=$(git rev-parse --show-toplevel 2>/dev/null)/.gitignore; if [ -f \"$IGNORE\" ]; then xargs printf ' --ignore-glob=%s' < \"$IGNORE\"; fi)";
    };
}
