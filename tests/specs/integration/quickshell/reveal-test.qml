import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: test

    property bool finished: false

    function fail(message) {
        if (finished)
            return;
        finished = true;
        console.error("bar reveal timing FAILED: " + message);
        Qt.exit(1);
    }

    function pass() {
        finished = true;
        console.log("bar reveal timing ok");
        Qt.quit();
    }

    function checkSlots(expanded) {
        if (optional.width !== (expanded ? 40 : 0))
            return fail("a collapsed module could not reopen");
        if (!optional.module.visible)
            return fail("hiding a slot changed its module's own visibility");
    }

    // Holds the process open; the shell quits when it has no window.
    Window {
        visible: true
        width: 100
        height: 40
        color: "transparent"

        Row {
            Slot {
                id: optional
                open: reveal.shown

                Item {
                    implicitWidth: 40
                    implicitHeight: 20
                }
            }
        }
    }

    // The bar owns the countdown through a singleton, not a visual parent.
    Singleton {
        Reveal {
            id: reveal
            idleMs: 150
        }
    }

    Timer {
        id: stages
        interval: 300
        repeat: true
        running: !test.finished
        property int stage: 0

        onTriggered: {
            switch (stage) {
            case 0:
                if (reveal.shown)
                    return test.fail("an idle bar stayed visible");
                test.checkSlots(false);
                reveal.nudge();
                if (!reveal.shown)
                    return test.fail("a nudge did not show the modules");
                reveal.hovered = true;
                stage++;
                break;
            case 1:
                if (!reveal.shown)
                    return test.fail("a pointer on the bar did not hold the modules");
                test.checkSlots(true);
                reveal.hovered = false;
                stage++;
                break;
            case 2:
                if (reveal.shown)
                    return test.fail("the modules stayed visible after the pointer left");
                test.checkSlots(false);
                reveal.popupOpen = true;
                if (!reveal.shown)
                    return test.fail("an open popup did not show the modules");
                stage++;
                break;
            case 3:
                if (!reveal.shown)
                    return test.fail("an open popup did not hold the modules");
                test.checkSlots(true);
                reveal.popupOpen = false;
                stage++;
                break;
            case 4:
                if (reveal.shown)
                    return test.fail("the modules stayed visible after the popup closed");
                test.checkSlots(false);
                test.pass();
                break;
            }
        }
    }

    Component.onCompleted: if (!reveal.shown)
        fail("a fresh bar did not start visible")

    Timer {
        interval: 20000
        running: !test.finished
        onTriggered: test.fail("the reveal stages timed out")
    }
}
