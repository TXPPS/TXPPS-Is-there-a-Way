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

# The pivot is low, and that is the whole trick. This game's image lives below
# a quarter brightness; contrast about the usual 0.5 pivot does not add
# contrast to it, it deletes it -- 0.10 comes out at 0.05 and the room goes
# black. Pivoting where the picture actually is puts the S-curve across the
# range that has detail in it. Every grade here keeps that pivot; what changes
# between acts is the hue at the two ends.
CONTRAST_PIVOT = 0.22


class Grade:
    """One act's colour, as the four numbers the grade actually turns on."""

    def __init__(self, name, cold_fill, highlight_gain, contrast,
                 shadow_tint, mid_desaturate, note):
        self.name = name
        self.cold_fill = cold_fill
        self.highlight_gain = highlight_gain
        self.contrast = contrast
        self.shadow_tint = shadow_tint
        self.mid_desaturate = mid_desaturate
        self.note = note

    @property
    def cold_direction(self):
        """The fill hue at unit luminance.

        Tinting toward the fill *colour* rather than its direction lifts true
        black to a grey haze, which is how the first version of this made the
        whole room look fogged. Normalising by luminance tints the hue and
        leaves the level alone.
        """
        luma = _luma(*self.cold_fill)
        return tuple(c / luma for c in self.cold_fill)


GRADES = [
    Grade(
        name="act1",
        # docs/ART_BIBLE.md, "Palette": the cold fill and the sodium practical.
        cold_fill=(0.106, 0.129, 0.157),
        highlight_gain=(1.015, 0.99, 0.93),
        contrast=1.10,
        shadow_tint=0.42,
        mid_desaturate=0.14,
        note="the dam: sodium practicals, cold blue-grey fill, warm top end",
    ),
    Grade(
        name="annex",
        # The palette shift that marks leaving the *dam* and entering the
        # *programme*. Everything a person notices is at the top end: the
        # practical stops being a warm sodium fitting and becomes a tired
        # fluorescent tube, which is green-white and slightly short of red.
        cold_fill=(0.098, 0.122, 0.126),
        highlight_gain=(0.955, 1.025, 0.975),
        # Fluorescent light is flatter than a point source: broad fittings,
        # less falloff, fewer places for the eye to find an edge.
        contrast=1.06,
        shadow_tint=0.34,
        # Less desaturation than Act 1, deliberately. The dam pulls colour out
        # of the midtones so sodium is the only hue in the frame; the annex
        # wants its sickness *in* the midtones, so the green reaches the walls
        # rather than staying in the fittings.
        mid_desaturate=0.05,
        note="the programme: fluorescent green-white, flatter, colour in the mids",
    ),
]


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
def grade(r: float, g: float, b: float, look: "Grade") -> tuple[float, float, float]:
    # 1. Contrast about a low pivot. No black-point lift: black stays black.
    channels = [
        max(0.0, (c - CONTRAST_PIVOT) * look.contrast + CONTRAST_PIVOT)
        for c in (r, g, b)
    ]

    # 2. Shadows toward the fill hue, at their own luminance.
    lum = _luma(*channels)
    shadow = _smoothstep(0.30, 0.0, lum) * look.shadow_tint
    channels = [
        c + (direction * lum - c) * shadow
        for c, direction in zip(channels, look.cold_direction)
    ]

    # 3. Push the top end toward whatever this act's practical is.
    lum = _luma(*channels)
    top = _smoothstep(0.52, 1.0, lum)
    channels = [
        _clamp(c * (1.0 + (gain - 1.0) * top))
        for c, gain in zip(channels, look.highlight_gain)
    ]

    # 4. Pull colour out of the middle, so the practical is the frame's hue.
    lum = _luma(*channels)
    mid = 1.0 - abs(lum - 0.5) * 2.0
    pull = look.mid_desaturate * max(0.0, mid)
    channels = [c + (lum - c) * pull for c in channels]

    return tuple(_clamp(c) for c in channels)


def build(look: "Grade") -> bytearray:
    pixels = bytearray(WIDTH * HEIGHT * 4)
    for slice_index in range(STEPS):
        blue = slice_index / (STEPS - 1)
        for y in range(HEIGHT):
            green = y / (HEIGHT - 1)
            for x in range(STEPS):
                red = x / (STEPS - 1)
                out = grade(red, green, blue, look)
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
    for look in GRADES:
        path = out / f"{look.name}.png"
        write_rgba(path, WIDTH, HEIGHT, build(look))
        print(f"wrote {path} ({path.stat().st_size:,} bytes) -- {look.note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
