{
    homePackages,
    pkgs,
    rofiFiles,
}:
let
    baseTheme = rofiFiles."rofi/themes/base.rasi".source;
    darkPalette = rofiFiles."rofi/themes/dark.rasi".source;
    lightPalette = rofiFiles."rofi/themes/light.rasi".source;
    launcherTheme = rofiFiles."rofi/themes/launcher.rasi".source;
    confirmTheme = rofiFiles."rofi/themes/confirm.rasi".source;
    clipboardTheme = rofiFiles."rofi/themes/clipboard.rasi".source;
    powerTheme = rofiFiles."rofi/themes/power.rasi".source;
    launcherDark = rofiFiles."rofi/themes/launcher-dark.rasi".source;
    launcherLight = rofiFiles."rofi/themes/launcher-light.rasi".source;
    confirmDark = rofiFiles."rofi/themes/confirm-dark.rasi".source;
    confirmLight = rofiFiles."rofi/themes/confirm-light.rasi".source;
    clipboardDark = rofiFiles."rofi/themes/clipboard-dark.rasi".source;
    clipboardLight = rofiFiles."rofi/themes/clipboard-light.rasi".source;
    powerDark = rofiFiles."rofi/themes/power-dark.rasi".source;
    powerLight = rofiFiles."rofi/themes/power-light.rasi".source;
    uiClipboard = builtins.head (
        builtins.filter (package: package.name == "ui-clipboard") homePackages
    );
    uiConfirm = builtins.head (builtins.filter (package: package.name == "ui-confirm") homePackages);
    uiLauncher = builtins.head (builtins.filter (package: package.name == "ui-launcher") homePackages);
    uiPower = builtins.head (builtins.filter (package: package.name == "ui-power") homePackages);
in
pkgs.runCommandLocal "rofi-command-check"
    {
        inherit
            baseTheme
            clipboardDark
            clipboardLight
            clipboardTheme
            confirmDark
            confirmLight
            confirmTheme
            darkPalette
            launcherDark
            launcherLight
            launcherTheme
            lightPalette
            powerDark
            powerLight
            powerTheme
            ;
        nativeBuildInputs = [
            uiClipboard
            uiConfirm
            uiLauncher
            uiPower
        ];
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

        require_line "$darkPalette" '    surface: #16161e;'
        require_line "$darkPalette" '    surface-translucent: #16161ecc;'
        require_line "$darkPalette" '    border: #292e42;'
        require_line "$darkPalette" '    accent: #7aa2f7;'
        require_line "$darkPalette" '    font-interface: "IosevkaNF 13";'
        require_line "$darkPalette" '    radius-card: 6px;'
        require_line "$darkPalette" '    radius-pill: 999px;'
        require_line "$darkPalette" '    spacing-normal: 8px;'
        require_line "$lightPalette" '    surface: #ffffff;'
        require_line "$lightPalette" '    surface-translucent: #ffffffcc;'
        require_line "$lightPalette" '    border: #c4c6d0;'
        require_line "$lightPalette" '    accent: #34548a;'

        require_line "$baseTheme" '    transparency: "real";'
        require_line "$baseTheme" '    background-color: @surface-translucent;'
        require_line "$baseTheme" '    location: north;'
        require_line "$baseTheme" '    anchor: north;'
        require_line "$baseTheme" '    y-offset: 40%;'
        require_line "$baseTheme" '    width: 92%;'
        require_line "$baseTheme" '@media ( min-width: 700 px ) {'
        require_line "$baseTheme" '        width: 640px;'
        require_line "$baseTheme" '@media ( min-width: 1440 px ) {'
        require_line "$baseTheme" '        width: 720px;'
        require_line "$baseTheme" '@media ( min-width: 2560 px ) {'
        require_line "$baseTheme" '        width: 840px;'
        if grep -Eq 'box-shadow|filter:[[:space:]]*blur' "$baseTheme"; then
            echo 'Rofi must not add theme-level shadows or blur filters' >&2
            exit 1
        fi

        for layout in "$baseTheme" "$launcherTheme" "$confirmTheme" "$clipboardTheme" "$powerTheme"; do
            if grep -Eq '#[[:xdigit:]]{6}' "$layout"; then
                printf 'hard-coded palette literal in %s\n' "$layout" >&2
                exit 1
            fi
        done
        require_line "$launcherTheme" '    show-icons: true;'
        require_line "$launcherTheme" '    lines: 8;'
        require_line "$confirmTheme" '    children: [ message, listview ];'
        require_line "$confirmTheme" '    markup: false;'
        require_line "$confirmTheme" '    lines: 2;'
        require_line "$clipboardTheme" '    lines: 10;'
        require_line "$powerTheme" '    children: [ listview ];'
        require_line "$powerTheme" '    lines: 4;'

        check_entrypoint() {
            file=$1
            mode=$2
            variant=$3
            require_line "$file" "@import \"$mode.rasi\""
            require_line "$file" '@import "base.rasi"'
            require_line "$file" "@import \"$variant.rasi\""
        }
        check_entrypoint "$launcherDark" dark launcher
        check_entrypoint "$launcherLight" light launcher
        check_entrypoint "$confirmDark" dark confirm
        check_entrypoint "$confirmLight" light confirm
        check_entrypoint "$clipboardDark" dark clipboard
        check_entrypoint "$clipboardLight" light clipboard
        check_entrypoint "$powerDark" dark power
        check_entrypoint "$powerLight" light power

        ui-launcher --help >/dev/null

        mkdir -p "$TMPDIR/bin" "$TMPDIR/config"
        cat > "$TMPDIR/bin/rofi" <<'SH'
        #!/bin/sh
        printf '%s\n' "$@" > "$UI_TEST_LOG"
        SH
        cat > "$TMPDIR/bin/desktop-theme" <<'SH'
        #!/bin/sh
        printf '%s\n' "$@" > "$UI_TEST_THEME_CALL"
        printf 'light\n'
        SH
        chmod +x "$TMPDIR/bin/rofi" "$TMPDIR/bin/desktop-theme"

        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/rofi" \
            UI_TEST_LOG="$TMPDIR/launcher-args" \
            UI_TEST_THEME_CALL="$TMPDIR/launcher-theme-call" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-launcher
        cat > "$TMPDIR/expected-launcher-args" <<EOF
        -show
        drun
        -monitor
        -1
        -theme
        $TMPDIR/config/rofi/themes/launcher-light.rasi
        EOF
        cmp "$TMPDIR/expected-launcher-args" "$TMPDIR/launcher-args"
        test "$(cat "$TMPDIR/launcher-theme-call")" = get

        cat > "$TMPDIR/bin/confirm-rofi" <<'SH'
        #!/bin/sh
        cat > "$UI_TEST_STDIN"
        printf '%s\n' "$@" > "$UI_TEST_LOG"
        printf '%s\n' "''${UI_TEST_SELECTION:-0}"
        exit "''${UI_TEST_STATUS:-0}"
        SH
        chmod +x "$TMPDIR/bin/confirm-rofi"
        message='Restart? $(touch '"$TMPDIR"'/injected)'
        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/confirm-rofi" \
            UI_TEST_LOG="$TMPDIR/confirm-args" \
            UI_TEST_STDIN="$TMPDIR/confirm-stdin" \
            UI_TEST_THEME_CALL="$TMPDIR/confirm-theme-call" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-confirm "$message"
        test ! -e "$TMPDIR/injected"
        printf 'Yes\nNo\n' > "$TMPDIR/expected-confirm-stdin"
        cmp "$TMPDIR/expected-confirm-stdin" "$TMPDIR/confirm-stdin"
        printf '%s\n' \
            -dmenu \
            -p Confirm \
            -mesg "$message" \
            -monitor -1 \
            -theme "$TMPDIR/config/rofi/themes/confirm-light.rasi" \
            -no-custom \
            -kb-cancel Escape \
            -format i \
            -selected-row 0 > "$TMPDIR/expected-confirm-args"
        cmp "$TMPDIR/expected-confirm-args" "$TMPDIR/confirm-args"
        test "$(cat "$TMPDIR/confirm-theme-call")" = get

        set +e
        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/confirm-rofi" \
            UI_TEST_LOG="$TMPDIR/no-confirm-args" \
            UI_TEST_SELECTION=1 \
            UI_TEST_STDIN="$TMPDIR/no-confirm-stdin" \
            UI_TEST_THEME_CALL="$TMPDIR/no-confirm-theme-call" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-confirm "Continue?"
        no_confirm_status=$?
        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/confirm-rofi" \
            UI_TEST_LOG="$TMPDIR/cancel-confirm-args" \
            UI_TEST_STATUS=23 \
            UI_TEST_STDIN="$TMPDIR/cancel-confirm-stdin" \
            UI_TEST_THEME_CALL="$TMPDIR/cancel-confirm-theme-call" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-confirm "Continue?"
        cancel_confirm_status=$?
        set -e
        test "$no_confirm_status" -eq 1
        test "$cancel_confirm_status" -eq 1

        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_TEST_THEME_CALL="$TMPDIR/custom-confirm-theme-call" \
            UI_ROFI="$TMPDIR/bin/confirm-rofi" \
            UI_TEST_LOG="$TMPDIR/custom-confirm-args" \
            UI_TEST_STDIN="$TMPDIR/custom-confirm-stdin" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-confirm "Shut down the system?" "Shut down"
        printf 'Shut down\nNo\n' > "$TMPDIR/expected-custom-confirm-stdin"
        cmp "$TMPDIR/expected-custom-confirm-stdin" "$TMPDIR/custom-confirm-stdin"

        set +e
        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/confirm-rofi" \
            UI_TEST_LOG="$TMPDIR/invalid-confirm-args" \
            UI_TEST_STDIN="$TMPDIR/invalid-confirm-stdin" \
            UI_TEST_THEME_CALL="$TMPDIR/invalid-confirm-theme-call" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-confirm "Continue?" $'Proceed\nMaybe'
        invalid_confirm_status=$?
        set -e
        test "$invalid_confirm_status" -eq 2

        cat > "$TMPDIR/bin/cliphist" <<'SH'
        #!/bin/sh
        case "''${1-}" in
            list)
                printf '42\t[image/png] binary entry\n'
                ;;
            decode)
                cat > "$UI_TEST_DECODE_INPUT"
                printf 'decoded\000binary'
                ;;
            *) exit 2 ;;
        esac
        SH
        cat > "$TMPDIR/bin/clipboard-rofi" <<'SH'
        #!/bin/sh
        cat > "$UI_TEST_LIST_INPUT"
        printf '%s\n' "$@" > "$UI_TEST_CLIPBOARD_ARGS"
        if [ "''${UI_TEST_CLIPBOARD_CANCEL:-0}" -eq 1 ]; then
            exit 1
        fi
        printf '42\t[image/png] binary entry\n'
        SH
        cat > "$TMPDIR/bin/wl-copy" <<'SH'
        #!/bin/sh
        : > "$UI_TEST_COPY_ARGS"
        for arg in "$@"; do
            printf '%s\n' "$arg" >> "$UI_TEST_COPY_ARGS"
        done
        cat > "$UI_TEST_COPY_INPUT"
        SH
        chmod +x "$TMPDIR/bin/cliphist" "$TMPDIR/bin/clipboard-rofi" "$TMPDIR/bin/wl-copy"

        UI_CLIPHIST="$TMPDIR/bin/cliphist" \
            UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/clipboard-rofi" \
            UI_WL_COPY="$TMPDIR/bin/wl-copy" \
            UI_TEST_CLIPBOARD_ARGS="$TMPDIR/clipboard-args" \
            UI_TEST_COPY_ARGS="$TMPDIR/copy-args" \
            UI_TEST_COPY_INPUT="$TMPDIR/copy-input" \
            UI_TEST_DECODE_INPUT="$TMPDIR/decode-input" \
            UI_TEST_LIST_INPUT="$TMPDIR/list-input" \
            UI_TEST_THEME_CALL="$TMPDIR/clipboard-theme-call" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-clipboard
        printf '42\t[image/png] binary entry\n' > "$TMPDIR/expected-entry"
        cmp "$TMPDIR/expected-entry" "$TMPDIR/list-input"
        cmp "$TMPDIR/expected-entry" "$TMPDIR/decode-input"
        printf 'decoded\000binary' > "$TMPDIR/expected-copy-input"
        cmp "$TMPDIR/expected-copy-input" "$TMPDIR/copy-input"
        test ! -s "$TMPDIR/copy-args"
        printf '%s\n' \
            -dmenu \
            -p Clipboard \
            -monitor -1 \
            -theme "$TMPDIR/config/rofi/themes/clipboard-light.rasi" \
            -no-custom \
            > "$TMPDIR/expected-clipboard-args"
        cmp "$TMPDIR/expected-clipboard-args" "$TMPDIR/clipboard-args"
        test "$(cat "$TMPDIR/clipboard-theme-call")" = get

        set +e
        UI_CLIPHIST="$TMPDIR/bin/cliphist" \
            UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_ROFI="$TMPDIR/bin/clipboard-rofi" \
            UI_TEST_CLIPBOARD_ARGS="$TMPDIR/cancel-clipboard-args" \
            UI_TEST_CLIPBOARD_CANCEL=1 \
            UI_TEST_COPY_ARGS="$TMPDIR/cancel-copy-args" \
            UI_TEST_COPY_INPUT="$TMPDIR/cancel-copy-input" \
            UI_TEST_DECODE_INPUT="$TMPDIR/cancel-decode-input" \
            UI_TEST_LIST_INPUT="$TMPDIR/cancel-list-input" \
            UI_TEST_THEME_CALL="$TMPDIR/cancel-clipboard-theme-call" \
            UI_WL_COPY="$TMPDIR/bin/wl-copy" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-clipboard
        cancel_clipboard_status=$?
        set -e
        test "$cancel_clipboard_status" -ne 0
        test ! -e "$TMPDIR/cancel-copy-input"
        test ! -e "$TMPDIR/cancel-copy-args"

        cat > "$TMPDIR/bin/power-rofi" <<'SH'
        #!/bin/sh
        cat > "$UI_TEST_POWER_MENU"
        printf '%s\n' "$@" > "$UI_TEST_POWER_ARGS"
        printf '%s\n' "''${UI_TEST_POWER_ACTION:-Shutdown}"
        SH
        cat > "$TMPDIR/bin/ui-confirm" <<'SH'
        #!/bin/sh
        printf '%s\n' "$@" > "$UI_TEST_CONFIRM_CALL"
        exit "''${UI_TEST_CONFIRM_STATUS:-0}"
        SH
        cat > "$TMPDIR/bin/systemctl" <<'SH'
        #!/bin/sh
        printf '%s\n' "$@" > "$UI_TEST_SYSTEMCTL_CALL"
        SH
        cat > "$TMPDIR/bin/uwsm" <<'SH'
        #!/bin/sh
        printf '%s\n' "$@" > "$UI_TEST_UWSM_CALL"
        SH
        cat > "$TMPDIR/bin/lock" <<'SH'
        #!/bin/sh
        : > "$UI_TEST_LOCK_CALL"
        for arg in "$@"; do
            printf '%s\n' "$arg" >> "$UI_TEST_LOCK_CALL"
        done
        SH
        cat > "$TMPDIR/bin/unexpected-power-command" <<'SH'
        #!/bin/sh
        touch "$UI_TEST_UNEXPECTED_POWER_CALL"
        SH
        chmod +x \
            "$TMPDIR/bin/power-rofi" \
            "$TMPDIR/bin/ui-confirm" \
            "$TMPDIR/bin/systemctl" \
            "$TMPDIR/bin/uwsm" \
            "$TMPDIR/bin/lock" \
            "$TMPDIR/bin/unexpected-power-command"

        UI_CONFIRM="$TMPDIR/bin/ui-confirm" \
            UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_LOCK="$TMPDIR/bin/unexpected-power-command" \
            UI_ROFI="$TMPDIR/bin/power-rofi" \
            UI_SYSTEMCTL="$TMPDIR/bin/systemctl" \
            UI_TEST_CONFIRM_CALL="$TMPDIR/confirm-call" \
            UI_TEST_POWER_ARGS="$TMPDIR/power-args" \
            UI_TEST_POWER_MENU="$TMPDIR/power-menu" \
            UI_TEST_SYSTEMCTL_CALL="$TMPDIR/systemctl-call" \
            UI_TEST_THEME_CALL="$TMPDIR/power-theme-call" \
            UI_TEST_UNEXPECTED_POWER_CALL="$TMPDIR/unexpected-power-call" \
            UI_UWSM="$TMPDIR/bin/unexpected-power-command" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-power
        printf 'Lock\nLogout\nReboot\nShutdown\n' > "$TMPDIR/expected-power-menu"
        cmp "$TMPDIR/expected-power-menu" "$TMPDIR/power-menu"
        printf '%s\n' \
            -dmenu \
            -p Power \
            -monitor -1 \
            -theme "$TMPDIR/config/rofi/themes/power-light.rasi" \
            -no-custom \
            -selected-row 0 > "$TMPDIR/expected-power-args"
        cmp "$TMPDIR/expected-power-args" "$TMPDIR/power-args"
        test "$(cat "$TMPDIR/power-theme-call")" = get
        printf 'Shut down the system?\nShut down\n' > "$TMPDIR/expected-confirm-call"
        cmp "$TMPDIR/expected-confirm-call" "$TMPDIR/confirm-call"
        printf 'poweroff\n' > "$TMPDIR/expected-systemctl-call"
        cmp "$TMPDIR/expected-systemctl-call" "$TMPDIR/systemctl-call"
        test ! -e "$TMPDIR/unexpected-power-call"

        UI_CONFIRM="$TMPDIR/bin/ui-confirm" \
            UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_LOCK="$TMPDIR/bin/unexpected-power-command" \
            UI_ROFI="$TMPDIR/bin/power-rofi" \
            UI_SYSTEMCTL="$TMPDIR/bin/systemctl" \
            UI_TEST_CONFIRM_CALL="$TMPDIR/denied-confirm-call" \
            UI_TEST_CONFIRM_STATUS=1 \
            UI_TEST_POWER_ACTION=Reboot \
            UI_TEST_POWER_ARGS="$TMPDIR/denied-power-args" \
            UI_TEST_POWER_MENU="$TMPDIR/denied-power-menu" \
            UI_TEST_SYSTEMCTL_CALL="$TMPDIR/denied-systemctl-call" \
            UI_TEST_THEME_CALL="$TMPDIR/denied-power-theme-call" \
            UI_TEST_UNEXPECTED_POWER_CALL="$TMPDIR/unexpected-power-call" \
            UI_UWSM="$TMPDIR/bin/unexpected-power-command" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-power
        printf 'Reboot the system?\nReboot\n' > "$TMPDIR/expected-denied-confirm-call"
        cmp "$TMPDIR/expected-denied-confirm-call" "$TMPDIR/denied-confirm-call"
        test ! -e "$TMPDIR/denied-systemctl-call"
        test ! -e "$TMPDIR/unexpected-power-call"

        UI_CONFIRM="$TMPDIR/bin/ui-confirm" \
            UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_LOCK="$TMPDIR/bin/unexpected-power-command" \
            UI_ROFI="$TMPDIR/bin/power-rofi" \
            UI_SYSTEMCTL="$TMPDIR/bin/unexpected-power-command" \
            UI_TEST_CONFIRM_CALL="$TMPDIR/logout-confirm-call" \
            UI_TEST_POWER_ACTION=Logout \
            UI_TEST_POWER_ARGS="$TMPDIR/logout-power-args" \
            UI_TEST_POWER_MENU="$TMPDIR/logout-power-menu" \
            UI_TEST_THEME_CALL="$TMPDIR/logout-power-theme-call" \
            UI_TEST_UNEXPECTED_POWER_CALL="$TMPDIR/unexpected-power-call" \
            UI_TEST_UWSM_CALL="$TMPDIR/uwsm-call" \
            UI_UWSM="$TMPDIR/bin/uwsm" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-power
        printf 'Log out of this session?\nLog out\n' > "$TMPDIR/expected-logout-confirm-call"
        cmp "$TMPDIR/expected-logout-confirm-call" "$TMPDIR/logout-confirm-call"
        test "$(cat "$TMPDIR/uwsm-call")" = stop
        test ! -e "$TMPDIR/unexpected-power-call"

        UI_CONFIRM="$TMPDIR/bin/unexpected-power-command" \
            UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
            UI_LOCK="$TMPDIR/bin/lock" \
            UI_ROFI="$TMPDIR/bin/power-rofi" \
            UI_SYSTEMCTL="$TMPDIR/bin/unexpected-power-command" \
            UI_TEST_LOCK_CALL="$TMPDIR/lock-call" \
            UI_TEST_POWER_ACTION=Lock \
            UI_TEST_POWER_ARGS="$TMPDIR/lock-power-args" \
            UI_TEST_POWER_MENU="$TMPDIR/lock-power-menu" \
            UI_TEST_THEME_CALL="$TMPDIR/lock-power-theme-call" \
            UI_TEST_UNEXPECTED_POWER_CALL="$TMPDIR/unexpected-power-call" \
            UI_UWSM="$TMPDIR/bin/unexpected-power-command" \
            XDG_CONFIG_HOME="$TMPDIR/config" \
            ui-power
        test -e "$TMPDIR/lock-call"
        test ! -s "$TMPDIR/lock-call"
        test ! -e "$TMPDIR/unexpected-power-call"

        touch "$out"
    ''
