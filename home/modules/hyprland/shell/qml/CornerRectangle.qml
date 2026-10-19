import QtQuick
import QtQuick.Shapes
import "corner.js" as Corner

// A Rectangle-shaped surface whose corners follow Hyprland's rounding power.
// Power 2 draws a native Rectangle, which matches Qt's circular corners
// exactly; any other power draws the superellipse path as a shape, with an
// optional uniform border stroked inside the boundary. Corners can be set
// individually, like Rectangle's topLeftRadius and friends.
Item {
    id: root

    property color color: "transparent"
    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property real roundingPower: Tokens.cornerRoundingPower

    component BorderProperties: QtObject {
        property color color: "black"
        property real width: 0
    }
    property BorderProperties border: BorderProperties {}

    readonly property real radiusScale: Corner.clampPower(roundingPower) / 2
    readonly property var effectiveRadii: ({
            tl: topLeftRadius * radiusScale,
            tr: topRightRadius * radiusScale,
            br: bottomRightRadius * radiusScale,
            bl: bottomLeftRadius * radiusScale
        })
    readonly property bool customCorners: Corner.clampPower(roundingPower) !== 2 && (topLeftRadius > 0 || topRightRadius > 0 || bottomLeftRadius > 0 || bottomRightRadius > 0)
    readonly property real strokeWidth: customCorners ? border.width : 0
    readonly property var strokeRadii: ({
            tl: Math.max(0, effectiveRadii.tl - strokeWidth / 2),
            tr: Math.max(0, effectiveRadii.tr - strokeWidth / 2),
            br: Math.max(0, effectiveRadii.br - strokeWidth / 2),
            bl: Math.max(0, effectiveRadii.bl - strokeWidth / 2)
        })

    Rectangle {
        anchors.fill: parent
        visible: !root.customCorners
        color: root.color
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.color: root.border.color
        border.width: root.border.width
        antialiasing: true
    }

    Shape {
        anchors.fill: parent
        visible: root.customCorners
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // Inset the path by half the border so a stroke of `border.width`
            // lands flush with the outer boundary.
            strokeWidth: root.strokeWidth
            strokeColor: root.strokeWidth > 0 ? root.border.color : "transparent"
            fillColor: root.color
            PathSvg {
                path: Corner.pathStringRadii(root.strokeWidth / 2, root.strokeWidth / 2, root.width - root.strokeWidth, root.height - root.strokeWidth, root.strokeRadii, root.roundingPower)
            }
        }
    }
}