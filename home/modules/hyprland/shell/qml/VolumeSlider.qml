import QtQuick
import QtQuick.Controls

Slider {
    id: slider

    from: 0
    to: 100
    stepSize: 1

    // A styled control sizes itself from its background and handle, so both
    // need an implicit height or the slider collapses to zero and takes no
    // pointer input.
    implicitWidth: 8 * Tokens.spacing.normal
    implicitHeight: Tokens.spacing.normal + Tokens.spacing.small

    background: Rectangle {
        implicitHeight: 6
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: implicitHeight
        radius: height / 2
        color: Tokens.c.surfaceHover

        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Tokens.c.accent
        }
    }

    handle: Rectangle {
        implicitWidth: 14
        implicitHeight: 14
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: implicitWidth
        height: implicitHeight
        radius: width / 2
        color: Tokens.c.accent
    }
}