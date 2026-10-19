import QtQuick

BarControl {
    id: root

    property int volume: 0
    property string icon: ""
    property string popupName: ""
    property string menuName: ""
    property string tooltip: ""
    signal toggleMute
    signal change(int delta)

    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight
    base: Bar.foreground
    tip: Desktop.popup === "audio" || Desktop.popup === menuName ? "" : tooltip

    onLeftClicked: Desktop.toggle("audio")
    onRightClicked: Desktop.toggle(menuName)
    onMiddleClicked: toggleMute()
    onScrolled: direction => change(direction * 5)

    // The glyph stands outside the ring so a quiet bar can drop the ring alone.
    Ring {
        anchors.fill: parent
        visible: Bar.shown
        value: root.volume
        arc: root.tint
    }

    BarIcon {
        anchors.fill: parent
        icon: root.icon
        color: root.tint
        adjust: -2
    }
}
