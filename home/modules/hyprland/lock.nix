{ config, lib, ... }:
let
    theme = config.mine.desktop.theme;
    colors = theme.colors.${theme.defaultMode};
    toRgb = color: "rgb(${lib.removePrefix "#" color})";
in
{
    programs.hyprlock = {
        enable = true;
        settings = {
            general = {
                hide_cursor = true;
                ignore_empty_input = true;
                immediate_render = true;
            };
            background = [
                {
                    monitor = "";
                    color = toRgb colors.background;
                }
            ];
            "input-field" = [
                {
                    monitor = "";
                    size = "320, 52";
                    position = "0, -40";
                    halign = "center";
                    valign = "center";
                    outline_thickness = theme.border.width;
                    rounding = theme.radius.card;
                    dots_center = true;
                    fade_on_empty = false;
                    inner_color = toRgb colors.surface;
                    outer_color = toRgb colors.accent;
                    check_color = toRgb colors.green;
                    fail_color = toRgb colors.red;
                    font_color = toRgb colors.foreground;
                    font_family = theme.fonts.interface.family;
                    placeholder_text = "Password";
                    check_text = "Authenticating…";
                    fail_text = "$FAIL";
                }
            ];
        };
    };
}
