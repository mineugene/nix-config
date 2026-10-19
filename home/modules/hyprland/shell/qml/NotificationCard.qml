import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

// One notification, as a toast or as a row of the history.
CornerRectangle {
    id: card

    required property var notification
    property bool toast: false
    property bool separator: false

    readonly property var n: notification
    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    readonly property bool low: n.urgency === NotificationUrgency.Low
    readonly property var defaultAction: n.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: n.actions.filter(a => a.identifier !== "default")
    readonly property string icon: {
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") ? "file://" + n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    implicitHeight: content.implicitHeight + 2 * pad
    readonly property real pad: toast ? Tokens.spacing.normal : Tokens.spacing.small
    radius: toast ? Tokens.radius.general : Tokens.radius.small
    color: area.containsMouse ? Tokens.c.surfaceHover : toast ? Tokens.c.surface : "transparent"
    border.width: toast && (critical || low) ? Tokens.borderWidth : 0
    border.color: critical ? Tokens.c.red : Tokens.c.muted

    Behavior on color {
        ColorAnimation {
            duration: Tokens.fast
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        visible: card.separator
        width: parent.width
        height: Tokens.borderWidth
        color: Tokens.c.border
    }

    // Toasts leave on their own, except urgent ones; the history keeps them.
    Timer {
        interval: card.n.expireTimeout > 0 ? card.n.expireTimeout * 1000 : card.low ? 5000 : 8000
        running: card.toast && !card.critical && !area.containsMouse
        onTriggered: Notifications.hideToast(card.n)
    }

    Connections {
        target: card.n
        function onClosed() {
            Notifications.hideToast(card.n);
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Notifications.activate(card.n, card.defaultAction);
            else
                card.n.dismiss();
        }
    }

    RowLayout {
        id: content
        x: card.pad
        y: card.pad
        width: card.width - 2 * card.pad
        spacing: Tokens.spacing.normal

        Image {
            visible: card.icon !== ""
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            source: card.icon
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small / 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                PopupText {
                    Layout.fillWidth: true
                    text: card.n.appName
                    elide: Text.ElideRight
                    color: Tokens.c.muted
                    font.pixelSize: Tokens.fontSize * 0.85
                }

                PopupText {
                    text: Notifications.age(card.n)
                    color: Tokens.c.muted
                    font.pixelSize: Tokens.fontSize * 0.85
                }

                CornerRectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: Tokens.radius.small
                    color: closeArea.containsMouse ? Tokens.c.surfaceHover : Tokens.c.surfaceAlt

                    PopupText {
                        anchors.centerIn: parent
                        text: "\u{F0156}"
                        color: Tokens.c.muted
                        font.family: Tokens.monoFamily
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.n.dismiss()
                    }
                }
            }

            PopupText {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.n.summary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Tokens.fontSize * 1.05
                font.weight: Font.Bold
            }

            PopupText {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.n.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.toast ? 4 : 6
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                visible: card.buttons.length > 0
                spacing: Tokens.spacing.small

                Repeater {
                    model: card.buttons

                    CornerRectangle {
                        id: button
                        required property var modelData
                        implicitWidth: label.implicitWidth + 2 * Tokens.spacing.small
                        implicitHeight: label.implicitHeight + Tokens.spacing.small
                        radius: Tokens.radius.small
                        color: buttonArea.containsMouse ? Tokens.c.surfaceHover : Tokens.c.surfaceAlt

                        PopupText {
                            id: label
                            anchors.centerIn: parent
                            text: button.modelData.text
                        }

                        MouseArea {
                            id: buttonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.activate(card.n, button.modelData)
                        }
                    }
                }
            }
        }
    }
}
