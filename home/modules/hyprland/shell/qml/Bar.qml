pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// The bar's optional modules collapse after a period without interaction. A
// workspace change, a volume change, a battery falling into a warning state, and
// the mod key (`quickshell ipc --path <bar.qml> call bar reveal`) bring them
// back.
Singleton {
    id: root

    readonly property alias shown: barReveal.shown
    // A hidden bar drops its optional modules to a muted, background-free row.
    readonly property color foreground: shown ? Tokens.c.foreground : Tokens.c.muted

    property bool hovered: false
    property string batterySeverity: Power.batterySeverity()
    property string lastSeverity: "normal"

    function reveal() {
        barReveal.nudge();
    }

    Reveal {
        id: barReveal
        hovered: root.hovered
        popupOpen: Desktop.popup !== ""
    }

    onBatterySeverityChanged: {
        // Only a transition into a warning state is news; staying low is not.
        if (batterySeverity !== "normal" && batterySeverity !== lastSeverity)
            reveal();
        lastSeverity = batterySeverity;
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.reveal();
        }
    }

    Connections {
        target: Audio

        function onSinkVolumeChanged() {
            root.reveal();
        }

        function onSinkMutedChanged() {
            root.reveal();
        }

        function onSourceVolumeChanged() {
            root.reveal();
        }

        function onSourceMutedChanged() {
            root.reveal();
        }
    }
}
