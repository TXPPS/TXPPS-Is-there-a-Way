#!/usr/bin/env python3
"""Generate the per-act colour grade as a 16x16x16 LUT strip.

One act, one LUT, one 256x16 PNG. The grade is a function, written here, rather
than a picture somebody tweaked in a photo editor -- so it is reviewable as
code, regenerable, and byte-identical between runs.

The strip layout is the usual one: sixteen 16x16 slices laid left to right,
slice index is blue, x within a slice is red, y is green.
`src/render/post.gdshader` reads it with two taps and a lerp across the blue
axis, which is why the file must import with linear filtering and no mipmaps.

Act 1's grade, in words (docs/ART_BIBLE.md, "Palette"):
  - crush the black point a little, because the majority of most frames is black
    and a lifted black on an OLED phone in a dark room looks like fog;
  - tint the shadows toward the cold fill, which is the lie that stands in for
    bounce light;
  - keep the top end warm, because the only warm thing in Act 1 is sodium;
  - take a little saturation out of the middle, so the one warm source reads.

Usage: python3 tools/gen/make_lut.py [--out assets/luts]
"""
from __future__ import annotations

import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from png import write_rgba  # noqa: E402

STEPS = 16
WIDTH = STEPS * STEPS
HEIGHT = STEPS

# docs/ART_BIBLE.md, "Palette": the cold fill and the sodium practical.
COLD_FILL = (0.106, 0.129, 0.157)
HIGHLIGHT_GAIN = (1.015, 0.99, 0.93)

# The pivot is low, and that is the whole trick. This game's image lives below
# a quarter brightness; contrast about the usual 0.5 pivot does not add
# contrast to it, it deletes it -- 0.10 comes out at 0.05 and the room goes
# black. Pivoting where the picture actually is puts the S-curve across the
# range that has detail in it.
CONTRAST_PIVOT = 0.22
CONTRAST = 1.10
SHADOW_TINT = 0.42
MID_DESATURATE = 0.14


def _luma(r: float, g: float, b: float) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _clamp(x: float) -> float:
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


def _smoothstep(edge0: float, edge1: float, x: float) -> float:
    if edge0 == edge1:
        return 0.0
    t = _clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


# The cold fill as a direction of unit luminance. Tinting toward the colour
# itself drags every shadow up to that colour's brightness, which lifts true
# black to a grey haze -- fog, which docs/ART_BIBLE.md forbids by name -- and
# flattens everything below it into one value. Tinting toward the direction
# moves the hue and leaves the luminance exactly where it was.
_COLD_LUMA = 0.2126 * COLD_FILL[0] + 0.7152 * COLD_FILL[1] + 0.0722 * COLD_FILL[2]
COLD_DIRECTION = tuple(c / _COLD_LUMA for c in COLD_FILL)


def grade(r: float, g: float, b: float) -> tuple[float, float, float]:
    # 1. Contrast about a low pivot. No black-point lift: black stays black.
    channels = [
        max(0.0, (c - CONTRAST_PIVOT) * CONTRAST + CONTRAST_PIVOT)
        for c in (r, g, b)
    ]

    # 2. Shadows toward the cold hue, at their own luminance.
    lum = _luma(*channels)
    shadow = _smoothstep(0.30, 0.0, lum) * SHADOW_TINT
    channels = [
        c + (direction * lum - c) * shadow
        for c, direction in zip(channels, COLD_DIRECTION)
    ]

    # 3. Keep the top end warm.
    lum = _luma(*channels)
    warm = _smoothstep(0.52, 1.0, lum)
    channels = [_clamp(c * (1.0 + (gain - 1.0) * warm)) for c, gain in zip(channels, HIGHLIGHT_GAIN)]

    # 4. Pull a little colour out of the middle so sodium is the only hue.
    lum = _luma(*channels)
    mid = 1.0 - abs(lum - 0.5) * 2.0
    pull = MID_DESATURATE * max(0.0, mid)
    channels = [c + (lum - c) * pull for c in channels]

    return tuple(_clamp(c) for c in channels)


def build() -> bytearray:
    pixels = bytearray(WIDTH * HEIGHT * 4)
    for slice_index in range(STEPS):
        blue = slice_index / (STEPS - 1)
        for y in range(HEIGHT):
            green = y / (HEIGHT - 1)
            for x in range(STEPS):
                red = x / (STEPS - 1)
                out = grade(red, green, blue)
                at = (y * WIDTH + slice_index * STEPS + x) * 4
                pixels[at + 0] = int(out[0] * 255.0 + 0.5)
                pixels[at + 1] = int(out[1] * 255.0 + 0.5)
                pixels[at + 2] = int(out[2] * 255.0 + 0.5)
                pixels[at + 3] = 255
    return pixels


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/luts")
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    path = out / "act1.png"
    write_rgba(path, WIDTH, HEIGHT, build())
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
