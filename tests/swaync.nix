{
    darkTheme,
    dunst,
    lightTheme,
    pkgs,
    swaync,
    swayncConfig,
    swayncService,
    swayncStyle,
}:
let
    expectedSettings = {
        ignore-gtk-theme = true;
        positionX = "right";
        positionY = "top";
        layer = "overlay";
        layer-shell = true;
        layer-shell-cover-screen = true;
        cssPriority = "user";
        control-center-positionX = "right";
        control-center-positionY = "top";
        control-center-layer = "overlay";
        control-center-exclusive-zone = true;
        control-center-margin-top = 4;
        control-center-margin-bottom = 6;
        control-center-margin-right = 6;
        control-center-margin-left = 6;
        notification-2fa-action = true;
        notification-inline-replies = true;
        notification-body-image-height = 100;
        notification-body-image-width = 200;
        notification-window-width = 480;
        notification-window-height = -1;
        timeout = 8;
        timeout-low = 5;
        timeout-critical = 0;
        image-visibility = "when-available";
        notification-grouping = true;
        transition-time = 200;
        relative-timestamps = true;
        fit-to-screen = false;
        control-center-width = 480;
        control-center-height = 640;
        keyboard-shortcuts = true;
        hide-on-clear = false;
        hide-on-action = true;
        text-empty = "No notifications";
        script-fail-notify = true;
        widgets = [
            "title"
            "dnd"
            "notifications"
        ];
        widget-config = {
            title = {
                text = "Notifications";
                clear-all-button = true;
                button-text = "Dismiss all";
            };
            dnd.text = "Do not disturb";
            notifications.vexpand = true;
        };
    };
in
assert !dunst.enable;
assert swaync.enable;
assert swaync.package.pname == "SwayNotificationCenter";
assert swaync.settings == expectedSettings;
assert swayncService.Install.WantedBy == [ "graphical-session.target" ];
assert swayncService.Unit.PartOf == [ "graphical-session.target" ];
assert
    swayncService.Unit.After == [
        "graphical-session.target"
        "desktop-theme.service"
    ];
assert swayncService.Service.BusName == "org.freedesktop.Notifications";
assert swayncService.Service.Restart == "on-failure";
pkgs.runCommandLocal "swaync-daemon-check"
    {
        nativeBuildInputs = [
            pkgs.check-jsonschema
            pkgs.glib.dev
        ];
        config = swayncConfig;
        schema = "${swaync.package}/etc/xdg/swaync/configSchema.json";
        inherit darkTheme lightTheme swayncStyle;
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

        check-jsonschema --schemafile "$schema" "$config"
        gresource extract \
            "${swaync.package}/bin/.swaync-wrapped" \
            /org/erikreider/swaync/ui/notification.ui > notification.ui
        grep -Fq '<object class="GtkLabel" id="app_name">' notification.ui
        grep -Fq '<class name="app-name"/>' notification.ui

        require_line "$darkTheme" '    --notification-background: #16161ecc;'
        require_line "$darkTheme" '    --control-center-background: #16161ecc;'
        require_line "$darkTheme" '    --notification-border: #292e42cc;'
        require_line "$darkTheme" '    --foreground: #c0caf5;'
        require_line "$darkTheme" '    --muted: #565f89;'
        require_line "$darkTheme" '    --accent: #7aa2f7;'
        require_line "$darkTheme" '    --critical: #f7768e;'
        require_line "$lightTheme" '    --notification-background: #ffffffcc;'
        require_line "$lightTheme" '    --notification-border: #c4c6d0cc;'
        require_line "$lightTheme" '    --foreground: #1a1b26;'

        require_line "$swayncStyle" '@import url("theme.css");'
        require_line "$swayncStyle" '    --notification-icon-size: 48px;'
        require_line "$swayncStyle" '    --notification-shadow: none;'
        require_line "$swayncStyle" '    font-family: "IosevkaNF";'
        require_line "$swayncStyle" '.floating-notifications .notification {'
        require_line "$swayncStyle" '    min-width: 360px;'
        require_line "$swayncStyle" '    background: var(--notification-background);'
        require_line "$swayncStyle" '    border: 1px solid var(--notification-border);'
        require_line "$swayncStyle" '.notification.critical {'
        require_line "$swayncStyle" '    border-color: var(--critical);'
        require_line "$swayncStyle" '.notification-content .summary {'
        require_line "$swayncStyle" '    font-weight: 700;'
        require_line "$swayncStyle" '.notification-content .body {'
        require_line "$swayncStyle" '    font-weight: 400;'
        require_line "$swayncStyle" '.notification-content .app-name {'
        require_line "$swayncStyle" '    color: var(--muted);'
        require_line "$swayncStyle" '.control-center {'
        require_line "$swayncStyle" '    background: var(--control-center-background);'
        require_line "$swayncStyle" '.widget-title > button:hover,'
        require_line "$swayncStyle" '    background: var(--surface-hover);'
        if grep -E 'box-shadow:' "$swayncStyle" | grep -Ev 'box-shadow: none;' >/dev/null; then
            echo 'SwayNC must not use heavy shadows' >&2
            exit 1
        fi

        touch "$out"
    ''
