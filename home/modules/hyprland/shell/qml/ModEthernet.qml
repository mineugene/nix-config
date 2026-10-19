import QtQuick

// A machine with no interface at all still has to say so: Ethernet stands in
// for the whole network and stays visible when neither kind exists.
NetworkRing {
    id: root

    function glyph() {
        const e = link;
        if (!e.available)
            return "\u{F0C9B}";
        if (e.state === "connecting")
            return "\u{F0C9D}";
        if (e.connected)
            return e.internet ? "\u{F0200}" : "\u{F015B}";
        return "\u{F0202}";
    }

    function describe() {
        const e = link;
        if (!e.available)
            return "Ethernet · unavailable";
        if (e.connected && e.internet)
            return e.name + " · " + e.ip;
        if (e.connected)
            return e.name + " · no internet";
        if (e.state === "connecting")
            return e.name + " · connecting";
        return e.interface + " · disconnected";
    }

    link: Network.ethernet
    visible: link.available || !Network.wifi.available
    popup: "ethernet"
    icon: glyph()
    tooltip: describe()
}
