import QtQuick
import QtQuick.Layouts

// One stream: a mute button, a volume slider, and a collapsible list of the
// default devices.
PopupSection {
    id: root

    property bool sinks: true
    property var node: null
    property bool available: false
    property int volume: 0
    property string glyph: ""
    property string label: ""
    property var devices: []
    property bool expanded: false

    Connections {
        target: Desktop
        function onPopupChanged() {
            if (Desktop.popup !== "audio")
                root.expanded = false;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        AudioControl {
            square: true
            text: root.glyph
            enabled: root.available
            onClicked: Audio.toggleMute(root.node)
        }
        VolumeSlider {
            id: slider
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: root.available
            value: root.volume
            onValueCommitted: value => Audio.setVolume(root.node, value)
        }
        PopupText {
            text: slider.value + "%"
            font.family: Tokens.monoFamily
        }
    }

    AudioControl {
        Layout.fillWidth: true
        text: "Default: " + root.label
        trailing: root.expanded ? "\u{F107}" : "\u{F105}"
        onClicked: root.expanded = !root.expanded
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.expanded
        spacing: Tokens.spacing.small / 2

        Repeater {
            model: root.devices

            AudioControl {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                active: modelData.active
                onClicked: Audio.setDefault(modelData.node, root.sinks)
            }
        }
    }

    DropdownRule {
        visible: root.expanded
    }
}