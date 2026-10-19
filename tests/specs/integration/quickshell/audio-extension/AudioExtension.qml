import QtQuick
import QtQuick.Layouts

// Stand-in for a downstream audio popup extension; exercises the extension
// hook in the quickshell check. The real downstream component renders its own
// mixer controls here.
PopupSection {
    title: "Extension"

    PopupText {
        Layout.fillWidth: true
        text: "Extension"
    }
}