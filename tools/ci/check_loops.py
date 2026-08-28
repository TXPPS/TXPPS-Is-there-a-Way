#!/usr/bin/env python3
"""Every looping sound must be imported as a loop, and no other one may be.

This exists because getting it wrong shipped twice. Godot's WAV importer writes
`edit/loop_mode=0` -- "Detect From WAV" -- into a new .import file, and nothing
in a generated WAV tells it to loop, so every new looping sound arrives silently
broken: it plays once and stops. The enum is

    0 Detect From WAV   1 Disabled   2 Forward   3 Ping-Pong   4 Backward

and the first time this was fixed it was fixed to 1, which is *Disabled*, which
looks like a fix and is not one. It passed locally because the test sampled
inside the first sixteen seconds.

`make_audio.py` already knows which sounds loop -- it is the flag beside each
one in SOUNDS -- so that table is the authority and this compares the .import
files against it.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/audio"))

FORWARD = 2
LOOP_MODE = re.compile(r"^edit/loop_mode=(\d+)", re.M)

NAMES = {0: "Detect From WAV", 1: "Disabled", 2: "Forward", 3: "Ping-Pong", 4: "Backward"}


def main() -> int:
    from make_audio import SOUNDS  # noqa: E402

    problems = []
    for name, (_generator, loops) in SOUNDS.items():
        path = ROOT / "assets/audio" / f"{name}.wav.import"
        if not path.exists():
            problems.append(f"{name}: no .import file -- has it been imported?")
            continue
        found = LOOP_MODE.search(path.read_text())
        if found is None:
            problems.append(f"{name}: .import has no edit/loop_mode")
            continue
        mode = int(found.group(1))
        want = FORWARD if loops else 0
        if mode != want:
            problems.append(
                "%s: imported as %s (%d), should be %s (%d)"
                % (name, NAMES.get(mode, "?"), mode, NAMES.get(want, "?"), want)
            )

    if problems:
        print("error: sounds are not imported the way they are generated:", file=sys.stderr)
        for line in problems:
            print("       " + line, file=sys.stderr)
        print("       Fix edit/loop_mode in the .import file and commit it.", file=sys.stderr)
        return 1
    print("[audio] %d sounds imported as generated" % len(SOUNDS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
