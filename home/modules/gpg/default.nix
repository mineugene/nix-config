{
    config,
    pkgs,
    ...
}:
{
    home.sessionVariables.GNUPGHOME = config.programs.gpg.homedir;

    programs.gpg = {
        enable = true;
        homedir = "${config.xdg.dataHome}/gnupg";
    };

    services.gpg-agent = {
        enable = true;
        enableSshSupport = true;
        pinentry.package = pkgs.pinentry-curses;
        defaultCacheTtl = 28800;
        maxCacheTtl = 28800;
        defaultCacheTtlSsh = 28800;
        maxCacheTtlSsh = 28800;
    };

}
