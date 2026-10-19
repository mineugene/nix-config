{ ... }:
{
    programs.bat = {
        enable = true;
        config = {
            theme = "TokyoNight";
            pager = "less -RF";
        };
        themes = {
            "TokyoNight" = {
                src = ./themes;
                file = "tokyo-night.tmTheme";
            };
        };
    };

    programs.zsh.shellAliases = {
        cat = "bat -p";
        catn = "bat";
    };
}
