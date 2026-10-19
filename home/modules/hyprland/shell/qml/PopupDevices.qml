import QtQuick
import QtQuick.Layouts

// The compact default-device menu: outputs for the speaker, inputs for the
// microphone. The current default has a check mark; selecting another
// dismisses the menu.
DesktopPopup {
    id: popup

    property bool sinks: true
    readonly property var devices: sinks ? Audio.outputs : Audio.inputs

    widthKey: "audioDevices"
    compact: true
    gap: Tokens.spacing.small / 2

    PopupAction {
        visible: popup.devices.length === 0
        enabled: false
        text: "No devices available"
    }

    Repeater {
        model: popup.devices

        PopupAction {
            id: row
            required property var modelData
            text: (modelData.active ? "✓ " : "") + modelData.label
            onTriggered: {
                Audio.setDefault(modelData.node, popup.sinks);
                Desktop.closeAll();
            }

            Tip {
                target: row
                text: row.modelData.label
                hovered: hover.hovered
            }
            HoverHandler {
                id: hover
            }
        }
    }
}
