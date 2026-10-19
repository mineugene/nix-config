import QtQuick

// An island holding a row of bar cells.
Island {
    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small / 4
    }
}
