import QtQuick

// A bar slot holding one module. `open` collapses it to zero width, so the
// modules beside it slide into place instead of jumping.
Item {
    id: root

    property bool open: true
    default property alias content: cell.data
    readonly property Item module: cell.children.length > 0 ? cell.children[0] : null
    readonly property real natural: module ? module.implicitWidth : 0

    implicitHeight: Tokens.barHeight
    width: open ? natural : 0
    // Width hides a collapsed slot. Hiding the slot itself would also make its
    // module report invisible, which a slot sizes itself from.
    clip: !open

    Behavior on width {
        NumberAnimation {
            duration: Tokens.slide
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.curve
        }
    }

    Item {
        id: cell
        width: root.natural
        height: root.height
    }
}
