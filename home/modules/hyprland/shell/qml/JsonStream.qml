import QtQuick
import Quickshell
import Quickshell.Io

// Runs a helper that prints one JSON document per line and keeps the latest
// one in `value`. The helper restarts when it exits while `enabled`.
Scope {
    id: root

    property alias command: proc.command
    property bool enabled: true
    property var value: null

    Component.onCompleted: proc.running = enabled
    onEnabledChanged: proc.running = enabled

    Process {
        id: proc

        stdout: SplitParser {
            onRead: line => {
                try {
                    root.value = JSON.parse(line);
                } catch (error) {
                    // A partial or foreign line leaves the last good value.
                }
            }
        }

        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: proc.running = root.enabled
    }
}
