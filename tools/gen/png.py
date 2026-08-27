"""Minimal dependency-free PNG writer.

The project forbids third-party asset packs and requires every image to be
regenerable from committed source, so we cannot lean on Pillow being present in
CI. This writes 8-bit RGBA PNGs with the standard zlib/deflate filter-0
encoding, which is all the generators here need.
"""
from __future__ import annotations

import struct
import zlib

SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def write_rgba(path, width: int, height: int, pixels: bytearray) -> None:
    """`pixels` is a flat RGBA byte buffer, row-major, len == w*h*4."""
    expected = width * height * 4
    if len(pixels) != expected:
        raise ValueError(f"expected {expected} bytes, got {len(pixels)}")

    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0 (None) keeps the encoder trivial
        raw += pixels[y * stride : (y + 1) * stride]

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    # mtime-free and level-pinned so repeated runs are byte-identical.
    body = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as fh:
        fh.write(SIGNATURE)
        fh.write(_chunk(b"IHDR", ihdr))
        fh.write(_chunk(b"IDAT", body))
        fh.write(_chunk(b"IEND", b""))
