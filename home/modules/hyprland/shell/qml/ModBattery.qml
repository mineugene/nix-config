import QtQuick

// A laptop-only cell: it is hidden entirely when no battery exists. The ring
// carries the charge percent at one-percent resolution and the severity tint
// the hardware rings use; the icon only states charging, full, or a ten-percent
// bucket of discharge.
BarControl {
    id: root

    visible: Power.battery.present === true
    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    tip: Desktop.popup === "battery" ? "" : Power.batteryTooltip()
    onLeftClicked: Desktop.toggle("battery")

    Ring {
        anchors.fill: parent
        value: Power.batteryRingValue()
        arc: {
            const severity = Power.batterySeverity();
            return severity === "critical" ? Tokens.c.red : severity === "warning" ? Tokens.c.yellow : root.tint;
        }

        BarIcon {
            anchors.fill: parent
            icon: Power.batteryIcon()
            color: root.tint
        }
    }
}