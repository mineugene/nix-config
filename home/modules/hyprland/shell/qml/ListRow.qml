import QtQuick
import QtQuick.Layouts

// A device or network row: leading glyph, name, trailing glyph or status. A
// connected network is a state rather than a choice, so its row keeps full
// contrast, names the state on the trailing side, and takes no click.
PopupAction {
    id: row

    property string leading: ""
    property string trailing: ""
    property bool connected: false

    enabled: !connected
    opacity: connected || enabled ? 1 : 0.5

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
            color: row.connected ? Tokens.c.accent : Tokens.c.foreground
            font.weight: row.connected ? Font.DemiBold : Font.Normal
        }
        PopupText {
            text: row.connected ? "Connected" : row.trailing
            font.family: row.connected || row.trailing.length > 1 ? Tokens.fontFamily : Tokens.monoFamily
            color: row.connected ? Tokens.c.accent : Tokens.c.muted
        }
    }
}
