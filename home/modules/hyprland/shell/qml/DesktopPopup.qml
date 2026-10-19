import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// A popup window with its themed frame. Fade in and out belongs to the
// compositor's layer animation, so the window only maps and unmaps. Dashboards
// pad by popupPadding; compact menus pad by one small step.
PanelWindow {
    id: popup

    required property string name
    property string side: "right"
    property string widthKey: name
    property bool compact: false
    property real minWidth: 0
    property real gap: Tokens.spacing.normal
    default property alias content: column.data

    readonly property real pad: compact ? Tokens.spacing.small : Tokens.popupPadding
    // A popup can outgrow the screen, so cap it and let the body scroll.
    readonly property real maxHeight: popup.screen ? popup.screen.height - 2 * Tokens.spacing.normal : Infinity
    readonly property real contentHeight: Math.min(column.implicitHeight + 2 * pad, maxHeight)

    // A layer surface resizes through a compositor round trip: the size request
    // is committed before a buffer of that size, so the compositor draws the
    // previous buffer at the new size for one frame. Growing hides it, because
    // the top-left corner the buffer is drawn from stays put; shrinking exposes
    // it as a one-frame flash. Hold the tallest size seen while mapped and
    // shrink only while unmapped, so a collapse never resizes the surface.
    property real heldHeight: 0
    implicitHeight: Math.max(contentHeight, heldHeight)
    onContentHeightChanged: if (contentHeight > heldHeight) heldHeight = contentHeight
    onVisibleChanged: heldHeight = contentHeight

    screen: Desktop.screen
    visible: Desktop.popup === name
    anchors {
        top: true
        left: side === "left"
        right: side === "right"
    }
    margins.top: Tokens.panelTopInset
    margins.left: side === "left" ? Tokens.spacing.small : 0
    margins.right: side === "right" ? Tokens.spacing.small : 0
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    implicitWidth: Math.max(Tokens.popupWidth[widthKey], minWidth)
    // The surface can stay taller than the visible frame after a collapse, so
    // input follows the frame, not the surface.
    mask: Region {
        item: frame
    }
    WlrLayershell.namespace: "shell-" + name
    WlrLayershell.layer: WlrLayer.Overlay

    CornerRectangle {
        id: frame
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: popup.contentHeight
        radius: Tokens.radius.general
        color: Tokens.c.surface
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: popup.pad
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            width: flick.width
            spacing: popup.gap
        }
    }
}