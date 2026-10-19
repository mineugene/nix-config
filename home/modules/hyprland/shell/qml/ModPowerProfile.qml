import QtQuick

// The profile cell appears only when the daemon is both configured and
// answering. Left-click is inert; right-click opens the profile dropdown and
// middle-click cycles the three standard profiles.
BarControl {
    id: root

    visible: Tokens.powerProfiles && Power.profileAvailable
    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    tip: Desktop.popup === "power-profile" ? "" : Power.profileTooltip()
    onRightClicked: Desktop.toggle("power-profile")
    onMiddleClicked: Power.cycle()

    BarIcon {
        anchors.fill: parent
        icon: Power.profileIcon()
        color: root.tint
    }
}