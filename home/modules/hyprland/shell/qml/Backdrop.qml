import QtQuick
import Quickshell
import Quickshell.Wayland

// Covers the usable area, which already excludes the bar's exclusive zone.
// Popups sit on the overlay layer above it, so any click on the desktop
// dismisses them. It never takes keyboard focus.
PanelWindow {
    screen: Desktop.screen
    visible: Desktop.popup !== ""
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: "shell-popup-backdrop"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: Desktop.closeAll()
    }
}
