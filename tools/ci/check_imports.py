#!/usr/bin/env python3
"""Import settings that must not drift, checked against what they are for.

Godot writes a fresh `.import` file the first time it sees an asset, with
defaults chosen for ordinary content. Two kinds of asset here are not ordinary
content, and in both cases the default is silently wrong -- the asset loads, the
build passes, and the thing is broken in a way nobody sees until it is on a
phone. Both have shipped broken already.

**Looping sounds must be imported as loops.**

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

**Colour lookup tables must not be compressed, mipmapped, or detected as 3D.**

A LUT is not a picture: it is a function stored as pixels, and every one of
those settings resamples it. `detect_3d/compress_to` is the nasty one, because
it does nothing at import time and then re-imports the texture as compressed the
first time it is used on a 3D material -- so the grade is exact until the moment
something touches it, and then it is not. `act1.png` was set to 0 deliberately;
`annex.png` arrived at 1 and would have taken the whole second act's colour with
it.
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


# LUT imports, and what each setting would do to a function stored as pixels.
LUT_MUST_BE = {
    "compress/mode": ("0", "compressed -- a LUT is a function, not a picture"),
    "mipmaps/generate": ("false", "mipmapped -- the slices would bleed into each other"),
    "detect_3d/compress_to": ("0", "re-imported compressed the first time a 3D material uses it"),
    "process/fix_alpha_border": ("false", "alpha-bordered -- it would rewrite the edge slices"),
}


def _check_luts(problems: list) -> int:
    seen = 0
    for path in sorted((ROOT / "assets/luts").glob("*.png.import")):
        seen += 1
        text = path.read_text()
        for key, (want, why) in LUT_MUST_BE.items():
            found = re.search(r"^%s=(\S+)" % re.escape(key), text, re.M)
            if found is None:
                problems.append(f"{path.name}: no {key}")
            elif found.group(1) != want:
                problems.append(f"{path.name}: {key}={found.group(1)} -- {why}")
    return seen


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

    luts = _check_luts(problems)

    if problems:
        print("error: assets are not imported the way they are meant to be:", file=sys.stderr)
        for line in problems:
            print("       " + line, file=sys.stderr)
        print("       Fix the .import file and commit it.", file=sys.stderr)
        return 1
    print("[import] %d sounds imported as generated, %d LUTs exact" % (len(SOUNDS), luts))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
