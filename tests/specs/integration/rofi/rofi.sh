#!/bin/sh
set -eu
: "${out:?}"

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
printf '%s\n' "${UI_TEST_SELECTION:-0}"
exit "${UI_TEST_STATUS:-0}"
SH
chmod +x "$TMPDIR/bin/confirm-rofi"
# shellcheck disable=SC2016
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
    ui-confirm "Continue?" "$(printf 'Proceed\nMaybe')"
invalid_confirm_status=$?
set -e
test "$invalid_confirm_status" -eq 2

cat > "$TMPDIR/bin/cliphist" <<'SH'
#!/bin/sh
case "${1-}" in
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
if [ "${UI_TEST_CLIPBOARD_CANCEL:-0}" -eq 1 ]; then
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
printf '%s\n' "${UI_TEST_POWER_ACTION:-Power off}"
SH
cat > "$TMPDIR/bin/ui-confirm" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$UI_TEST_CONFIRM_CALL"
exit "${UI_TEST_CONFIRM_STATUS:-0}"
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
# logind answers for hibernation. The stub speaks its reply verbatim
# so the parsing, not a paraphrase of it, is what the test exercises.
cat > "$TMPDIR/bin/busctl" <<'SH'
#!/bin/sh
printf 's "%s"\n' "${UI_TEST_CAN_HIBERNATE:-yes}"
SH
cat > "$TMPDIR/bin/unexpected-power-command" <<'SH'
#!/bin/sh
touch "$UI_TEST_UNEXPECTED_POWER_CALL"
SH
chmod +x \
    "$TMPDIR/bin/busctl" \
    "$TMPDIR/bin/power-rofi" \
    "$TMPDIR/bin/ui-confirm" \
    "$TMPDIR/bin/systemctl" \
    "$TMPDIR/bin/uwsm" \
    "$TMPDIR/bin/lock" \
    "$TMPDIR/bin/unexpected-power-command"

UI_BUSCTL="$TMPDIR/bin/busctl" \
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
printf 'Lock\nLog out\nSleep\nHibernate\nReboot\nPower off\n' > "$TMPDIR/expected-power-menu"
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
printf 'Power off the system?\nPower off\n' > "$TMPDIR/expected-confirm-call"
cmp "$TMPDIR/expected-confirm-call" "$TMPDIR/confirm-call"
printf 'poweroff\n' > "$TMPDIR/expected-systemctl-call"
cmp "$TMPDIR/expected-systemctl-call" "$TMPDIR/systemctl-call"
test ! -e "$TMPDIR/unexpected-power-call"

for power_action in Sleep Hibernate; do
    case "$power_action" in
        Sleep)
            systemctl_action=suspend
            confirmation='Suspend the system?'
            affirmative=Suspend
            ;;
        Hibernate)
            systemctl_action=hibernate
            confirmation='Hibernate the system?'
            affirmative=Hibernate
            ;;
    esac
    UI_CONFIRM="$TMPDIR/bin/ui-confirm" \
        UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
        UI_LOCK="$TMPDIR/bin/unexpected-power-command" \
        UI_ROFI="$TMPDIR/bin/power-rofi" \
        UI_SYSTEMCTL="$TMPDIR/bin/systemctl" \
        UI_TEST_CONFIRM_CALL="$TMPDIR/$systemctl_action-confirm-call" \
        UI_TEST_POWER_ACTION="$power_action" \
        UI_TEST_POWER_ARGS="$TMPDIR/$systemctl_action-power-args" \
        UI_TEST_POWER_MENU="$TMPDIR/$systemctl_action-power-menu" \
        UI_TEST_SYSTEMCTL_CALL="$TMPDIR/$systemctl_action-systemctl-call" \
        UI_TEST_THEME_CALL="$TMPDIR/$systemctl_action-theme-call" \
        UI_TEST_UNEXPECTED_POWER_CALL="$TMPDIR/unexpected-power-call" \
        UI_UWSM="$TMPDIR/bin/unexpected-power-command" \
        XDG_CONFIG_HOME="$TMPDIR/config" \
        ui-power
    printf '%s\n%s\n' "$confirmation" "$affirmative" > "$TMPDIR/$systemctl_action-expected-confirm"
    cmp "$TMPDIR/$systemctl_action-expected-confirm" "$TMPDIR/$systemctl_action-confirm-call"
    test "$(cat "$TMPDIR/$systemctl_action-systemctl-call")" = "$systemctl_action"
    test ! -e "$TMPDIR/unexpected-power-call"
done

UI_BUSCTL="$TMPDIR/bin/busctl" \
    UI_CONFIRM="$TMPDIR/bin/ui-confirm" \
    UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
    UI_LOCK="$TMPDIR/bin/unexpected-power-command" \
    UI_ROFI="$TMPDIR/bin/power-rofi" \
    UI_SYSTEMCTL="$TMPDIR/bin/systemctl" \
    UI_TEST_CONFIRM_CALL="$TMPDIR/denied-confirm-call" \
    UI_TEST_CONFIRM_STATUS=1 \
    UI_TEST_POWER_ACTION='Reboot' \
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

UI_BUSCTL="$TMPDIR/bin/busctl" \
    UI_CONFIRM="$TMPDIR/bin/ui-confirm" \
    UI_DESKTOP_THEME="$TMPDIR/bin/desktop-theme" \
    UI_LOCK="$TMPDIR/bin/unexpected-power-command" \
    UI_ROFI="$TMPDIR/bin/power-rofi" \
    UI_SYSTEMCTL="$TMPDIR/bin/unexpected-power-command" \
    UI_TEST_CONFIRM_CALL="$TMPDIR/logout-confirm-call" \
    UI_TEST_POWER_ACTION='Log out' \
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
    UI_TEST_POWER_ACTION='Lock' \
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
