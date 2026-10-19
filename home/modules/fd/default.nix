{ ... }:
{
    programs.fd = {
        enable = true;
        ignores = [
            ".git/"
            ".npm/"
            "node_modules/"
            "package-lock.json"
            ".vscode/"

            # Auto-generated cache files contained in XDG_CACHE_HOME
            ".cache/"
        ];
    };

    programs.zsh.shellAliases = {
        fd = "fd --hidden --strip-cwd-prefix --color=auto";
    };
}
