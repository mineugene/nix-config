#!/usr/bin/env python3
import os
from pathlib import Path
import sys

root = Path(os.environ["AUDIO_TEST_ROOT"])
with (root / "subscriptions").open("a") as log:
    log.write(f"{os.getpid()}\n")
with (root / "events").open() as events:
    for event in events:
        if event.strip() == "disconnect":
            sys.exit(0)
        print(event.strip(), flush=True)
