import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

ShellRoot {
    id: test

    property int phase: 0
    property bool finished: false

    function node(name) {
        return Pipewire.nodes.values.find(item => item.name === name) || null;
    }

    function selected(suffix) {
        return Audio.sink && Audio.sink.name === "test_sink_" + suffix && Audio.source && Audio.source.name === "test_source_" + suffix;
    }

    Process {
        id: overrideSink
        command: ["pw-metadata", "-n", "default", "0", "default.audio.sink", '{"name":"test_sink_b"}', "Spa:String:JSON"]
    }

    Process {
        id: overrideSource
        command: ["pw-metadata", "-n", "default", "0", "default.audio.source", '{"name":"test_source_b"}', "Spa:String:JSON"]
    }

    Timer {
        interval: 10
        repeat: true
        running: !test.finished
        onTriggered: {
            switch (test.phase) {
            case 0:
                if (!Pipewire.ready || !Audio.available || !Audio.sourceAvailable || !node("test_sink_a") || !node("test_source_a") || !node("test_sink_b") || !node("test_source_b"))
                    return;
                Audio.setDefault(node("test_sink_a"), true);
                Audio.setDefault(node("test_source_a"), false);
                test.phase++;
                break;
            case 1:
                if (!selected("a") || Pipewire.preferredDefaultAudioSink !== node("test_sink_a") || Pipewire.preferredDefaultAudioSource !== node("test_source_a"))
                    return;
                overrideSink.running = true;
                overrideSource.running = true;
                test.phase++;
                break;
            case 2:
                if (overrideSink.running || overrideSource.running)
                    return;
                if (!selected("b")) {
                    overrideSink.running = true;
                    overrideSource.running = true;
                    return;
                }
                if (Pipewire.preferredDefaultAudioSink !== node("test_sink_a") || Pipewire.preferredDefaultAudioSource !== node("test_source_a"))
                    return;
                Audio.setDefault(node("test_sink_a"), true);
                Audio.setDefault(node("test_source_a"), false);
                test.phase++;
                break;
            case 3:
                if (!selected("a"))
                    return;
                Audio.setDefault(node("test_sink_b"), true);
                Audio.setDefault(node("test_source_b"), false);
                test.phase++;
                break;
            case 4:
                if (!selected("b"))
                    return;
                test.finished = true;
                console.log("native audio defaults ok");
                Qt.quit();
                break;
            }
        }
    }

    Timer {
        interval: 60000
        running: !test.finished
        onTriggered: {
            test.finished = true;
            console.error("native audio defaults FAIL: selection did not take effect in phase " + test.phase);
            Qt.quit();
        }
    }
}
