import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    screen: Desktop.screen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Tokens.barHeight
    // The bar owns the gap to the windows: it reserves its height plus the gap,
    // so the compositor adds no top outer gap.
    exclusiveZone: Tokens.barHeight + Tokens.barGap
    color: Tokens.c.barBackground
    WlrLayershell.namespace: "shell-bar"

    // Empty canvas dismisses an open popup. It sits beneath the controls, so a
    // click on a control opens its popup instead of reaching this area.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: Desktop.closeAll()
    }

    // Controls sit above the canvas and take its hover, so the pointer hands
    // itself to the collapse in a passive handler that stays out of their way.
    HoverHandler {
        id: pointer

        onHoveredChanged: Bar.hovered = hovered
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        ModMenu {
            icon: "\u{F44E}"
            popup: "menu"
            tip: "Open desktop menu"
        }
        ModWorkspaces {}
        ModWindow {}
    }

    ModClock {
        anchors.centerIn: parent
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        // The ring meters are the one cluster a quiet bar hides rather than
        // mutes: they report readings, not state, and their helper polls.
        Slot {
            open: Bar.shown

            ModHardware {}
        }
        // The status controls take an island's inner gap so they still read as
        // one cluster; the gaps at the cluster's edges stay at the bar's step.
        Row {
            spacing: Tokens.spacing.small / 4

            ModWifi {}
            ModBluetooth {}
            ModEthernet {}
            ModAudio {}
            ModBattery {}
        }
        ModNotifications {}
        ModMenu {
            icon: "\u{F007}"
            popup: "profile"
            tip: Tokens.username + " · power menu"
        }
    }
}
