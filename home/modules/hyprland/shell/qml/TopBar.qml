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

        ModHardware {}
        Pill {
            ModWifi {}
            ModBluetooth {}
            ModEthernet {}
            AudioRing {
                menuName: "audio-output"
                volume: Audio.sinkVolume
                icon: !Audio.available ? "\u{F026}" : Audio.sinkMuted ? "\u{EEE8}" : Audio.sinkVolume === 0 ? "\u{F026}" : Audio.sinkVolume < 34 ? "\u{F027}" : Audio.sinkVolume < 67 ? "\u{EFCF}" : "\u{F028}"
                tooltip: !Audio.available ? "Audio status unavailable" : Audio.sinkMuted ? "Output muted · middle-click to unmute" : "Output " + Audio.sinkVolume + "% · " + Audio.sinkLabel + " · middle-click to mute"
                onToggleMute: Audio.toggleMute(Audio.sink)
                onChange: delta => Audio.step(Audio.sink, delta)
            }
            AudioRing {
                visible: Audio.sourceAvailable
                menuName: "audio-input"
                volume: Audio.sourceVolume
                icon: Audio.sourceMuted ? "\u{F131}" : "\u{F130}"
                tooltip: Audio.sourceMuted ? "Microphone muted · middle-click to unmute" : "Microphone " + Audio.sourceVolume + "%" + (Audio.sourceClient ? " · in use by " + Audio.sourceClient : "") + " · middle-click to mute"
                onToggleMute: Audio.toggleMute(Audio.source)
                onChange: delta => Audio.step(Audio.source, delta)
            }
            ModPowerProfile {}
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
