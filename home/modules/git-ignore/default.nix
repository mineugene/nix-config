{ config, lib, ... }:
{
    programs.zsh.shellAliases = {
        gitignore = "git-ignore";
    };

    # Plugin's init.zsh hardcodes GI_TEMPLATE to a path under its own
    # source dir, which Home Manager symlinks into the read-only Nix
    # store. Plugins source at mkOrder 900, so override after that to
    # redirect the template cache to a writable XDG location.
    programs.zsh.initContent = lib.mkOrder 1000 ''
        export GI_TEMPLATE="${config.xdg.dataHome}/git-ignore"
    '';
}
