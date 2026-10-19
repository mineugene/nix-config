pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var state: ({
            available: false,
            powered: false,
            connected: false,
            audio: false,
            adapter: ""
        })

    Process {
        id: status
        command: ["shell-bluetooth", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.state = JSON.parse(text);
                } catch (error) {
                    // Keep the last good state.
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!status.running)
            status.running = true
    }

    JsonStream {
        id: devices
        command: ["shell-bluetooth", "watch"]
        enabled: Desktop.popup === "bluetooth"
    }

    readonly property var list: devices.value ?? ({
            scanning: false,
            devices: [],
            paired_online: [],
            paired_offline: [],
            discovered: [],
            discovered_top: []
        })

    readonly property bool busy: toggleJob.busy

    ToggleJob {
        id: toggleJob
        label: "Bluetooth"
    }

    function toggle() {
        const target = !state.powered;
        toggleJob.start(["shell-bluetooth", "toggle"], () => state.powered === target);
    }

    // Rows act on the address, a fixed hex shape, never on the remote-supplied
    // name.
    function run(args) {
        Quickshell.execDetached(["shell-bluetooth"].concat(args));
    }
}
