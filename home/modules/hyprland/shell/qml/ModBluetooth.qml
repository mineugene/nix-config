import QtQuick

// The adapter is present either way, so an off radio keeps its control and
// says it is off; hiding it would remove the only way to switch it back on.
BarControl {
    id: root

    readonly property var adapter: Bluetooth.state

    visible: adapter.available
    enabled: !Bluetooth.busy
    opacity: enabled ? 1 : 0.5
    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    tip: Desktop.popup === "bluetooth" ? "" : adapter.adapter + " · " + (!adapter.powered ? "disabled" : adapter.connected ? "connected" : "enabled")
    onLeftClicked: Desktop.toggle("bluetooth")
    onMiddleClicked: Bluetooth.toggle()

    BarIcon {
        anchors.fill: parent
        color: root.tint
        icon: !root.adapter.powered ? "\u{F00B2}" : root.adapter.audio ? "\u{F00B0}" : root.adapter.connected ? "\u{F00B1}" : "\u{F00AF}"
    }
}
