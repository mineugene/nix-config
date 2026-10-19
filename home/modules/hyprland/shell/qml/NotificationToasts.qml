import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The newest notifications, stacked under the bar. The window is only as big
// as the stack, so the rest of the screen keeps its clicks.
PanelWindow {
    screen: Desktop.screen
    visible: Notifications.toasts.length > 0 && Desktop.popup !== "notifications"
    anchors {
        top: true
        right: true
    }
    margins.top: Tokens.panelTopInset
    margins.right: Tokens.spacing.small
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    implicitWidth: Tokens.popupWidth.notifications
    implicitHeight: stack.implicitHeight
    WlrLayershell.namespace: "shell-notification"
    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
        id: stack
        width: parent.width
        spacing: Tokens.spacing.small

        Repeater {
            model: Notifications.toasts

            NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                notification: modelData
                toast: true
            }
        }
    }
}
