import QtQuick

// A bare cell rather than an island: it sits beside the session button with the
// bar's shared spacing on both sides.
BarControl {
    id: notifications

    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    tip: Notifications.dnd ? "Do not disturb enabled · click for notifications; middle-click to disable" : Notifications.count > 0 ? "Uncleared notifications · middle-click for do not disturb" : "No uncleared notifications · middle-click for do not disturb"
    onLeftClicked: Desktop.toggle("notifications")
    onMiddleClicked: Notifications.toggleDnd()

    // The filled glyph is the unread signal; a count beside it would say
    // the same thing twice and widen the control as notifications arrive.
    BarIcon {
        anchors.fill: parent
        icon: Notifications.dnd ? "\u{F15E2}" : Notifications.count > 0 ? "\u{F017A}" : "\u{F0182}"
        color: notifications.tint
    }
}