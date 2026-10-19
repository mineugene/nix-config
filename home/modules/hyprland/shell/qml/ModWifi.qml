import QtQuick

// A system-level disabled radio is not a control the user can toggle, so it
// leaves the bar entirely.
NetworkRing {
    id: root

    function glyph() {
        const w = link;
        if (w.state === "off" || w.state === "unavailable")
            return "\u{F092D}";
        if (w.state === "connecting")
            return ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}", "\u{F0925}", "\u{F0922}"][Network.frame];
        if (!w.connected)
            return "\u{F092F}";
        const s = w.signal ?? -1;
        const rung = s < 40 ? 0 : s < 60 ? 1 : s < 80 ? 2 : 3;
        return (w.internet ? ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"] : ["\u{F0920}", "\u{F0923}", "\u{F0926}", "\u{F0929}"])[rung];
    }

    function describe() {
        const w = link;
        if (w.connected && w.internet)
            return w.name + " · " + w.ip;
        if (w.connected)
            return w.name + " · no internet";
        if (w.state === "connecting")
            return w.name + " · connecting";
        if (w.state === "off")
            return w.interface + " · disabled";
        return w.interface + " · disconnected";
    }

    link: Network.wifi
    visible: link.available && link.state !== "unavailable"
    popup: "wifi"
    enabled: !Network.wifiBusy
    opacity: enabled ? 1 : 0.5
    icon: glyph()
    tooltip: describe()
    onMiddleClicked: Network.toggleWifi()
}
