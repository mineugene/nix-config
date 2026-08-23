import fcntl
from functools import partial
import json
import os
from pathlib import Path
import pty
import re
import select
import shlex
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time


def controlling_terminal(terminal):
    os.setsid()
    fd = os.open(terminal, os.O_RDWR)
    fcntl.ioctl(fd, termios.TIOCSCTTY, 0)
    os.close(fd)


def main():
    widget = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        directory = root / "project with space"
        directory.mkdir()
        stale = root / "deleted"
        binary = root / "bin"
        binary.mkdir()
        stub = binary / "stub"
        stub.write_text(Path(os.environ["switcherStub"]).read_text())
        stub.chmod(0o755)
        for name in ("tmux", "fzf", "zoxide"):
            (binary / name).symlink_to(stub)
        environment = dict(os.environ, PATH=f"{binary}:{os.environ['PATH']}", TEST_ROOT=str(root))
        environment.pop("TMUX", None)
        environment.pop("WIDGET", None)
        environment["TEST_DIRS"] = f"{directory}\n{stale}\n/"
        failures = []

        def run(row, sessions=None, key="", inside=True, fail_create=False):
            (root / "sessions").write_text(json.dumps(sessions or {}))
            (root / "calls").write_text("")
            env = dict(environment, TEST_ROW=row, TEST_KEY=key)
            if inside:
                env["TMUX"] = "test"
            if fail_create:
                env["TEST_FAIL_CREATE"] = "1"
            master, slave = pty.openpty()
            result = subprocess.run(
                ["zsh", "-f", str(widget)],
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=slave,
                stderr=slave,
                preexec_fn=partial(controlling_terminal, os.ttyname(slave)),
                timeout=60,
            )
            os.close(slave)
            output = b""
            try:
                while chunk := os.read(master, 4096):
                    output += chunk
            except OSError:
                pass
            finally:
                os.close(master)
            calls = [json.loads(line) for line in (root / "calls").read_text().splitlines()]
            return calls, (root / "choices").read_text(), result.returncode, output.decode()

        def check(name, condition, detail):
            if not condition:
                failures.append(name)
                print(f"FAIL {name}: {detail}")
            else:
                print(f"PASS {name}")

        row = f"directory\t\t{directory}\tDIR      {directory}"
        calls, choices, _, _ = run(row)
        check("directory selection", ["new-session", "-d", "-s", directory.name, "-c", str(directory)] in [c[0] for c in calls], calls)
        check("stale directories hidden", str(stale) not in choices, choices)
        check("root directory preserved", "directory\t\t/\t" in choices, choices)

        calls, _, _, _ = run(row, {f"{directory.name}-1": str(directory)}, key="alt-enter")
        check("alt-enter creates next session", ["switch-client", "-t", f"={directory.name}-2"] in [c[0] for c in calls], calls)

        session_row = f"session\twork\t{directory}\tSESSION work"
        calls, _, _, _ = run(session_row, {"work": str(directory)})
        check("inside switches existing session", ["switch-client", "-t", "=work"] in [c[0] for c in calls], calls)

        calls, _, _, output = run(session_row, {"work": str(directory)}, inside=False)
        check("outside attaches with terminal stdin", [["attach-session", "-t", "=work"], True] in calls, (calls, output))

        calls, _, _, _ = run(row, key="alt-enter", inside=False)
        check("outside alt-enter creates and attaches", [["attach-session", "-t", f"={directory.name}-1"], True] in calls, calls)

        calls, _, _, _ = run(row, {f"{directory.name}-other": str(directory)})
        check("prefix does not match another session", any(c[0][0] == "new-session" for c in calls), calls)

        calls, _, status, output = run(row, key="alt-enter", fail_create=True)
        check("creation failure stops attachment", status == 1 and sum(c[0][0] == "new-session" for c in calls) == 1 and not any(c[0][0] in ("attach-session", "switch-client") for c in calls) and "create failed" in output, (calls, output))

        real_tmux = shutil.which("tmux")
        (binary / "tmux").unlink()
        (binary / "tmux").write_text(Path(os.environ["tmuxWrapper"]).read_text())
        environment["REAL_TMUX"] = real_tmux
        (binary / "tmux").chmod(0o755)
        functions = root / "widgets"
        functions.mkdir()
        (functions / "tmux-session-switcher").symlink_to(widget)
        env = dict(
            environment,
            HOME=str(root),
            SHELL=shutil.which("zsh"),
            TERM="xterm-256color",
            TEST_SOCKET=str(root / "tmux.sock"),
            TEST_ROW=session_row,
        )

        def tmux(*args):
            return subprocess.run(
                [str(binary / "tmux"), *args], env=env, capture_output=True, text=True, timeout=30
            )

        try:
            created = tmux("new-session", "-d", "-s", "work", "-c", str(directory))
            assert created.returncode == 0, created.stderr
            for key, expected in (("", "work"), ("alt-enter", "work-1")):
                env["TEST_KEY"] = key
                master, slave = pty.openpty()
                fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
                screen = bytearray()
                env.update(
                    TEST_FUNCTIONS=str(functions),
                    TEST_ATTACH_CONTEXT=str(root / "attach-context"),
                    TEST_PENDING=str(root / "pending"),
                    TEST_READY=str(root / f"ready-{expected}"),
                    TEST_ZLE_SETUP=os.environ["zleSetup"],
                )
                process = subprocess.Popen(
                    ["zsh", "-f", "-i"],
                    env=env,
                    stdin=slave,
                    stdout=slave,
                    stderr=slave,
                    preexec_fn=partial(controlling_terminal, os.ttyname(slave)),
                )
                os.close(slave)

                def wait_for(predicate):
                    deadline = time.monotonic() + 60
                    while time.monotonic() < deadline:
                        if predicate():
                            return True
                        if process.poll() is not None:
                            return False
                        if select.select([master], [], [], 0.05)[0]:
                            try:
                                screen.extend(os.read(master, 65536))
                            except OSError:
                                return False
                        if predicate():
                            return True
                    return False

                try:
                    ready = root / f"ready-{expected}"
                    os.write(master, b'source "$TEST_ZLE_SETUP"\n')
                    assert wait_for(ready.exists), "interactive shell did not initialize"
                    screen.clear()
                    os.write(master, b"echo unfinished\x1bt")
                    attached = wait_for(
                        lambda: expected in tmux("list-clients", "-F", "#{session_name}").stdout.splitlines()
                    )
                    check(f"ZLE attaches {expected}", attached, f"exit={process.poll()}")
                    check(f"tmux renders alternate screen {expected}", wait_for(lambda: re.search(rb"\x1b\[\?(?:47|1047|1049)h", screen) is not None), "no alternate-screen output")
                    context = root / "attach-context"
                    check(f"attachment runs outside ZLE {expected}", context.exists() and context.read_text().strip() == "inactive", context.read_text() if context.exists() else "no attachment")
                    marker = root / f"input-{expected}"
                    os.write(master, f": > {shlex.quote(str(marker))}\n".encode())
                    responsive = wait_for(marker.exists)
                    check(f"ZLE attachment accepts input {expected}", responsive, tmux("list-clients", "-F", "#{client_pid} #{client_flags}").stdout)
                    tmux("detach-client", "-s", f"={expected}")
                    pending = root / "pending"
                    pending.unlink(missing_ok=True)
                    os.write(master, b"\x18r")
                    check(f"pending input restored {expected}", wait_for(pending.exists) and pending.read_text().strip() == "echo unfinished", pending.read_text() if pending.exists() else "no pending input")
                    returned = root / f"returned-{expected}"
                    os.write(master, b"\x15" + f": > {shlex.quote(str(returned))}\n".encode())
                    check(f"ZLE prompt resumes {expected}", wait_for(returned.exists), "no shell input after detach")
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=15)
                    os.close(master)
        finally:
            tmux("kill-server")

        if failures:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
