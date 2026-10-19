import Quickshell
import Quickshell.Io

ShellRoot {
    // `quickshell ipc call popup toggle <name>` opens a popup from a key
    // binding or a script.
    IpcHandler {
        target: "popup"

        function toggle(name: string): void {
            Desktop.toggle(name);
        }

        function close(): void {
            Desktop.closeAll();
        }
    }

    TopBar {}
    Backdrop {}
    PopupMenu {}
    PopupProfile {}
    PopupCalendar {}
    PopupHardware {}
    PopupAudio {}
    PopupDevices {
        name: "audio-output"
        sinks: true
    }
    PopupDevices {
        name: "audio-input"
        sinks: false
    }
    PopupNotifications {}
    NotificationToasts {}
    PopupWifi {}
    PopupEthernet {}
    PopupBluetooth {}
    PopupBattery {}
    PopupPowerProfile {}
}
