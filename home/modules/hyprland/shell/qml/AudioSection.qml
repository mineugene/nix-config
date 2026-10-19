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

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small / 2

        AudioControl {
            square: true
            text: root.glyph
            enabled: root.available
            onClicked: Audio.toggleMute(root.node)
        }
        VolumeSlider {
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: root.available
            value: root.volume
            onMoved: Audio.setVolume(root.node, value)
        }
        PopupText {
            text: root.volume + "%"
            font.family: Tokens.monoFamily
        }
    }

    AudioControl {
        Layout.fillWidth: true
        glyph: true
        text: root.expanded ? "\u{F0D7}" : "\u{F0DA}"
        onClicked: root.expanded = !root.expanded
    }

    PopupText {
        Layout.fillWidth: true
        visible: !root.expanded
        text: root.label
        elide: Text.ElideRight
        color: Tokens.c.muted
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
}