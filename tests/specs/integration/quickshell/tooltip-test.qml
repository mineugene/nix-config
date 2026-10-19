import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: test
    property bool popupOpen: false
    property bool finished: false
    property var tooltip: null
    property var before: null

    function fail(message) {
        finished = true;
        console.error("tooltip geometry FAILED: " + message);
        Qt.exit(1);
    }

    Window {
        visible: true
        width: 480
        height: 90
        color: "transparent"

        BarControl {
            id: module
            x: 40
            y: 20
            width: 80
            height: 32
            tip: test.popupOpen ? "" : "Module tooltip"
            onLeftClicked: test.popupOpen = true
        }
    }

    Timer {
        id: stages
        interval: 50
        repeat: true
        running: !test.finished
        property int stage: 0

        onTriggered: {
            switch (stage) {
            case 0:
                test.tooltip = module.data.find(candidate => candidate && candidate.target === module);
                if (!test.tooltip) {
                    test.fail("module tooltip was not found");
                    return;
                }
                // Offscreen popups do not map, but their content and layout still update.
                test.tooltip.shown = true;
                stage++;
                break;
            case 1:
                test.before = {
                    width: test.tooltip.width,
                    height: test.tooltip.height,
                    implicitWidth: test.tooltip.implicitWidth,
                    implicitHeight: test.tooltip.implicitHeight,
                };
                if (test.before.implicitWidth <= Tokens.spacing.normal) {
                    test.fail("nonempty tooltip had no content width");
                    return;
                }
                module.leftClicked();
                stage++;
                break;
            case 2:
                if (!test.popupOpen || test.tooltip.text !== "") {
                    test.fail("module click did not clear the tooltip source text");
                    return;
                }
                if (test.tooltip.anchor.item !== module) {
                    test.fail("tooltip anchor target changed while hiding");
                    return;
                }
                if (test.tooltip.width !== test.before.width || test.tooltip.height !== test.before.height ||
                        test.tooltip.implicitWidth !== test.before.implicitWidth || test.tooltip.implicitHeight !== test.before.implicitHeight) {
                    test.fail(`closing resized the tooltip from ${test.before.width}x${test.before.height} to ${test.tooltip.width}x${test.tooltip.height}`);
                    return;
                }
                test.finished = true;
                console.log("native tooltip geometry ok");
                Qt.quit();
            }
        }
    }

    Timer {
        interval: 5000
        running: !test.finished
        onTriggered: test.fail("bounded click transition timed out");
    }
}
