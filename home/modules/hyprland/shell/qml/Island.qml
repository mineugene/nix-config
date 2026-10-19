import QtQuick

// A bar island: a rounded rectangle, and a single cell makes a rounded square.
CornerRectangle {
    implicitHeight: Tokens.barHeight
    radius: Tokens.radius.general
    color: Tokens.c.surfaceHover
}
