import QtQuick
import Quickshell
import Quickshell.Hyprland

// Occupied workspaces sit shoulder to shoulder so their backgrounds merge into
// one group; only a run's outer edges are rounded. The accent marker slides
// beneath the digits.
Island {
    id: root

    readonly property int cell: Tokens.workspaceCell
    readonly property int inset: (Tokens.barHeight - cell) / 2
    readonly property var focused: Hyprland.focusedWorkspace

    function find(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function lit(id) {
        if (id < 1 || id > 9)
            return false;
        const ws = find(id);
        return id === (focused?.id ?? -1) || (ws !== null && ws.toplevels.values.length > 0);
    }

    color: Tokens.c.surface
    implicitWidth: cell * 9 + 2 * inset

    Item {
        x: root.inset
        width: root.cell * 9
        height: parent.height

        CornerRectangle {
            id: marker
            readonly property int active: root.focused?.id ?? 0
            width: root.cell
            height: root.cell
            radius: Tokens.radius.small
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.c.accent
            opacity: active >= 1 && active <= 9 ? 1 : 0
            x: (Math.max(active, 1) - 1) * root.cell

            Behavior on x {
                NumberAnimation {
                    duration: Tokens.slide
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.curve
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.slide
                }
            }
            z: 1
        }

        Repeater {
            model: 9

            CornerRectangle {
                id: backdrop
                required property int index
                readonly property int id: index + 1
                readonly property bool on: root.lit(id)
                readonly property bool start: on && !root.lit(id - 1)
                readonly property bool end: on && !root.lit(id + 1)

                x: index * root.cell
                width: root.cell
                height: root.cell
                anchors.verticalCenter: parent.verticalCenter
                color: on ? Tokens.c.surfaceHover : "transparent"
                radius: 0
                topLeftRadius: start ? Tokens.radius.small : 0
                bottomLeftRadius: start ? Tokens.radius.small : 0
                topRightRadius: end ? Tokens.radius.small : 0
                bottomRightRadius: end ? Tokens.radius.small : 0

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.slide
                    }
                }
            }
        }

        Repeater {
            model: 9

            MouseArea {
                id: button
                required property int index
                readonly property int id: index + 1
                readonly property var ws: root.find(id)
                readonly property bool active: id === (root.focused?.id ?? -1)

                x: index * root.cell
                width: root.cell
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: 2
                onClicked: Desktop.run(["shell-workspace", String(id)])

                Text {
                    anchors.centerIn: parent
                    text: button.id
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSize + 1
                    color: button.active ? Tokens.c.background : button.containsMouse ? Tokens.c.accent : Tokens.c.foreground

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.slide
                        }
                    }
                }
            }
        }
    }
}
