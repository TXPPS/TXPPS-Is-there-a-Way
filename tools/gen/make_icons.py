#!/usr/bin/env python3
"""Generate every app/PWA icon for "Is There a Way?".

The icon is the game's core image, drawn from first principles rather than
sourced: a sealed bulkhead in the dark with a single seam of sodium light
escaping it, crossed by the faint horizontal stain of a waterline. No text --
at 60px on a home screen, text is mud.

Deterministic: same inputs -> byte-identical PNGs, so CI can assert the
committed files really are the script's output.

Usage: python3 tools/gen/make_icons.py [--out assets/icons]
"""
from __future__ import annotations

import argparse
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from png import write_rgba  # noqa: E402

# --- palette (linear-ish sRGB bytes) -----------------------------------------
STEEL_TOP = (14, 15, 17)
STEEL_BOTTOM = (6, 6, 7)
SODIUM = (255, 176, 84)
SODIUM_DEEP = (194, 96, 24)
WATERLINE = (46, 41, 33)
LEAF_SHADOW = (0, 0, 0)

SEAM_X = 0.545          # slightly off-centre; dead-centre reads as a logo, not a door
SEAM_HALF_WIDTH = 0.011
GLOW_FALLOFF = 30.0     # higher = tighter pool of light
WATER_Y = 0.735         # silt line sits low; it is a stain, not a horizon
WATER_THICKNESS = 0.022


def _mix(a, b, t: float):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _add(base, colour, amount: float):
    amount = max(0.0, min(1.0, amount))
    return tuple(min(255, int(round(base[i] + colour[i] * amount))) for i in range(3))


def render(size: int) -> bytearray:
    buf = bytearray(size * size * 4)
    inv = 1.0 / (size - 1)
    for y in range(size):
        v = y * inv
        row_base = _mix(STEEL_TOP, STEEL_BOTTOM, v * v)
        # Silt stain: soft below, harder along its top edge, the way deposits dry.
        edge = (v - WATER_Y) / WATER_THICKNESS
        water = math.exp(-(edge * edge) * (2.4 if v < WATER_Y else 0.35))
        row_base = _mix(row_base, WATERLINE, water * 0.5)
        # Broad, low-frequency vertical falloff so the spill never forms a band.
        spill_v = 0.62 + 0.38 * math.exp(-((v - 0.46) ** 2) * 0.85)

        for x in range(size):
            u = x * inv
            d = abs(u - SEAM_X)
            if d <= SEAM_HALF_WIDTH:
                # The seam itself: hot core falling off to its own edges.
                core = 1.0 - (d / SEAM_HALF_WIDTH) ** 2
                # Brightest where the leaf is most warped -- the upper third.
                gate = 0.5 + 0.5 * math.exp(-((v - 0.32) ** 2) * 2.6)
                rgb = _mix(SODIUM_DEEP, SODIUM, core * gate)
            else:
                base = row_base
                if u > SEAM_X:
                    # The door leaf is recessed: a hair darker, with a contact
                    # shadow hugging the seam. This is what makes it a door.
                    contact = math.exp(-(d - SEAM_HALF_WIDTH) * 90.0)
                    base = _mix(base, LEAF_SHADOW, 0.10 + 0.45 * contact)
                glow = math.exp(-(d - SEAM_HALF_WIDTH) * GLOW_FALLOFF) * spill_v
                rgb = _add(base, SODIUM_DEEP, glow * 0.40)

            i = (y * size + x) * 4
            buf[i] = rgb[0]
            buf[i + 1] = rgb[1]
            buf[i + 2] = rgb[2]
            buf[i + 3] = 255
    return buf


SIZES = {
    # PWA manifest (Godot's web exporter wires these three itself)
    144: "icon_144.png",
    180: "icon_180.png",   # apple-touch-icon
    512: "icon_512.png",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/icons")
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for size, name in sorted(SIZES.items()):
        write_rgba(out / name, size, size, render(size))
        print(f"[icons] {out / name}  {size}x{size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
