import QtQuick
import QtQuick.Layouts

DesktopPopup {
    id: popup

    readonly property var adapter: Bluetooth.state
    readonly property var list: Bluetooth.list

    name: "bluetooth"

    component DeviceGroup: ColumnLayout {
        property string heading: ""
        property var devices: []

        Layout.fillWidth: true
        visible: devices.length > 0
        spacing: Tokens.spacing.small / 2

        ListHeading {
            text: parent.heading
        }

        // The row acts on the address, a fixed hex shape, never on the device
        // name: a name is remote-supplied text.
        Repeater {
            model: parent.devices

            ListRow {
                required property var modelData
                text: modelData.name
                connected: modelData.connected
                leading: modelData.audio ? "\u{F00B0}" : "\u{F00AF}"
                trailing: modelData.connected ? "Connected" : modelData.paired ? "Paired" : ""
                onTriggered: {
                    Bluetooth.run([modelData.connected ? "disconnect" : modelData.paired ? "connect" : "pair", modelData.address]);
                    Desktop.closeAll();
                }
            }
        }
    }

    PopupTitle {
        text: "Bluetooth"
    }

    PopupAction {
        text: popup.adapter.powered ? "Turn Bluetooth off" : "Turn Bluetooth on"
        enabled: popup.adapter.available && !Bluetooth.busy
        onTriggered: Bluetooth.toggle()
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: popup.adapter.available && popup.adapter.powered
        spacing: Tokens.spacing.small / 2

        // The adapter is discoverable and pairable only while this popup is
        // open, so the notice states the condition rather than offering an
        // action.
        PopupText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.spacing.small
            wrapMode: Text.WordWrap
            color: Tokens.c.muted
            text: "Your device " + popup.adapter.adapter + " is currently visible to others nearby."
        }

        PopupAction {
            text: popup.list.scanning ? "Scanning for devices" : "Reload"
            enabled: !popup.list.scanning
            onTriggered: Bluetooth.run(["scan"])
        }

        ListHeading {
            visible: popup.list.devices.length === 0
            text: "No devices found"
        }

        DeviceGroup {
            heading: "Paired & online"
            devices: popup.list.paired_online
        }
        DeviceGroup {
            heading: "Paired & offline"
            devices: popup.list.paired_offline
        }
        DeviceGroup {
            heading: "Discovered devices"
            devices: popup.list.discovered_top
            visible: popup.list.discovered.length > 0
        }

        PopupAction {
            visible: popup.list.discovered.length > 6
            text: "Show more"
            onTriggered: {
                Bluetooth.run(["menu"]);
                Desktop.closeAll();
            }
        }
    }
}
