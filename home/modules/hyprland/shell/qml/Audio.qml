pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The default sink and source come from PipeWire directly, so a hardware mute
// or knob turn shows on the next event instead of the next poll.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function label(node) {
        return node ? (node.description || node.nickname || node.name) : "Unavailable";
    }

    readonly property bool available: sink !== null && sink.audio !== null
    readonly property int sinkVolume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property string sinkLabel: label(sink)

    readonly property bool sourceAvailable: source !== null && source.audio !== null
    readonly property int sourceVolume: Math.round((source?.audio?.volume ?? 0) * 100)
    readonly property bool sourceMuted: source?.audio?.muted ?? false
    readonly property string sourceLabel: label(source)

    // A monitor is a sink's loopback source; it cannot be a capture default, so
    // offering it would revert the selection on the next policy pass.
    function isMonitor(node) {
        const name = node.properties["node.name"] ?? "";
        return name.endsWith(".monitor");
    }

    function devices(sinks) {
        const current = sinks ? sink : source;
        return Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink === sinks && (sinks || !isMonitor(n))).map(n => ({
                    node: n,
                    label: label(n),
                    active: current !== null && n.id === current.id
                }));
    }

    readonly property var outputs: devices(true)
    readonly property var inputs: devices(false)

    function setDefault(node, sinks) {
        if (sinks)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    function setVolume(node, percent) {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    function step(node, delta) {
        if (node?.audio)
            setVolume(node, Math.round(node.audio.volume * 100) + delta);
    }

    function toggleMute(node) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    // The microphone is an alarm, not a setting: it says something only while
    // an application is listening.
    PwNodeLinkTracker {
        id: capture
        node: root.source
    }

    readonly property var captureNodes: {
        const out = [];
        const groups = capture.linkGroups;
        for (let i = 0; i < groups.length; i++) {
            const other = groups[i].source === root.source ? groups[i].target : groups[i].source;
            if (other && other.isStream)
                out.push(other);
        }
        return out;
    }

    PwObjectTracker {
        objects: root.captureNodes
    }

    readonly property bool sourceActive: captureNodes.length > 0
    readonly property string sourceClient: captureNodes.length > 0 ? (captureNodes[0].properties["application.name"] || captureNodes[0].description || "") : ""
}
