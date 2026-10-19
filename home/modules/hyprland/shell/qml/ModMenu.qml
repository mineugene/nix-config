import QtQuick

// The end controls reach the bar's corners: the hit area extends one small
// step past the cell on both sides, cancelled by the section's margin.
Item {
    id: root

    property string icon: ""
    property string tip: ""
    property string popup: ""
    signal activated

    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight

    BarControl {
        id: control
        anchors.fill: parent
        anchors.leftMargin: -Tokens.spacing.small
        anchors.rightMargin: -Tokens.spacing.small
        tip: Desktop.popup === root.popup ? "" : root.tip
        onLeftClicked: Desktop.toggle(root.popup)
    }

    BarIcon {
        anchors.fill: parent
        icon: root.icon
        color: control.tint
    }
}
