import QtQuick

// A clickable bar control. `tint` is the foreground its children should draw
// with: the accent under the pointer, the plain foreground otherwise.
MouseArea {
    id: control

    property color base: Tokens.c.foreground
    property color tint: containsMouse ? Tokens.c.accent : base
    property string tip: ""

    signal leftClicked
    signal middleClicked
    signal rightClicked
    signal scrolled(int direction)

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            leftClicked();
        else if (mouse.button === Qt.MiddleButton)
            middleClicked();
        else
            rightClicked();
    }

    onWheel: wheel => scrolled(wheel.angleDelta.y > 0 ? 1 : -1)

    Behavior on tint {
        ColorAnimation {
            duration: Tokens.fast
            easing.type: Easing.OutQuad
        }
    }

    Tip {
        target: control
        text: control.tip
        hovered: control.containsMouse
    }
}
