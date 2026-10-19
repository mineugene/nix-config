import QtQuick
import QtQuick.Layouts

DesktopPopup {
    id: popup

    name: "battery"

    function level() {
        return Power.battery.percent === null ? " – " : Power.battery.percent + "%";
    }

    function time() {
        const seconds = Power.battery.time_s;
        if (seconds === null || seconds <= 0)
            return " – ";
        return Power.timeText(seconds) + (Power.battery.status === "charging" ? " to full" : " left");
    }

    PopupTitle {
        text: "Battery"
    }

    PopupSection {
        title: "Charge"
        PopupDetail {
            name: "Level"
            value: popup.level()
        }
        PopupDetail {
            name: "State"
            value: Power.batteryStateText()
        }
        PopupDetail {
            name: "Time"
            value: popup.time()
        }
    }

    PopupSection {
        visible: Power.battery.devices.length > 1
        title: "Batteries"

        Repeater {
            model: Power.battery.devices

            PopupDetail {
                required property var modelData
                name: modelData.name
                value: (modelData.percent === null ? " – " : modelData.percent + "%") + " · " + modelData.status
            }
        }
    }
}