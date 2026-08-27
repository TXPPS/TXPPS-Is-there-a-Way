#!/usr/bin/env python3
"""Make a Godot web export safely cacheable, then prove it is the build we want.

Godot names its payload index.js / index.wasm / index.pck on every build, which
makes long-lived HTTP caching unsafe: a returning player would get last week's
engine with this week's data. This renames the payload to include a content
hash and rewrites every reference (HTML config, service-worker cache list), so
the engine files can be served `immutable` for a year while index.html stays
no-cache.

It also asserts the export really is the single-threaded, non-isolated variant
the iOS Safari target requires. A wrong export preset otherwise fails silently
and only shows up as a blank screen on the phone.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import shutil
import sys

# Suffixes Godot derives from the `executable` base name, plus the data pack.
PAYLOAD_SUFFIXES = (
    ".js",
    ".wasm",
    ".pck",
    ".audio.worklet.js",
    ".audio.position.worklet.js",
)
# Emitted by the exporter but referenced by nothing once a custom shell replaces
# the default splash markup.
UNUSED = ("index.png",)


class Failure(Exception):
    pass


def content_hash(build: pathlib.Path, base: str) -> str:
    digest = hashlib.sha256()
    for suffix in PAYLOAD_SUFFIXES:
        path = build / f"{base}{suffix}"
        if path.exists():
            digest.update(path.read_bytes())
    return digest.hexdigest()[:10]


def assert_target_variant(html: str) -> None:
    """Fail loudly if this is not the export the iOS target needs."""
    if not re.search(r"GODOT_THREADS_ENABLED\s*=\s*false", html):
        raise Failure(
            "export is threaded: set variant/thread_support=false in export_presets.cfg. "
            "Threads need SharedArrayBuffer, which needs COOP/COEP, which we do not have."
        )
    if '"ensureCrossOriginIsolationHeaders":true' in html:
        raise Failure(
            "export requests cross-origin isolation headers: set "
            "progressive_web_app/ensure_cross_origin_isolation_headers=false."
        )


def rename_payload(build: pathlib.Path, base: str, digest: str) -> dict:
    mapping = {}
    for suffix in PAYLOAD_SUFFIXES:
        old = build / f"{base}{suffix}"
        if not old.exists():
            continue
        new_name = f"{base}.{digest}{suffix}"
        old.rename(build / new_name)
        mapping[old.name] = new_name
    return mapping


def rewrite(path: pathlib.Path, mapping: dict, base: str, digest: str) -> None:
    text = path.read_text()
    # Longest names first so "index.js" cannot clobber "index.audio.worklet.js".
    for old in sorted(mapping, key=len, reverse=True):
        text = text.replace(old, mapping[old])
    text = text.replace(f'"executable":"{base}"', f'"executable":"{base}.{digest}"')
    path.write_text(text)


def extend_sw_cache(path: pathlib.Path, extra: list) -> None:
    """Add files the exporter leaves out, so an installed PWA is complete."""
    text = path.read_text()
    match = re.search(r"const CACHED_FILES = (\[.*?\]);", text, re.S)
    if not match:
        raise Failure("could not find CACHED_FILES in the service worker")
    cached = json.loads(match.group(1))
    for name in extra:
        if name not in cached:
            cached.append(name)
    text = text[: match.start(1)] + json.dumps(cached) + text[match.end(1) :]
    path.write_text(text)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    ap.add_argument("--base", default="index")
    ap.add_argument("--headers", default="web/_headers")
    args = ap.parse_args()

    build = pathlib.Path(args.build)
    base = args.base
    html = build / f"{base}.html"
    if not html.exists():
        raise Failure(f"{html} not found -- did the export run?")

    assert_target_variant(html.read_text())

    for name in UNUSED:
        target = build / name
        if target.exists():
            target.unlink()

    digest = content_hash(build, base)
    mapping = rename_payload(build, base, digest)
    if not mapping:
        raise Failure("no engine payload found to hash")

    worker = build / f"{base}.service.worker.js"
    for path in (html, worker, build / f"{base}.manifest.json"):
        if path.exists():
            rewrite(path, mapping, base, digest)

    if worker.exists():
        candidates = [
            f"{base}.manifest.json",
            f"{base}.144x144.png",
            f"{base}.180x180.png",
            f"{base}.512x512.png",
        ]
        extend_sw_cache(worker, [n for n in candidates if (build / n).exists()])

    headers = pathlib.Path(args.headers)
    if headers.exists():
        shutil.copy2(headers, build / "_headers")

    print(f"[web] payload hash {digest}")
    for old, new in sorted(mapping.items()):
        print(f"      {old} -> {new}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Failure as err:
        print(f"error: {err}", file=sys.stderr)
        raise SystemExit(1)
