import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// The session lock. It starts locked and exits cleanly only after PAM accepts
// the password; any other exit leaves the compositor locked, and the service
// restarts it.
ShellRoot {
    id: root

    // Empty draws the prompt on every monitor.
    readonly property string primary: Quickshell.env("SHELL_LOCK_MONITOR") ?? ""

    property string password: ""
    property bool checking: false
    property bool failed: false
    property string pending: ""

    function press(event) {
        if (checking)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (password !== "")
                submit();
        } else if (event.key === Qt.Key_Backspace) {
            password = password.slice(0, -1);
        } else if (event.key === Qt.Key_Escape || (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier))) {
            password = "";
        } else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & Qt.ControlModifier)) {
            password += event.text;
            failed = false;
        }
    }

    function submit() {
        pending = password;
        password = "";
        checking = true;
        failed = false;
        pam.start();
    }

    PamContext {
        id: pam
        config: "shell-lock"

        onResponseRequiredChanged: {
            if (responseRequired && root.pending !== "") {
                respond(root.pending);
                root.pending = "";
            }
        }

        onCompleted: result => {
            root.pending = "";
            root.checking = false;
            if (result === PamResult.Success) {
                lock.locked = false;
                quit.start();
            } else {
                root.failed = true;
            }
        }

        onError: {
            root.pending = "";
            root.checking = false;
            root.failed = true;
        }
    }

    // The unlock request must reach the compositor before the process exits.
    Timer {
        id: quit
        interval: 200
        onTriggered: Qt.quit()
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: Tokens.c.background

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => root.press(event)

                CornerRectangle {
                    visible: root.primary === "" || surface.screen.name === root.primary
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 40
                    width: 320
                    height: 52
                    radius: Tokens.radius.general
                    color: Tokens.c.surface
                    border.width: Tokens.borderWidth
                    border.color: root.checking ? Tokens.c.green : root.failed ? Tokens.c.red : Tokens.c.accent

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Tokens.fast
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 2 * Tokens.spacing.normal
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideLeft
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSize + 2
                        color: root.password === "" ? Tokens.c.muted : Tokens.c.foreground
                        text: root.checking ? "Authenticating…" : root.password !== "" ? "•".repeat(root.password.length) : root.failed ? (pam.message || "Authentication failed") : "Password"
                    }
                }
            }
        }
    }
}
