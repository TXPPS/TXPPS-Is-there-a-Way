"""Minimal dependency-free WAV writer, matching tools/gen/png.py in spirit.

The project keeps zero third-party Python dependencies so that CI can
regenerate every committed asset and diff it against what is in the tree. A
16-bit PCM RIFF file is forty-four bytes of header and then the samples, which
is not worth an import.

Mono only. Everything this game generates is either a point source in 3D --
where a stereo file is discarded anyway -- or a score layer that is placed by
the mix rather than baked with a width.
"""
from __future__ import annotations

import pathlib
import struct


def write_mono16(path: pathlib.Path, rate: int, samples: list[float]) -> None:
    """`samples` are floats in -1..1. Anything outside is clipped, loudly enough
    that a generator that overflows shows up as distortion rather than as wrap."""
    frames = len(samples)
    body = bytearray(frames * 2)
    for index, value in enumerate(samples):
        clipped = -1.0 if value < -1.0 else (1.0 if value > 1.0 else value)
        struct.pack_into("<h", body, index * 2, int(clipped * 32767.0))

    header = b"RIFF" + struct.pack("<I", 36 + len(body)) + b"WAVE"
    header += b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16)
    header += b"data" + struct.pack("<I", len(body))
    path.write_bytes(header + bytes(body))


def peak(samples: list[float]) -> float:
    return max((abs(s) for s in samples), default=0.0)


def normalise(samples: list[float], target: float) -> list[float]:
    """Scales to a peak. Deterministic, and applied last so every generator can
    be written in whatever units the physics wanted."""
    top = peak(samples)
    if top <= 1e-9:
        return samples
    gain = target / top
    return [s * gain for s in samples]
