import QtQuick
import QtQuick.Layouts

DesktopPopup {
    name: "audio"

    PopupTitle {
        text: "Audio"
    }

    AudioSection {
        title: "Output"
        sinks: true
        node: Audio.sink
        available: Audio.available
        volume: Audio.sinkVolume
        label: Audio.sinkLabel
        devices: Audio.outputs
        glyph: Audio.outputGlyph(Audio.sinkVolume, Audio.sinkMuted, Audio.available)
    }

    AudioSection {
        title: "Input"
        sinks: false
        node: Audio.source
        available: Audio.sourceAvailable
        volume: Audio.sourceVolume
        label: Audio.sourceLabel
        devices: Audio.inputs
        glyph: Audio.sourceMuted ? "\u{F131}" : "\u{F130}"
    }

    // A downstream extension (a non-PipeWire mixer) fills the Mixer section. An
    // unset extension hides the section, so the popup is unchanged without one.
    PopupSection {
        title: "Mixer"
        visible: Tokens.audioExtension

        Loader {
            Layout.fillWidth: true
            active: Tokens.audioExtension
            source: Tokens.audioExtension ? "AudioExtension.qml" : ""
        }
    }
}