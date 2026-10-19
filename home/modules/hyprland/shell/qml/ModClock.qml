import QtQuick
import Quickshell

BarControl {
    implicitWidth: label.implicitWidth + Tokens.spacing.normal
    implicitHeight: Tokens.barHeight
    onLeftClicked: Desktop.toggle("calendar")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd MMM dd · HH:mm")
        color: parent.tint
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.fontSize + 1
        font.letterSpacing: 0.04 * (Tokens.fontSize + 1)
    }
}
