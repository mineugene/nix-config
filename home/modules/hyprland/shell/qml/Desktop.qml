pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string popup: ""
    property string primaryName: ""
    readonly property var screen: Quickshell.screens.find(s => s.name === primaryName) ?? Quickshell.screens[0] ?? null

    property bool canHibernate: false
    property string previous: ""

    function toggle(name) {
        popup = popup === name ? "" : name;
    }

    function closeAll() {
        popup = "";
    }

    function run(command) {
        Quickshell.execDetached(command);
    }

    // Opening a popup hands over to the one it replaces, so the transition
    // runs here rather than in each popup.
    onPopupChanged: {
        if (previous === "bluetooth")
            run(["shell-bluetooth", "broadcast", "off"]);
        if (popup === "wifi")
            run(["shell-network-listener", "scan"]);
        if (popup === "bluetooth") {
            run(["shell-bluetooth", "scan"]);
            run(["shell-bluetooth", "broadcast", "on"]);
        }
        previous = popup;
    }

    Process {
        command: ["monitor-topology", "primary"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.primaryName = text.trim()
        }
    }

    Process {
        id: theme
        command: ["shell-theme-listener"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const mode = line.trim();
                if (mode === "dark" || mode === "light")
                    Tokens.mode = mode;
            }
        }
        onExited: themeRestart.start()
    }

    Timer {
        id: themeRestart
        interval: 2000
        onTriggered: theme.running = true
    }

    // Capabilities rarely change, so an hourly check also covers a machine
    // gaining swap or a resume device without a restart.
    Process {
        id: hibernate
        command: ["ui-power", "can", "hibernate"]
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.trim() === "true"
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: hibernate.running = true
    }
}
