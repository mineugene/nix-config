import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: Math.max(0, parent.width - 2 * Tokens.spacing.normal)
    Layout.topMargin: Tokens.spacing.small
    Layout.bottomMargin: Tokens.spacing.small
    implicitHeight: Tokens.borderWidth
    color: Tokens.c.border
}
