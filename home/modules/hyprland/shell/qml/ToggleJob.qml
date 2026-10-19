import QtQuick
import Quickshell
import Quickshell.Io

// A radio switch that locks its control until the state the user asked for is
// observed, not merely until the command exits. The state reaches the shell
// through a poll that lags the command, so without the settle predicate the
// control would re-enable while it still shows the old state. A command that
// outlives `timeout` is cancelled so the control never stays locked.
Scope {
    id: job

    property string label: ""
    property int timeout: 10000
    property bool busy: false
    property bool expired: false
    // Reports whether the requested state is now visible; null means the
    // command's exit is enough.
    property var settled: null
    property bool exited: false

    function start(command, settled) {
        if (busy)
            return;
        expired = false;
        exited = false;
        job.settled = settled ?? null;
        busy = true;
        process.command = command;
        process.running = true;
        guard.restart();
        watch.start();
    }

    function finish() {
        guard.stop();
        watch.stop();
        busy = false;
        job.settled = null;
    }

    function evaluate() {
        if (!busy || !exited)
            return;
        if (job.settled === null || job.settled())
            finish();
    }

    function fail(reason) {
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Shell", label, reason]);
    }

    Process {
        id: process
        onExited: code => {
            job.exited = true;
            if (code !== 0 && !job.expired) {
                finish();
                job.fail("Failed to switch " + job.label + " (exit " + code + ").");
            } else {
                evaluate();
            }
        }
    }

    // The radio state lags the command, so poll the predicate until it holds.
    Timer {
        id: watch
        interval: 100
        repeat: true
        onTriggered: evaluate()
    }

    Timer {
        id: guard
        interval: job.timeout
        onTriggered: {
            job.expired = true;
            process.running = false;
            finish();
            job.fail("Timeout occurred while attempting to switch on/off the " + job.label + ".");
        }
    }
}