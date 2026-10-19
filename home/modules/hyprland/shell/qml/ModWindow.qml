import QtQuick

// One island holding two layers: the island is the title plate, and the app
// plate sits over its left end, so the darker title surface reads as a plate
// emerging from behind the app name.
Island {
    id: root

    readonly property string app: Focused.app
    readonly property string title: Focused.title
    readonly property bool truncated: title.length > 60

    visible: app !== "" || title !== ""
    // A quiet bar hides both plates but keeps their space, so the title text
    // stays where it is while the plates fade.
    color: Bar.shown ? Tokens.c.surface : "transparent"
    implicitWidth: capsule.width + titleText.width

    CornerRectangle {
        id: capsule
        visible: root.app !== ""
        width: visible ? appText.implicitWidth + Tokens.spacing.small * 2 : 0
        height: Tokens.barHeight
        radius: Tokens.radius.general
        color: Bar.shown ? Tokens.c.surfaceHover : "transparent"
        z: 1

        Text {
            id: appText
            anchors.centerIn: parent
            text: root.app
            color: Bar.shown ? Tokens.c.foreground : Tokens.c.muted
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSize + 1
        }
    }

    Text {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        x: capsule.width
        leftPadding: Tokens.spacing.small
        rightPadding: Tokens.spacing.normal
        text: root.truncated ? root.title.slice(0, 59) + "…" : root.title
        color: Tokens.c.foreground
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.fontSize + 1

        HoverHandler {
            id: hover
        }
    }

    Tip {
        target: titleText
        text: root.truncated ? root.title : ""
        hovered: hover.hovered
    }
}
