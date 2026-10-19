import QtQuick
import Quickshell
import Quickshell.Hyprland

// One cell per workspace Hyprland still holds: one that is active on a monitor,
// with or without windows, or one that holds windows. Cells keep their numbered
// slot, so a gap in the row is a workspace that does not exist. Occupied
// workspaces sit shoulder to shoulder so their backgrounds merge into one
// group; only a run's outer edges are rounded. The accent marker slides beneath
// the digits. The trailing cell creates the lowest free workspace.
Island {
    id: root

    readonly property int cell: Tokens.workspaceCell
    readonly property int inset: (Tokens.barHeight - cell) / 2
    readonly property var focused: Hyprland.focusedWorkspace

    readonly property var ids: Hyprland.workspaces.values.filter(ws => ws.id >= 1 && ws.id <= 9 && (ws.active || ws.toplevels.values.length > 0)).map(ws => ws.id).sort((a, b) => a - b)

    readonly property int highest: ids.length > 0 ? ids[ids.length - 1] : 0
    // The plus focuses a free id, which Hyprland creates on demand, so a full
    // grid leaves it nothing to show. The bar still stops at nine: the digit
    // binds and the grid do not go past it.
    readonly property int free: {
        for (let id = 1; id <= 9; id++)
            if (!ids.includes(id))
                return id;
        return 0;
    }

    // The plus cell takes the pill when it is hovered, so the run before it
    // must not round away from it.
    readonly property bool plusLit: Bar.shown && free > 0 && plus.containsMouse

    function find(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function lit(id) {
        const ws = find(id);
        return id === (focused?.id ?? -1) || (ws !== null && ws.toplevels.values.length > 0);
    }

    color: Bar.shown ? Tokens.c.surface : "transparent"
    implicitWidth: (highest + (free > 0 ? 1 : 0)) * cell + 2 * inset

    Item {
        x: root.inset
        width: (root.highest + (root.free > 0 ? 1 : 0)) * root.cell
        height: parent.height

        CornerRectangle {
            id: marker
            readonly property int active: root.focused?.id ?? 0
            width: root.cell
            height: root.cell
            radius: Tokens.radius.small
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.c.accent
            opacity: Bar.shown && root.ids.includes(active) ? 1 : 0
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
            model: root.ids

            CornerRectangle {
                id: backdrop
                required property var modelData
                readonly property int id: modelData
                readonly property bool on: root.lit(id)
                readonly property bool start: on && !root.lit(id - 1)
                readonly property bool end: on && !root.lit(id + 1) && !(root.plusLit && id === root.highest)

                x: (id - 1) * root.cell
                width: root.cell
                height: root.cell
                anchors.verticalCenter: parent.verticalCenter
                color: on && Bar.shown ? Tokens.c.surfaceHover : "transparent"
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
            model: root.ids

            MouseArea {
                id: button
                required property var modelData
                readonly property int id: modelData
                readonly property bool active: id === (root.focused?.id ?? -1)

                x: (id - 1) * root.cell
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
                    color: Bar.shown ? (button.active ? Tokens.c.background : button.containsMouse ? Tokens.c.accent : Tokens.c.foreground) : button.active ? Tokens.c.foreground : Tokens.c.muted

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.slide
                        }
                    }
                }
            }
        }

        // The hovered plus continues the pill, so it reads as one more cell of
        // the island rather than a control beside it.
        CornerRectangle {
            x: root.highest * root.cell
            width: root.cell
            height: root.cell
            anchors.verticalCenter: parent.verticalCenter
            visible: root.plusLit
            color: Tokens.c.surfaceHover
            topLeftRadius: root.lit(root.highest) ? 0 : Tokens.radius.small
            bottomLeftRadius: topLeftRadius
            topRightRadius: Tokens.radius.small
            bottomRightRadius: Tokens.radius.small

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.slide
                }
            }
        }

        MouseArea {
            id: plus
            readonly property bool on: root.free > 0

            visible: on && Bar.shown
            x: root.highest * root.cell
            width: root.cell
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 2
            onClicked: Desktop.run(["shell-workspace", String(root.free)])

            // The digits sit a step above the interface size; the plus sits a
            // step below it so the marker does not dominate the island.
            BarIcon {
                anchors.centerIn: parent
                width: plus.width
                height: plus.height
                icon: "\u{F067}"
                adjust: -5
                color: plus.containsMouse ? Tokens.c.accent : Tokens.c.muted

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.slide
                    }
                }
            }
        }
    }
}
