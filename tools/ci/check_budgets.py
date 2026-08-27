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


def gz_size(path: pathlib.Path) -> int:
    return len(gzip.compress(path.read_bytes(), 9))


def human(n: int) -> str:
    return f"{n / 1048576:.2f} MB"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    args = ap.parse_args()

    build = pathlib.Path(args.build)
    files = sorted(p for p in build.rglob("*") if p.is_file())
    if not files:
        print(f"error: no files in {build}", file=sys.stderr)
        return 1

    rows = [(p.relative_to(build).as_posix(), p.stat().st_size, gz_size(p)) for p in files]
    rows.sort(key=lambda r: -r[2])

    total_gz = sum(r[2] for r in rows)
    audio_gz = sum(r[2] for r in rows if r[0].endswith(AUDIO_SUFFIXES))

    width = max(len(r[0]) for r in rows)
    print(f"{'file'.ljust(width)}  {'raw':>12}  {'gzip':>12}")
    for name, raw, gz in rows:
        print(f"{name.ljust(width)}  {raw:>12,}  {gz:>12,}")
    print()
    print(f"total gzipped : {human(total_gz)}  (budget {human(TOTAL_GZ_LIMIT)})")
    print(f"audio gzipped : {human(audio_gz)}  (budget {human(AUDIO_GZ_LIMIT)})")

    failed = False
    if total_gz > TOTAL_GZ_LIMIT:
        print(f"error: total download {human(total_gz)} exceeds {human(TOTAL_GZ_LIMIT)}", file=sys.stderr)
        failed = True
    if audio_gz > AUDIO_GZ_LIMIT:
        print(f"error: audio {human(audio_gz)} exceeds {human(AUDIO_GZ_LIMIT)}", file=sys.stderr)
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
