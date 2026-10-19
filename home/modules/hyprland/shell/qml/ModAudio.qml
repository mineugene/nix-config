import QtQuick

// One audio island: both meters open the same controls, so the island carries
// that click as a whole. Each meter keeps its own middle, right, and wheel
// actions, which the island's own surface leaves to the cell under the pointer.
Pill {
    id: root

    // The island plate belongs to the expanded bar; a quiet bar keeps the two
    // meters bare.
    color: Bar.shown ? Tokens.c.surfaceHover : "transparent"

    MouseArea {
        parent: root
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Desktop.toggle("audio")
    }

    AudioRing {
        menuName: "audio-output"
        volume: Audio.sinkVolume
        icon: Audio.outputGlyph(Audio.sinkVolume, Audio.sinkMuted, Audio.available)
        tooltip: !Audio.available ? "Audio status unavailable" : Audio.sinkMuted ? "Output muted · middle-click to unmute" : "Output " + Audio.sinkVolume + "% · " + Audio.sinkLabel + " · middle-click to mute"
        onToggleMute: Audio.toggleMute(Audio.sink)
        onChange: delta => Audio.step(Audio.sink, delta)
    }
    AudioRing {
        visible: Audio.sourceAvailable
        menuName: "audio-input"
        volume: Audio.sourceVolume
        icon: Audio.sourceMuted ? "\u{F131}" : "\u{F130}"
        tooltip: Audio.sourceMuted ? "Microphone muted · middle-click to unmute" : "Microphone " + Audio.sourceVolume + "%" + (Audio.sourceClient ? " · in use by " + Audio.sourceClient : "") + " · middle-click to mute"
        onToggleMute: Audio.toggleMute(Audio.source)
        onChange: delta => Audio.step(Audio.source, delta)
    }
}
