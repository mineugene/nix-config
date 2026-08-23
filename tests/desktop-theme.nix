{
    pkgs,
    homePackages,
    defaultMode,
    swayncDarkTheme,
    swayncLightTheme,
}:
let
    desktopTheme = builtins.head (builtins.filter (pkg: pkg.name == "desktop-theme") homePackages);
    schemaDir = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
in
pkgs.runCommandLocal "desktop-theme-command-check"
    {
        nativeBuildInputs = [
            desktopTheme
            pkgs.glib
            pkgs.gsettings-desktop-schemas
        ];
    }
    ''
        set -eu

        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$TMPDIR/config"
        export XDG_STATE_HOME="$TMPDIR/state"
        export GSETTINGS_BACKEND=keyfile
        mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$TMPDIR/bin"
        cat > "$TMPDIR/bin/swaync-client" <<'SH'
        #!/bin/sh
        printf '%s\n' "$*" >> "$DESKTOP_THEME_TEST_SWAYNC_LOG"
        exit "''${DESKTOP_THEME_TEST_SWAYNC_STATUS:-0}"
        SH
        chmod +x "$TMPDIR/bin/swaync-client"
        export DESKTOP_THEME_SWAYNC_CLIENT="$TMPDIR/bin/swaync-client"
        export DESKTOP_THEME_TEST_SWAYNC_LOG="$TMPDIR/swaync-client.log"

        test "$(desktop-theme get)" = ${pkgs.lib.escapeShellArg defaultMode}
        test ! -e "$XDG_CONFIG_HOME/swaync/theme.css"

        desktop-theme set dark
        test "$(cat "$XDG_STATE_HOME/mineugene-desktop/theme")" = dark
        cmp ${swayncDarkTheme} "$XDG_CONFIG_HOME/swaync/theme.css"
        test "$(tail -n 1 "$DESKTOP_THEME_TEST_SWAYNC_LOG")" = '--skip-wait --reload-css'
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'"
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface gtk-theme)" = "'Adwaita-dark'"

        desktop-theme set light
        test "$(cat "$XDG_STATE_HOME/mineugene-desktop/theme")" = light
        cmp ${swayncLightTheme} "$XDG_CONFIG_HOME/swaync/theme.css"
        test "$(tail -n 1 "$DESKTOP_THEME_TEST_SWAYNC_LOG")" = '--skip-wait --reload-css'
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface color-scheme)" = "'prefer-light'"
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface gtk-theme)" = "'Adwaita'"

        desktop-theme toggle
        test "$(desktop-theme get)" = dark
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'"

        desktop-theme toggle
        test "$(desktop-theme get)" = light
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface color-scheme)" = "'prefer-light'"

        gsettings --schemadir ${schemaDir} set org.gnome.desktop.interface color-scheme prefer-dark
        gsettings --schemadir ${schemaDir} set org.gnome.desktop.interface gtk-theme Adwaita-dark
        desktop-theme apply
        desktop-theme apply
        test "$(desktop-theme get)" = light
        cmp ${swayncLightTheme} "$XDG_CONFIG_HOME/swaync/theme.css"
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface color-scheme)" = "'prefer-light'"
        test "$(gsettings --schemadir ${schemaDir} get org.gnome.desktop.interface gtk-theme)" = "'Adwaita'"

        if desktop-theme set sepia >/dev/null 2>&1; then
            echo 'desktop-theme accepted an invalid mode' >&2
            exit 1
        fi
        if desktop-theme unknown >/dev/null 2>&1; then
            echo 'desktop-theme accepted an invalid command' >&2
            exit 1
        fi
        test "$(desktop-theme get)" = light

        DESKTOP_THEME_TEST_SWAYNC_STATUS=23 desktop-theme apply
        cmp ${swayncLightTheme} "$XDG_CONFIG_HOME/swaync/theme.css"

        cat > "$TMPDIR/bin/hanging-swaync-client" <<'SH'
        #!/bin/sh
        sleep 10
        SH
        chmod +x "$TMPDIR/bin/hanging-swaync-client"
        DESKTOP_THEME_SWAYNC_CLIENT="$TMPDIR/bin/hanging-swaync-client" \
            timeout 3 desktop-theme apply

        touch "$out"
    ''
