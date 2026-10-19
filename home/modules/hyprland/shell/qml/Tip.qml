import QtQuick
import Quickshell

// A hover tooltip anchored below its control. Empty text shows nothing.
PopupWindow {
    id: tip

    required property Item target
    property string text: ""
    // Preserve geometry while the anchored popup hides after the source clears.
    property string displayText: ""
    property bool hovered: false

    color: "transparent"
    visible: shown && text !== ""
    implicitWidth: label.implicitWidth + Tokens.spacing.normal
    implicitHeight: label.implicitHeight + Tokens.spacing.small

    property bool shown: false

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.rect.y: 0
    anchor.rect.width: target.width
    anchor.rect.height: target.height + Tokens.spacing.small / 2

    onTextChanged: if (text !== "")
        displayText = text

    onHoveredChanged: {
        if (hovered)
            delay.restart();
        else {
            delay.stop();
            shown = false;
        }
    }

    Timer {
        id: delay
        interval: 500
        onTriggered: tip.shown = true
    }

    CornerRectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: Tokens.c.surface
        border.width: Tokens.borderWidth
        border.color: Tokens.c.border

        Text {
            id: label
            anchors.centerIn: parent
            text: tip.displayText
            color: Tokens.c.foreground
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSize + 1
        }
    }
}
