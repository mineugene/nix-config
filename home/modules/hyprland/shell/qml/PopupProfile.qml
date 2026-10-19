import QtQuick

DesktopPopup {
    id: popup

    name: "profile"
    compact: true
    gap: Tokens.spacing.small / 2

    // Each row hands the action to ui-power, which outlives the click and acts
    // once confirmed. Dismissal runs at once, so a popup left open when the
    // machine suspends cannot reappear on resume.
    component ProfileAction: PopupAction {
        required property string action
        onTriggered: {
            Desktop.run(["ui-power", action]);
            Desktop.closeAll();
        }
    }

    ProfileAction {
        text: "Lock"
        action: "lock"
    }
    ProfileAction {
        text: "Log out"
        action: "logout"
    }
    ProfileAction {
        text: "Suspend"
        action: "suspend"
    }
    // An action the machine cannot carry out is worse than a missing one: it
    // fails silently well after the menu has closed.
    ProfileAction {
        visible: Desktop.canHibernate
        text: "Hibernate"
        action: "hibernate"
    }
    ProfileAction {
        text: "Reboot"
        action: "reboot"
    }
    ProfileAction {
        text: "Power off"
        action: "poweroff"
    }
}
