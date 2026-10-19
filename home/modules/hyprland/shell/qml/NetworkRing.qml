import QtQuick

// The ring reports activity, not rate: the right half lights on receive and
// the left on transmit. The floor is 4 KiB/s rather than zero because an idle
// link is never silent; ARP, mDNS and keepalives reach about 1 KiB/s, and any
// real transfer sits far above the floor.
BarControl {
    id: root

    required property var link
    property string icon: ""
    property string popup: ""

    readonly property bool idle: link.state === "off" || link.state === "disconnected" || link.state === "unavailable"

    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    tip: Desktop.popup === popup ? "" : tooltip
    property string tooltip: ""
    onLeftClicked: Desktop.toggle(popup)

    Ring {
        anchors.fill: parent
        value: 0
        fill: root.idle ? "transparent" : Tokens.c.surface

        BarIcon {
            anchors.fill: parent
            icon: root.icon
            color: root.tint
        }
    }
    Ring {
        anchors.fill: parent
        fill: "transparent"
        arc: Tokens.c.accent
        value: root.link.rx_bytes_per_second >= 4096 ? 50 : 0
    }
    Ring {
        anchors.fill: parent
        fill: "transparent"
        arc: Tokens.c.accentAlt
        clockwise: false
        value: root.link.tx_bytes_per_second >= 4096 ? 50 : 0
    }
}
