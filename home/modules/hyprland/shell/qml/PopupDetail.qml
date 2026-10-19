import QtQuick
import QtQuick.Layouts

RowLayout {
    property string name: ""
    property string value: ""

    Layout.fillWidth: true

    PopupText {
        Layout.fillWidth: true
        text: parent.name
    }
    PopupText {
        text: parent.value
        font.family: Tokens.monoFamily
    }
}
