import QtQuick
import QtQuick.Layouts

DesktopPopup {
    id: popup

    name: "notifications"

    RowLayout {
        Layout.fillWidth: true

        PopupTitle {
            Layout.fillWidth: true
            text: "Notifications"
        }

        CornerRectangle {
            implicitWidth: clear.implicitWidth + 2 * Tokens.spacing.small
            implicitHeight: clear.implicitHeight + Tokens.spacing.small
            radius: Tokens.radius.small
            color: clearArea.containsMouse ? Tokens.c.surfaceHover : Tokens.c.surfaceAlt

            PopupText {
                id: clear
                anchors.centerIn: parent
                text: "Dismiss all"
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.dismissAll()
            }
        }
    }

    PopupAction {
        text: Notifications.dnd ? "Do not disturb · on" : "Do not disturb · off"
        active: Notifications.dnd
        onTriggered: Notifications.toggleDnd()
    }

    PopupText {
        visible: Notifications.count === 0
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        horizontalAlignment: Text.AlignHCenter
        color: Tokens.c.muted
        text: "No notifications"
    }

    ListView {
        visible: Notifications.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 560)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: [...Notifications.history.values].reverse()

        delegate: NotificationCard {
            required property var modelData
            required property int index
            width: ListView.view.width
            notification: modelData
            separator: index > 0
        }
    }
}
