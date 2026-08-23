import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import sys
import termios
import time
import fcntl

ICON_GAP = rb"(?:\x1b\[[0-9;]*m)*\x20(?:\x1b\[[0-9;]*m)*\x20"
HOSTS_ICON = re.compile(b"\xf3\xb0\x80\x82" + ICON_GAP)
BASIC_ICON = re.compile(rb"(?:\xee|\xef)[\x80-\xbf]{2}" + ICON_GAP)
ERRORS = re.compile(rb"\b(?:error|failed|not found)\b|preset settings", re.IGNORECASE)


def rendered(screen):
    return b"tree-leaf" in screen and HOSTS_ICON.search(screen) and BASIC_ICON.search(screen)


def main():
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    process = subprocess.Popen(
        ["yazi", "0-dir"], stdin=slave, stdout=slave, stderr=slave, start_new_session=True
    )
    os.close(slave)
    screen = bytearray()
    deadline = time.monotonic() + 60
    try:
        while time.monotonic() < deadline and not rendered(screen) and process.poll() is None:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    screen.extend(os.read(master, 65536))
                except OSError:
                    break
        complete = rendered(screen)
        if complete:
            os.write(master, b"q")
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
        Path(sys.argv[1]).write_bytes(screen)
        if not complete:
            raise SystemExit("yazi did not render the expected preview and icon padding")
        if ERRORS.search(screen):
            raise SystemExit("yazi reported a configuration or plugin error")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=15)
        os.close(master)


if __name__ == "__main__":
    main()
