import QtQuick

// One square bar cell holding a Nerd Font glyph. The glyph is centered by the
// Text's alignment over the whole cell rather than by the font's line box,
// whose bearings leave the ink a step low.
Item {
    property string icon: ""
    property real adjust: 0
    property color color: Tokens.c.foreground

    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        width: parent.width
        height: parent.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: parent.icon
        color: parent.color
        font.family: Tokens.monoFamily
        font.pixelSize: Tokens.fontSize + 3 + parent.adjust
    }
}
