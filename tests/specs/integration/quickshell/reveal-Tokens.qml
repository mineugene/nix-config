pragma Singleton

import QtQuick

QtObject {
    readonly property int barHeight: 30
    readonly property int slide: 0
    readonly property var curve: [0.25, 0.8, 0.3, 1, 1, 1]
}
