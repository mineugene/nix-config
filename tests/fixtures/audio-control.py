#!/usr/bin/env python3
import os
from pathlib import Path
import sys

root = Path(os.environ["AUDIO_TEST_ROOT"])
command = sys.argv[1:]
with (root / "queries").open("a") as log:
    log.write(" ".join(command) + "\n")
if not command:
    print((root / "graph").read_text())
elif command[0] == "get-volume":
    state = "sink" if command[1] == "@DEFAULT_AUDIO_SINK@" else "source"
    print((root / state).read_text())
elif command[0] == "inspect":
    print('node.description = "Test device"')
elif command[0] == "status":
    print("Sinks:\n * 42. Test output [vol: 0.42]\nSources:\n * 43. Test input [vol: 0.73]\nFilters:")
else:
    sys.exit(1)
