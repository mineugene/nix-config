import QtQuick
import QtQuick.Layouts

// A device or network row: leading glyph, name, trailing glyph or status.
PopupAction {
    id: row

    property string leading: ""
    property string trailing: ""
    property bool connected: false

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.small
        anchors.rightMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small

        Text {
            text: row.leading
            color: Tokens.c.foreground
            font.family: Tokens.monoFamily
            font.pixelSize: Tokens.fontSize + 3
        }
        PopupText {
            Layout.fillWidth: true
            text: row.text
            elide: Text.ElideRight
        }
        PopupText {
            text: row.trailing
            font.family: row.trailing.length > 1 ? Tokens.fontFamily : Tokens.monoFamily
            color: Tokens.c.muted
        }
    }
}
