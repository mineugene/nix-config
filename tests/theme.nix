{
    ghostty,
    pkgs,
    theme,
    themeFiles,
}:
let
    scssTokens = themeFiles."mineugene-desktop/theme/tokens.scss".source;
    rasiTokens = themeFiles."mineugene-desktop/theme/tokens.rasi".source;

    semanticKeys = [
        "accent"
        "accentAlt"
        "background"
        "border"
        "cyan"
        "foreground"
        "green"
        "muted"
        "red"
        "surface"
        "surfaceAlt"
        "surfaceHover"
        "yellow"
    ];
in
assert builtins.attrNames theme.colors.dark == semanticKeys;
assert builtins.attrNames theme.colors.light == semanticKeys;
assert theme.colors.dark.background == "#1a1b26";
assert ghostty.settings.theme == [ "light:mineugene-light,dark:mineugene-dark" ];
assert ghostty.settings."minimum-contrast" == [ 0.3 ];
assert ghostty.settings."window-theme" == [ "system" ];
assert ghostty.themes.mineugene-dark.background == [ theme.colors.dark.background ];
assert ghostty.themes.mineugene-dark.foreground == [ theme.colors.dark.foreground ];
# Upstream tokyonight night values (folke/tokyonight.nvim extras/ghostty).
assert ghostty.themes.mineugene-dark.foreground == [ "#c0caf5" ];
assert ghostty.themes.mineugene-dark.cursor-color == [ "#c0caf5" ];
assert ghostty.themes.mineugene-dark.selection-background == [ "#283457" ];
assert ghostty.themes.mineugene-dark.selection-foreground == [ "#c0caf5" ];
assert
    ghostty.themes.mineugene-dark.palette == [
        "0=#15161e"
        "1=#f7768e"
        "2=#9ece6a"
        "3=#e0af68"
        "4=#7aa2f7"
        "5=#bb9af7"
        "6=#7dcfff"
        "7=#a9b1d6"
        "8=#414868"
        "9=#ff899d"
        "10=#9fe044"
        "11=#faba4a"
        "12=#8db0ff"
        "13=#c7a9ff"
        "14=#a4daff"
        "15=#c0caf5"
    ];
assert ghostty.themes.mineugene-light.background == [ theme.colors.light.background ];
assert ghostty.themes.mineugene-light.foreground == [ theme.colors.light.foreground ];
assert
    theme.fonts.interface == {
        family = "IosevkaNF";
        size = 13;
    };
assert theme.fonts.monospace.family == "IosevkaTermNF";
# The package backs the build-time icon metrics, so it must supply the family
# named above. Checked by name because this test's pkgs lacks the font overlay.
assert theme.fonts.monospace.package.pname == "iosevka-term-nf";
assert
    theme.radius == {
        small = 4;
        card = 6;
        pill = 999;
    };
assert theme.border.width == 1;
assert
    theme.spacing == {
        small = 8;
        normal = 16;
        large = 24;
    };
assert
    theme.bar == {
        height = 38;
        outerMargin = 6;
    };
assert theme.popup.padding == 24;
assert
    theme.animation == {
        fast = 100;
        normal = 200;
        slow = 300;
    };
pkgs.runCommandLocal "desktop-theme-check"
    {
        inherit
            rasiTokens
            scssTokens
            ;
    }
    ''
        set -eu

        require_line() {
            file=$1
            line=$2
            if ! grep -Fqx -- "$line" "$file"; then
                printf 'missing line in %s: %s\n' "$file" "$line" >&2
                exit 1
            fi
        }

        require_line "$scssTokens" '$background: #1a1b26;'
        require_line "$scssTokens" '$surface-alt: #0c0e14;'
        require_line "$scssTokens" '$dark-surface-alt: #0c0e14;'
        require_line "$scssTokens" '$dark-accent-alt: #bb9af7;'
        require_line "$scssTokens" '$dark-red: #f7768e;'
        require_line "$scssTokens" '$light-surface-alt: #ececf2;'
        require_line "$scssTokens" '$light-accent-alt: #6f42a6;'
        require_line "$scssTokens" '$light-red: #8c4351;'
        require_line "$scssTokens" '$font-interface-family: "IosevkaNF";'
        require_line "$scssTokens" '$radius-card: 6px;'
        require_line "$scssTokens" '$animation-normal: 200ms;'

        require_line "$rasiTokens" '    background: #1a1b26;'
        require_line "$rasiTokens" '    surface-alt: #0c0e14;'
        require_line "$rasiTokens" '    font-interface-family: "IosevkaNF";'
        require_line "$rasiTokens" '    radius-card: 6px;'
        require_line "$rasiTokens" '    animation-normal-ms: 200;'

        touch "$out"
    ''
