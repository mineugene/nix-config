import QtQuick

// The wired link is reported, never toggled: unplugging a cable is the only
// way its carrier changes, so a switch here would be a lie.
DesktopPopup {
    id: popup

    readonly property var link: Network.ethernet

    function rate(bytes) {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MiB/s" : (bytes / 1024).toFixed(1) + " KiB/s";
    }

    function dash(v) {
        return v === "" || v === null || v === undefined ? " – " : v;
    }

    name: "ethernet"

    PopupTitle {
        text: "Ethernet"
    }

    PopupSection {
        PopupDetail {
            name: "Interface"
            value: popup.dash(popup.link.interface)
        }
        PopupDetail {
            name: "IPv4"
            value: popup.dash(popup.link.ip)
        }
        PopupDetail {
            name: "Download"
            value: popup.rate(popup.link.rx_bytes_per_second)
        }
        PopupDetail {
            name: "Upload"
            value: popup.rate(popup.link.tx_bytes_per_second)
        }
    }
}
