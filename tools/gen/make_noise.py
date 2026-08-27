#!/usr/bin/env python3
"""Generate the one noise texture every surface in the game is made from.

The budget rule (`docs/BUDGETS.md`, `docs/ART_BIBLE.md`) is that almost none of
the payload may go to texture data, so there is exactly one: a 256x256 RGBA
tile whose four channels are four different scales of the same idea. Every
material is `src/render/surface.gdshader` reading this file with different
parameters, triplanar-mapped, so six materials cost one texture and one shader.

    R  4 px features   micro roughness breakup, condensation
    G 16 px features   rust patches, paint chipping, silt settling
    B 64 px features   large wet/dry variation across a wall
    A  stretched 8:1   mineral staining, which runs down and not along

All four tile. Value noise on a wrapping integer lattice, deterministic from a
fixed seed, so the committed PNG really is this script's output and CI can say
so.

Usage: python3 tools/gen/make_noise.py [--out assets/textures]
"""
from __future__ import annotations

import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from png import write_rgba  # noqa: E402

SIZE = 256
SEED = 0x1D0C

# (cells across, cells down, octaves) per channel. Cells wrap, so the result
# tiles; more cells means finer features.
CHANNELS = (
    (64, 64, 3),   # R -- micro
    (16, 16, 4),   # G -- patches
    (4, 4, 3),     # B -- broad
    (24, 3, 3),    # A -- streaks: many cells across, few down, so it runs down
)


def _hash(x: int, y: int, salt: int) -> float:
    """Deterministic lattice value in 0..1. A cheap integer hash beats a PRNG
    here because it has to give the same answer for the same cell however many
    times it is asked, including across the wrap."""
    h = (x * 374761393 + y * 668265263 + salt * 2246822519 + SEED) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF) / float(0xFFFFFF)


def _smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def _value_noise(u: float, v: float, cx: int, cy: int, salt: int) -> float:
    fx, fy = u * cx, v * cy
    x0, y0 = int(fx) % cx, int(fy) % cy
    x1, y1 = (x0 + 1) % cx, (y0 + 1) % cy
    tx, ty = _smooth(fx - int(fx)), _smooth(fy - int(fy))
    a = _hash(x0, y0, salt)
    b = _hash(x1, y0, salt)
    c = _hash(x0, y1, salt)
    d = _hash(x1, y1, salt)
    top = a + (b - a) * tx
    bot = c + (d - c) * tx
    return top + (bot - top) * ty


def _fbm(u: float, v: float, cx: int, cy: int, octaves: int, salt: int) -> float:
    total, amplitude, weight = 0.0, 1.0, 0.0
    for octave in range(octaves):
        scale = 1 << octave
        total += amplitude * _value_noise(u, v, cx * scale, cy * scale, salt + octave * 101)
        weight += amplitude
        amplitude *= 0.5
    return total / weight


def build() -> bytearray:
    pixels = bytearray(SIZE * SIZE * 4)
    for index, (cx, cy, octaves) in enumerate(CHANNELS):
        for y in range(SIZE):
            v = y / SIZE
            row = y * SIZE * 4
            for x in range(SIZE):
                value = _fbm(x / SIZE, v, cx, cy, octaves, index * 7919)
                pixels[row + x * 4 + index] = int(max(0.0, min(1.0, value)) * 255.0 + 0.5)
    return pixels


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/textures")
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    path = out / "surface_noise.png"
    write_rgba(path, SIZE, SIZE, build())
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
