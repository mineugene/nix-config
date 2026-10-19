pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "AudioRouting.js" as Routing

// The default sink and source come from PipeWire directly, so a hardware mute
// or knob turn shows on the next event instead of the next poll.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // An extension that owns a node's gain or mute answers for it, so a
    // backend can read and write both through one node-name test.
    Loader {
        id: backend
        active: Tokens.audioExtension
        source: "AudioBackend.qml"
    }

    function backendHandles(node) {
        return backend.item !== null && backend.item.handles(node);
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function label(node) {
        return node ? (node.description || node.nickname || node.name) : "Unavailable";
    }

    readonly property bool available: sink !== null && sink.audio !== null
    readonly property int sinkVolume: volume(sink)
    readonly property bool sinkMuted: backendHandles(sink) ? backend.item.muted(sink) : (sink?.audio?.muted ?? false)
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
    property var captureTargets: ({})
    readonly property var captureApplications: Routing.captureApplications(Pipewire.nodes.values, captureTargets)
    readonly property bool captureRouting: captureRoute.running

    Process {
        id: captureMetadata
        command: ["pw-metadata", "-n", "default"]
        running: Desktop.popup === "audio"
        stdout: SplitParser {
            onRead: line => {
                const update = Routing.parseMetadataLine(line);
                if (update)
                    root.captureTargets = Routing.updateCaptureTargets(root.captureTargets, update);
            }
        }
    }

    Process {
        id: captureRoute
    }

    function captureTarget(app) {
        if (!app.target)
            return { id: "", label: "Follow default", unavailable: false };
        const source = inputs.find(item => item.node.name === app.target || String(item.node.properties["object.serial"]) === String(app.target));
        return {
            id: source ? source.node.name : app.target,
            label: source ? source.label : app.target,
            unavailable: !source
        };
    }

    function setCaptureTarget(app, target) {
        let next = root.captureTargets;
        for (const node of app.nodes) {
            next = Routing.updateCaptureTargets(next, { id: node.id, target: target ? target.name : null });
        }
        root.captureTargets = next;
        captureRoute.command = ["shell-audio", "capture-target", target ? target.name : "-1"].concat(app.nodes.map(node => String(node.id)));
        captureRoute.running = true;
    }

    function setDefault(node, sinks) {
        // Quickshell skips unchanged preferences even when the effective default differs.
        if (sinks) {
            if (Pipewire.preferredDefaultAudioSink === node && root.sink !== node)
                Pipewire.preferredDefaultAudioSink = null;
            Pipewire.preferredDefaultAudioSink = node;
        } else {
            if (Pipewire.preferredDefaultAudioSource === node && root.source !== node)
                Pipewire.preferredDefaultAudioSource = null;
            Pipewire.preferredDefaultAudioSource = node;
        }
    }

    function outputGlyph(volume, muted, available = true) {
        if (!available)
            return "\u{F026}";
        if (muted)
            return "\u{EEE8}";
        if (volume === 0)
            return "\u{F026}";
        if (volume < 34)
            return "\u{F027}";
        if (volume < 67)
            return "\u{EFCF}";
        return "\u{F028}";
    }

    // PipeWire is not the gain's owner for a backend-owned node: the backend
    // reads and writes it, and the node's own volume stays where that owner
    // puts it.
    function volume(node) {
        if (backendHandles(node))
            return backend.item.volume(node);
        return Math.round((node?.audio?.volume ?? 0) * 100);
    }

    function setVolume(node, percent) {
        const value = Math.max(0, Math.min(100, percent));
        if (backendHandles(node)) {
            backend.item.setVolume(node, value);
            return;
        }
        if (node?.audio)
            node.audio.volume = value / 100;
    }

    function step(node, delta) {
        setVolume(node, volume(node) + delta);
    }

    function toggleMute(node) {
        if (backendHandles(node)) {
            backend.item.toggleMute(node);
            return;
        }
        if (Tokens.audioExtension && node && node.name.startsWith("OpenXLR_ch_"))
            return;
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
