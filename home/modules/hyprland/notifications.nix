{
    config,
    lib,
    pkgs,
    ...
}:
let
    theme = config.mine.desktop.theme;
    swayncPackage = pkgs.swaynotificationcenter.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./swaync/responsive-notifications.patch ];
    });
    swayncStyle = pkgs.replaceVars ./swaync/style.css {
        animationFast = toString theme.animation.fast;
        animationNormal = toString theme.animation.normal;
        barOuterMargin = toString theme.bar.outerMargin;
        borderWidth = toString theme.border.width;
        interfaceFontFamily = theme.fonts.interface.family;
        interfaceFontSize = toString theme.fonts.interface.size;
        popupPadding = toString theme.popup.padding;
        radiusCard = toString theme.radius.card;
        radiusPill = toString theme.radius.pill;
        radiusSmall = toString theme.radius.small;
        spacingLarge = toString theme.spacing.large;
        spacingNormal = toString theme.spacing.normal;
        spacingSmall = toString theme.spacing.small;
    };
in
{
    services = {
        cliphist.enable = true;
        dunst.enable = lib.mkForce false;
        polkit-gnome.enable = true;
        swaync = {
            enable = true;
            package = swayncPackage;
            style = swayncStyle;
            settings = {
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
                control-center-margin-top = theme.spacing.small;
                control-center-margin-bottom = theme.bar.outerMargin;
                control-center-margin-right = theme.bar.outerMargin;
                control-center-margin-left = theme.bar.outerMargin;
                fit-to-screen = false;
                control-center-width = 480;
                control-center-height = 640;

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
                transition-time = theme.animation.normal;
                relative-timestamps = true;
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
        };
    };

    systemd.user.services.swaync.Unit.After = [ "desktop-theme.service" ];
}
