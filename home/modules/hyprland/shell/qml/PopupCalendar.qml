import QtQuick
import QtQuick.Layouts
import Quickshell

DesktopPopup {
    id: popup

    readonly property var locale: Qt.locale()
    readonly property date today: clock.date
    readonly property int first: locale.firstDayOfWeek % 7
    readonly property int offset: (new Date(today.getFullYear(), today.getMonth(), 1).getDay() - first + 7) % 7

    name: "calendar"
    side: "center"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PopupText {
        Layout.alignment: Qt.AlignHCenter
        text: popup.locale.monthName(popup.today.getMonth()) + " " + popup.today.getFullYear()
        font.weight: Font.Bold
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: 7

            PopupText {
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                horizontalAlignment: Text.AlignHCenter
                text: popup.locale.dayName((popup.first + index) % 7, Locale.ShortFormat)
                font.weight: Font.Bold
            }
        }

        // Six weeks always cover a month, so the grid never changes height.
        Repeater {
            model: 42

            CornerRectangle {
                id: cell
                required property int index
                readonly property date day: new Date(popup.today.getFullYear(), popup.today.getMonth(), 1 - popup.offset + index)
                readonly property bool current: day.getMonth() === popup.today.getMonth()
                readonly property bool isToday: current && day.getDate() === popup.today.getDate()

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: label.implicitHeight + Tokens.spacing.small
                radius: Tokens.radius.small
                color: isToday ? Tokens.c.accent : "transparent"

                PopupText {
                    id: label
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.isToday ? Tokens.c.background : cell.current ? Tokens.c.foreground : Tokens.c.muted
                }
            }
        }
    }

    PopupText {
        text: Qt.formatDateTime(clock.date, "dddd, MMMM d · HH:mm")
    }
}
