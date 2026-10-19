import QtQuick

// One power cell: it reports charge when the host has a battery and the daemon's
// profile when it does not, so an AC-only host keeps the profile control. The
// ring carries the charge percent at one-percent resolution, green while the
// adapter is attached, and the severity tint on a discharging cell; the glyph
// states the battery in ten-percent buckets, or the profile with no battery to
// report. The glyph stands outside the ring so a quiet bar can drop the ring
// alone.
BarControl {
    id: root

    readonly property bool hasBattery: Power.battery.present === true

    visible: hasBattery || Power.profileAvailable
    base: Bar.foreground
    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    tip: {
        if (Desktop.popup === "battery")
            return "";
        return hasBattery ? Power.batteryTooltip() : Power.profileTooltip();
    }
    onLeftClicked: Desktop.toggle("battery")
    onMiddleClicked: Power.cycle()

    Ring {
        anchors.fill: parent
        visible: Bar.shown && root.hasBattery
        value: Power.batteryRingValue()
        arc: {
            const severity = Power.batterySeverity();
            if (severity === "critical")
                return Tokens.c.red;
            if (severity === "warning")
                return Tokens.c.yellow;
            return Power.batteryPlugged() ? Tokens.c.green : root.tint;
        }
    }

    BarIcon {
        anchors.fill: parent
        icon: root.hasBattery ? Power.batteryIcon() : Power.profileIcon()
        color: root.tint
    }
}
