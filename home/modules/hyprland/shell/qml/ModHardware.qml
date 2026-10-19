import QtQuick

Pill {
    id: root

    // Every ring reports a reading in its own units against its own range, so
    // the arc and the alert colour are derived here rather than at each call
    // site. A reading outside the range clamps to a full or empty arc.
    component HardwareRing: Ring {
        id: ring

        property string icon: ""
        property var reading: null
        property real minimum: 0
        property real maximum: 100
        property real warning: 60
        property real critical: 85
        property real adjust: 0
        readonly property bool known: reading !== null && reading !== undefined && reading >= 0
        readonly property color tone: !known ? Tokens.c.muted : reading >= critical ? Tokens.c.red : reading >= warning ? Tokens.c.yellow : control.tint

        value: !known || reading <= minimum ? 0 : reading >= maximum ? 100 : (reading - minimum) * 100 / (maximum - minimum)
        arc: tone

        BarIcon {
            anchors.fill: parent
            icon: ring.icon
            color: control.tint
            adjust: ring.adjust
        }
    }

    HardwareRing {
        icon: "\u{F2DB}"
        reading: Hardware.cpu.usage
    }
    HardwareRing {
        visible: Hardware.gpuPresent
        icon: "\u{F0FB2}"
        adjust: 2
        reading: Hardware.gpu.usage
    }
    HardwareRing {
        icon: "\u{EFC5}"
        adjust: -2
        reading: Hardware.memory.usage
    }
    // A fan speed has no severity of its own, so the ring only meters it and
    // never leaves the theme tint.
    HardwareRing {
        visible: Hardware.coolingAvailable
        icon: "\u{F0210}"
        reading: Hardware.cooling.cpu_fan_rpm
        maximum: 2000
        warning: 10000
        critical: 20000
    }

    BarControl {
        id: control
        parent: root
        anchors.fill: parent
        z: 10
        tip: Desktop.popup === "hardware" ? "" : "Open hardware dashboard"
        onLeftClicked: Desktop.toggle("hardware")
    }
}