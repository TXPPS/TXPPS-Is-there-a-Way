#!/usr/bin/env python3
"""Enforce the download budgets from docs/BUDGETS.md against a real export.

Budgets that are only written down are budgets that get blown. This runs in CI
after every export and fails the build rather than letting a 60 MB download
reach a phone on LTE.
"""
from __future__ import annotations

import argparse
import gzip
import pathlib
import sys

TOTAL_GZ_LIMIT = 40 * 1024 * 1024        # hard constraint: <= 40 MB gzipped
AUDIO_GZ_LIMIT = 12 * 1024 * 1024        # hard constraint: audio <= 12 MB gzipped
AUDIO_SUFFIXES = (".wav", ".ogg", ".mp3")
TEXTURE_MAX_PX = 1024                    # hard constraint: no texture over 1024px
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def gz_size(path: pathlib.Path) -> int:
    return len(gzip.compress(path.read_bytes(), 9))


def png_size(path: pathlib.Path) -> tuple[int, int]:
    """Width and height straight out of the IHDR. Reading eight bytes beats
    taking a dependency on an image library CI would have to install."""
    with path.open("rb") as fh:
        if fh.read(8) != PNG_SIGNATURE:
            raise ValueError(f"{path} is not a PNG")
        fh.read(4)
        if fh.read(4) != b"IHDR":
            raise ValueError(f"{path} has no IHDR where one must be")
        return int.from_bytes(fh.read(4), "big"), int.from_bytes(fh.read(4), "big")


def check_textures(root: pathlib.Path) -> list[str]:
    """Every committed PNG, against the texture ceiling. Run against the source
    tree rather than the export, because by export time a texture is inside a
    pack and its dimensions are no longer a file anyone can read."""
    problems = []
    for path in sorted(root.rglob("*.png")):
        width, height = png_size(path)
        if max(width, height) > TEXTURE_MAX_PX:
            problems.append(
                f"{path}: {width}x{height} exceeds the {TEXTURE_MAX_PX}px ceiling"
            )
    return problems


def human(n: int) -> str:
    return f"{n / 1048576:.2f} MB"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    ap.add_argument("--assets", default="assets")
    ap.add_argument("--imported", default=".godot/imported")
    args = ap.parse_args()

    build = pathlib.Path(args.build)
    files = sorted(p for p in build.rglob("*") if p.is_file())
    if not files:
        print(f"error: no files in {build}", file=sys.stderr)
        return 1

    rows = [(p.relative_to(build).as_posix(), p.stat().st_size, gz_size(p)) for p in files]
    rows.sort(key=lambda r: -r[2])

    total_gz = sum(r[2] for r in rows)
    # By export time every sound is inside the pack and there is no file left
    # whose size is the audio budget -- so this measures the *imported* samples,
    # which are byte for byte what the pack carries. The committed WAVs are five
    # times larger and measuring those would refuse a legitimate addition on the
    # strength of a number that never ships.
    imported = pathlib.Path(args.imported)
    audio_files = sorted(imported.glob("*.sample")) if imported.is_dir() else []
    audio_gz = sum(gz_size(p) for p in audio_files)
    source_gz = sum(
        gz_size(p) for p in sorted(pathlib.Path(args.assets).rglob("*"))
        if p.is_file() and p.suffix in AUDIO_SUFFIXES
    )

    width = max(len(r[0]) for r in rows)
    print(f"{'file'.ljust(width)}  {'raw':>12}  {'gzip':>12}")
    for name, raw, gz in rows:
        print(f"{name.ljust(width)}  {raw:>12,}  {gz:>12,}")
    print()
    print(f"total gzipped : {human(total_gz)}  (budget {human(TOTAL_GZ_LIMIT)})")
    print(f"audio shipped : {human(audio_gz)}  (budget {human(AUDIO_GZ_LIMIT)}) "
          f"from {human(source_gz)} of committed WAV")

    texture_problems = check_textures(pathlib.Path(args.assets))
    if texture_problems:
        print()
        for problem in texture_problems:
            print(f"error: {problem}", file=sys.stderr)
    else:
        print(f"textures      : all within {TEXTURE_MAX_PX}px")

    failed = bool(texture_problems)
    if total_gz > TOTAL_GZ_LIMIT:
        print(f"error: total download {human(total_gz)} exceeds {human(TOTAL_GZ_LIMIT)}", file=sys.stderr)
        failed = True
    if audio_gz > AUDIO_GZ_LIMIT:
        print(f"error: shipped audio {human(audio_gz)} exceeds {human(AUDIO_GZ_LIMIT)}", file=sys.stderr)
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
