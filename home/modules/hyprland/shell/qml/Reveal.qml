import QtQuick

// Collapses its consumers after a period without interaction. The countdown
// pauses while the pointer rests on the bar or a popup is open, so the modules
// stay up while they are being used. `nudge` shows them again.
QtObject {
    id: root

    property int idleMs: 5000
    property bool hovered: false
    property bool popupOpen: false
    property bool shown: true

    readonly property bool busy: hovered || popupOpen

    function nudge() {
        shown = true;
        // A nudge during a running countdown measures the idle period from the
        // interaction, not from when the countdown started.
        if (idle.running)
            idle.restart();
    }

    onHoveredChanged: if (hovered) nudge()
    onPopupOpenChanged: if (popupOpen) nudge()

    property Timer idle: Timer {
        interval: root.idleMs
        running: root.shown && !root.busy
        onTriggered: root.shown = false
    }
}
