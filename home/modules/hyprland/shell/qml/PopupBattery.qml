import QtQuick
import QtQuick.Layouts

// The power panel: the charge readings while the host has a battery, and the
// daemon's power modes wherever the host enables it, so an AC-only host reaches
// the same surface as a laptop.
DesktopPopup {
    id: popup

    name: "battery"

    readonly property bool hasBattery: Power.battery.present === true

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
        text: popup.hasBattery ? "Battery" : "Power"
    }

    PopupSection {
        visible: popup.hasBattery
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
        visible: popup.hasBattery && Power.battery.devices.length > 1
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

    PopupSection {
        visible: Power.profileAvailable
        title: "Power mode"

        PopupDetail {
            visible: Power.profile.inhibited === true || Power.profile.degraded === true
            name: "State"
            value: Power.profile.inhibited === true ? "Inhibited" : "Degraded"
        }

        Repeater {
            model: Power.profileNames

            PopupAction {
                required property string modelData
                text: (Power.profile.active === modelData ? "✓ " : "") + Power.profileLabel(modelData)
                onTriggered: {
                    Power.setProfile(modelData);
                    Desktop.closeAll();
                }
            }
        }
    }
}
