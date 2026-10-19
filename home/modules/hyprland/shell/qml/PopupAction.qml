import QtQuick
import QtQuick.Layouts

// One row shape for every dropdown entry, so menus stay visually identical.
CornerRectangle {
    id: row

    property string text: ""
    property bool active: false
    default property alias content: slot.data
    property bool hasContent: slot.children.length > 0
    signal triggered

    Layout.fillWidth: true
    implicitHeight: label.implicitHeight + Tokens.spacing.small + 2
    radius: Tokens.radius.small
    color: area.containsMouse && enabled ? Tokens.c.surfaceHover : "transparent"
    opacity: enabled ? 1 : 0.5

    MouseArea {
        id: area
        anchors.fill: parent
        // Item.enabled does not reach a child MouseArea, so the click handler
        // must gate on the row itself.
        enabled: row.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.triggered()
    }

    Item {
        id: slot
        anchors.fill: parent
    }

    PopupText {
        id: label
        visible: !row.hasContent
        anchors.verticalCenter: parent.verticalCenter
        x: Tokens.spacing.small
        width: parent.width - 2 * Tokens.spacing.small
        text: row.text
        elide: Text.ElideRight
    }
}
