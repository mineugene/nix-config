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

    // `quickshell ipc --path <bar.qml> call bar reveal` shows the modules the
    // bar collapsed while idle; the mod key bind uses it.
    IpcHandler {
        target: "bar"

        function reveal(): void {
            Bar.reveal();
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
}
