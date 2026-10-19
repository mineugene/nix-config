import QtQuick

// The profile dropdown: the daemon's standard profiles, with the active one
// checked. Selecting another applies it and dismisses the menu.
DesktopPopup {
    id: popup

    name: "power-profile"
    compact: true
    gap: Tokens.spacing.small / 2

    Repeater {
        model: Power.profileNames

        PopupAction {
            required property string modelData
            text: (Power.profile.active === modelData ? "✓ " : "") + Power.profileLabel(modelData)
            onTriggered: {
                Power.setProfile(modelData);
                Desktop.closeAll();
            }
        }
    }
}