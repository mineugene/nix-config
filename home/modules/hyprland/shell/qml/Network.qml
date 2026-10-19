pragma Singleton

import QtQuick
import Quickshell

// Wi-Fi and Ethernet are independent links; the listener reports both. A
// control that has not heard from it yet must be hidden rather than claim a
// link that may not exist on this machine.
Singleton {
    id: root

    function seed(kind) {
        return {
            kind: kind,
            available: false,
            state: "unavailable",
            connected: false,
            internet: false,
            interface: "",
            name: "Unavailable",
            signal: null,
            ip: "",
            rx_bytes_per_second: 0,
            tx_bytes_per_second: 0
        };
    }

    JsonStream {
        id: links
        command: ["shell-network-listener", "listen"]
    }

    // The list only refreshes while a scan runs, and the helper stays idle
    // otherwise, so it runs only while its popup is open.
    JsonStream {
        id: scan
        command: ["shell-network-listener", "watch"]
        enabled: Desktop.popup === "wifi"
    }

    readonly property var wifi: links.value?.wifi ?? seed("wifi")
    readonly property var ethernet: links.value?.ethernet ?? seed("ethernet")
    readonly property var list: scan.value ?? ({
            scanning: false,
            networks: [],
            top: []
        })

    // Association has no glyph of its own, so it is drawn as motion: the
    // ladder sweeps up and back down over six frames.
    property int frame: 0

    Timer {
        interval: 180
        running: root.wifi.state === "connecting"
        repeat: true
        onTriggered: root.frame = (root.frame + 1) % 6
    }

    readonly property bool wifiBusy: wifiJob.busy

    ToggleJob {
        id: wifiJob
        label: "Wi-Fi"
    }

    function toggleWifi() {
        const turningOff = wifi.state !== "off";
        wifiJob.start(
            ["shell-network-listener", "wifi", turningOff ? "off" : "on"],
            () => turningOff ? wifi.state === "off" : wifi.state !== "off"
        );
    }

    function run(args) {
        Quickshell.execDetached(["shell-network-listener"].concat(args));
    }
}
