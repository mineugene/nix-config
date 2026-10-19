pragma Singleton

import QtQuick
import Quickshell

Singleton {
    JsonStream {
        id: stream
        command: ["shell-hardware-status"]
    }

    readonly property var status: stream.value ?? ({})
    readonly property var cpu: status.cpu ?? ({})
    readonly property var gpu: status.gpu ?? ({})
    readonly property var memory: status.memory ?? ({})
    readonly property var storage: status.storage ?? ({})
    readonly property var cooling: status.cooling ?? ({})
    readonly property real uptime: status.uptime_seconds ?? -1

    readonly property bool gpuPresent: gpu.present === true
    readonly property bool coolingAvailable: cooling.available === true
}