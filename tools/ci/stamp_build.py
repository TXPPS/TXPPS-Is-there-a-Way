#!/usr/bin/env python3
"""Write build_stamp.json so the running game can name its own commit.

Knowing exactly which build is on the phone is the difference between "the fix
didn't work" and "the fix didn't ship". Read back by src/core/build_info.gd.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import subprocess


def _git(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="build_stamp.json")
    ap.add_argument("--built-at", default="", help="ISO-8601 timestamp; defaults to the commit date")
    args = ap.parse_args()

    version = "0.0.0"
    project = pathlib.Path("project.godot")
    if project.exists():
        for line in project.read_text().splitlines():
            if line.startswith("config/version="):
                version = line.split("=", 1)[1].strip().strip('"')
                break

    stamp = {
        "version": version,
        "commit": _git("rev-parse", "HEAD"),
        "branch": _git("rev-parse", "--abbrev-ref", "HEAD"),
        "built_at": args.built_at or _git("show", "-s", "--format=%cI", "HEAD"),
    }
    pathlib.Path(args.out).write_text(json.dumps(stamp, indent=1, sort_keys=True) + "\n")
    print(f"[stamp] {stamp['version']} {stamp['commit'][:7]} ({stamp['branch']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
