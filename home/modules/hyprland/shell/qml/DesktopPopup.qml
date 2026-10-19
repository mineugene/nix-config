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
    implicitHeight: Math.min(column.implicitHeight + 2 * pad, maxHeight)
    WlrLayershell.namespace: "shell-" + name
    WlrLayershell.layer: WlrLayer.Overlay

    CornerRectangle {
        anchors.fill: parent
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