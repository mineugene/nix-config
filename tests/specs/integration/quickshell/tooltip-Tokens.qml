pragma Singleton

import QtQuick

QtObject {
    readonly property var spacing: ({
            small: 8,
            normal: 16,
            large: 24
        })
    readonly property var radius: ({
            small: 4
        })
    readonly property var c: ({
            foreground: "white",
            border: "gray",
            surface: "black",
            accent: "blue"
        })
    readonly property int borderWidth: 1
    readonly property int fontSize: 14
    readonly property string fontFamily: "DejaVu Sans"
    readonly property string monoFamily: "DejaVu Sans Mono"
    readonly property real cornerRoundingPower: 2
    readonly property int fast: 160
}
