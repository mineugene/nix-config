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
    tip: Desktop.popup === "audio" || Desktop.popup === menuName ? "" : tooltip

    onLeftClicked: Desktop.toggle("audio")
    onRightClicked: Desktop.toggle(menuName)
    onMiddleClicked: toggleMute()
    onScrolled: direction => change(direction * 5)

    Ring {
        anchors.fill: parent
        value: root.volume
        arc: root.tint

        BarIcon {
            anchors.fill: parent
            icon: root.icon
            color: root.tint
        }
    }
}
