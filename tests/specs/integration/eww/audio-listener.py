import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time


def main():
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        runtime = root / "runtime"
        runtime.mkdir()
        for variable, name in (("audioSubscriber", "pactl"), ("audioControl", "control")):
            target = root / name
            source = Path(os.environ[variable]).read_text().split("\n", 1)[1]
            target.write_text(f"#!{sys.executable}\n{source}")
            target.chmod(0o755)
        (root / "sink").write_text("Volume: 0.42 [MUTED]\n")
        (root / "source").write_text("Volume: 0.73\n")
        (root / "graph").write_text("[]")
        os.mkfifo(root / "events")
        events = os.open(root / "events", os.O_RDWR)
        environment = dict(
            os.environ,
            AUDIO_TEST_ROOT=str(root),
            TMPDIR=str(runtime),
            EWW_AUDIO_PACTL=str(root / "pactl"),
            EWW_AUDIO_WPCTL=str(root / "control"),
            EWW_AUDIO_PWDUMP=str(root / "control"),
        )
        snapshots = []
        buffered = bytearray()
        with (root / "stderr").open("wb") as stderr:
            process = subprocess.Popen(
                ["eww-audio", "listen"],
                env=environment,
                stdout=subprocess.PIPE,
                stderr=stderr,
                start_new_session=True,
            )
            assert process.stdout is not None

            def wait_for(predicate):
                deadline = time.monotonic() + 60
                while time.monotonic() < deadline:
                    if predicate():
                        return
                    if process.poll() is not None:
                        raise AssertionError(f"listener exited: {process.returncode}")
                    if select.select([process.stdout], [], [], 0.1)[0]:
                        chunk = os.read(process.stdout.fileno(), 65536)
                        if not chunk:
                            raise AssertionError("listener closed stdout")
                        buffered.extend(chunk)
                        while b"\n" in buffered:
                            line, _, remaining = buffered.partition(b"\n")
                            buffered[:] = remaining
                            snapshots.append(json.loads(line))
                raise AssertionError(f"listener made no progress; snapshots={snapshots}")

            def send(*lines):
                os.write(events, ("\n".join(lines) + "\n").encode())

            def graph(client):
                (root / "graph").write_text(json.dumps([
                    {"type": "PipeWire:Interface:Node", "info": {
                        "state": "running", "props": {
                            "media.class": "Stream/Input/Audio", "application.name": client,
                        },
                    }},
                ]))

            def queries():
                path = root / "queries"
                return path.read_text().splitlines() if path.exists() else []

            def subscribers():
                path = root / "subscriptions"
                return [int(pid) for pid in path.read_text().splitlines()] if path.exists() else []

            try:
                wait_for(lambda: bool(snapshots))
                assert len(snapshots) == 1
                assert snapshots[-1]["sink"]["available"] and snapshots[-1]["source"]["available"]
                assert queries().count("") == 1

                for muted in (False, True):
                    (root / "sink").write_text("Volume: 0.42" + (" [MUTED]" if muted else "") + "\n")
                    send("Event 'change' on sink #42")
                    wait_for(lambda: snapshots[-1]["sink"]["muted"] == muted)
                assert [state["sink"]["muted"] for state in snapshots] == [True, False, True]
                assert queries().count("") == 1, "volume updates re-read the graph"

                before = len(snapshots)
                graph("burst-complete")
                send(*(["Event 'change' on sink #42"] * 128),
                     "Event 'change' on source #43", "Event 'change' on card #12",
                     "Event 'change' on client #7", "Event 'change' on source-output #44")
                wait_for(lambda: snapshots[-1]["source"]["clients"] == ["burst-complete"])
                assert len(snapshots) == before + 1, "unchanged bursts published duplicate state"
                assert queries().count("") == 2, "burst caused redundant graph reads"
                assert queries().count("inspect @DEFAULT_AUDIO_SINK@") == 1
                assert queries().count("inspect @DEFAULT_AUDIO_SOURCE@") == 1

                (root / "sink").write_text("invalid volume\n")
                (root / "graph").write_text("not JSON")
                send("Event 'change' on server #0")
                wait_for(lambda: not snapshots[-1]["sink"]["available"])
                assert snapshots[-1]["source"]["clients"] == []

                (root / "sink").write_text("Volume: 0.55\n")
                graph("reconnected")
                previous_subscribers = len(subscribers())
                send("disconnect")
                wait_for(lambda: len(subscribers()) > previous_subscribers)
                wait_for(lambda: snapshots[-1]["source"]["clients"] == ["reconnected"])
                assert snapshots[-1]["sink"]["available"]
                assert snapshots[-1]["sink"]["volume"] == 55

                process.terminate()
                process.wait(timeout=15)
                assert process.returncode == 0
                for pid in subscribers():
                    try:
                        os.kill(pid, 0)
                    except ProcessLookupError:
                        continue
                    raise AssertionError(f"subscriber {pid} survived listener termination")
                assert not list(runtime.iterdir()), "listener left temporary files"
                assert not (root / "stderr").read_text(), (root / "stderr").read_text()
            except BaseException:
                print((root / "stderr").read_text())
                print(f"snapshots: {snapshots}")
                print(f"queries: {queries()}")
                raise
            finally:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=15)
                process.stdout.close()
                os.close(events)


if __name__ == "__main__":
    main()
