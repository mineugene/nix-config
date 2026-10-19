import QtQuick
import QtQuick.Layouts

DesktopPopup {
    id: popup

    readonly property var wifi: Network.wifi
    readonly property var list: Network.list
    readonly property bool on: wifi.available && wifi.state !== "off"

    function rate(bytes) {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MiB/s" : (bytes / 1024).toFixed(1) + " KiB/s";
    }

    function dash(v) {
        return v === "" || v === null || v === undefined ? " – " : v;
    }

    function rung(signal) {
        return signal < 40 ? "\u{F091F}" : signal < 60 ? "\u{F0922}" : signal < 80 ? "\u{F0925}" : "\u{F0928}";
    }

    name: "wifi"

    PopupTitle {
        text: "Wi-Fi"
    }

    // A blocked radio must still be reachable, so the row stays and refuses
    // only the click when the machine has no wireless interface at all.
    PopupAction {
        text: popup.wifi.state === "off" ? "Turn Wi-Fi on" : "Turn Wi-Fi off"
        enabled: popup.wifi.available && !Network.wifiBusy
        onTriggered: Network.toggleWifi()
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: popup.on
        spacing: Tokens.spacing.small / 2

        PopupAction {
            text: popup.list.scanning ? "Scanning for networks" : "Reload"
            enabled: !popup.list.scanning
            onTriggered: Network.run(["scan"])
        }

        ListHeading {
            visible: popup.list.networks.length === 0
            text: "No networks found"
        }

        // A row selects by list position, never by SSID: an SSID is
        // attacker-supplied text.
        Repeater {
            model: popup.list.top

            ListRow {
                required property var modelData
                text: modelData.ssid
                connected: modelData.connected
                leading: popup.rung(modelData.signal)
                trailing: modelData.security === "open" ? "" : "\u{F033E}"
                onTriggered: {
                    Network.run(modelData.connected ? ["disconnect"] : ["connect", String(modelData.index)]);
                    Desktop.closeAll();
                }
            }
        }

        PopupAction {
            visible: popup.list.networks.length > 6
            text: "Show more"
            onTriggered: {
                Network.run(["menu"]);
                Desktop.closeAll();
            }
        }
    }

    PopupAction {
        visible: popup.on
        text: "Add network"
        onTriggered: {
            Network.run(["add"]);
            Desktop.closeAll();
        }
    }

    PopupSection {
        PopupDetail {
            name: "Interface"
            value: popup.dash(popup.wifi.interface)
        }
        PopupDetail {
            name: "Signal"
            value: (popup.wifi.signal ?? -1) < 0 ? " – " : popup.wifi.signal + "%"
        }
        PopupDetail {
            name: "IPv4"
            value: popup.dash(popup.wifi.ip)
        }
        PopupDetail {
            name: "Download"
            value: popup.rate(popup.wifi.rx_bytes_per_second)
        }
        PopupDetail {
            name: "Upload"
            value: popup.rate(popup.wifi.tx_bytes_per_second)
        }
    }
}
