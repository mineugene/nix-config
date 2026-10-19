import QtQuick
import QtQuick.Layouts

// A top border, a title, and small-spaced children.
ColumnLayout {
    property string title: ""
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Tokens.borderWidth
        color: Tokens.c.border
    }

    PopupText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        Layout.bottomMargin: Tokens.spacing.small
        visible: parent.title !== ""
        text: parent.title
        elide: Text.ElideRight
        font.weight: Font.Bold
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        // An empty title is dropped from the layout along with its margins, so
        // the body carries the gap after the separator itself.
        Layout.topMargin: parent.title === "" ? Tokens.spacing.small : 0
        spacing: Tokens.spacing.small
    }
}
