import QtQuick

// A button used by the audio dashboard. Icon buttons keep the row height of a
// plain text button while drawing a larger glyph, so swapping the glyph never
// resizes them.
CornerRectangle {
    id: root

    property string text: ""
    property bool active: false
    property bool glyph: false
    property bool square: false
    signal clicked

    readonly property bool icon: square || glyph

    implicitWidth: square ? implicitHeight : label.implicitWidth + 2 * Tokens.spacing.small
    implicitHeight: sizing.implicitHeight + Tokens.spacing.small + 2
    radius: Tokens.radius.small
    color: area.containsMouse && enabled ? Tokens.c.surfaceHover : "transparent"
    opacity: enabled ? 1 : 0.5

    // Invisible, but it fixes the row height to the plain text size so a larger
    // icon glyph cannot thicken its button.
    PopupText {
        id: sizing
        visible: false
        text: "M"
    }

    PopupText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.icon ? -1 : 0
        x: root.icon ? 0 : Tokens.spacing.small
        width: root.icon ? parent.width : parent.width - 2 * Tokens.spacing.small
        text: root.text
        color: root.active ? Tokens.c.accent : Tokens.c.foreground
        // The icon font carries the glyphs; the interface font does not.
        font.family: root.icon ? Tokens.monoFamily : Tokens.fontFamily
        font.pixelSize: root.icon ? Tokens.fontSize + 3 : Tokens.fontSize + 1
        horizontalAlignment: root.icon ? Text.AlignHCenter : Text.AlignLeft
        elide: root.icon ? Text.ElideNone : Text.ElideRight
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // Item.enabled does not reach a child MouseArea, so the click handler
        // must gate on the control itself.
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}