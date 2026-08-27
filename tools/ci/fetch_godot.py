#!/usr/bin/env python3
"""Fetch the pinned Godot editor and *only* the Web export templates.

The official export-template archive (.tpz) is ~1.2 GB because it carries every
platform. CI only needs the Web templates (~40 MB), so this script reads the
archive's zip central directory over HTTP range requests and downloads just the
members it needs. No third-party actions, no vendored binaries, fully pinned.

Usage:  python3 tools/ci/fetch_godot.py --version 4.6.3-stable --dest .godot-sdk
"""
from __future__ import annotations

import argparse
import io
import os
import pathlib
import shutil
import struct
import sys
import urllib.request
import zipfile
import zlib

MIRROR = "https://github.com/godotengine/godot-builds/releases/download"
# Members we need out of the template archive. Godot names Web templates
# web_<dlink_>?<nothreads_>?<debug|release>.zip; we grab every web_* variant so
# both single- and multi-threaded presets can export.
WANTED_PREFIX = "templates/web_"
CHUNK = 1 << 20


def _open(url: str, headers: dict[str, str] | None = None):
    req = urllib.request.Request(url, headers=headers or {})
    return urllib.request.urlopen(req, timeout=120)


def http_size(url: str) -> int:
    with _open(url, {"Range": "bytes=0-0"}) as resp:
        content_range = resp.headers.get("Content-Range", "")
    if "/" not in content_range:
        raise RuntimeError(f"server does not support range requests: {url}")
    return int(content_range.rsplit("/", 1)[1])


def http_range(url: str, start: int, end: int) -> bytes:
    with _open(url, {"Range": f"bytes={start}-{end}"}) as resp:
        return resp.read()


def download(url: str, dest: pathlib.Path) -> pathlib.Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with _open(url) as resp, dest.open("wb") as out:
        shutil.copyfileobj(resp, out, CHUNK)
    return dest


def find_eocd(url: str, size: int) -> tuple[int, int]:
    """Return (central_directory_offset, central_directory_size)."""
    tail_len = min(size, 1 << 16)
    tail = http_range(url, size - tail_len, size - 1)
    idx = tail.rfind(b"PK\x05\x06")
    if idx < 0:
        raise RuntimeError("end-of-central-directory record not found")
    cd_size, cd_offset = struct.unpack("<II", tail[idx + 12 : idx + 20])
    if cd_offset == 0xFFFFFFFF:  # zip64
        z64_idx = tail.rfind(b"PK\x06\x06")
        if z64_idx < 0:
            raise RuntimeError("zip64 end-of-central-directory record not found")
        cd_size, cd_offset = struct.unpack("<QQ", tail[z64_idx + 40 : z64_idx + 56])
    return cd_offset, cd_size


def extract_web_templates(url: str, dest_dir: pathlib.Path) -> list[str]:
    size = http_size(url)
    cd_offset, cd_size = find_eocd(url, size)
    central = http_range(url, cd_offset, cd_offset + cd_size - 1)

    # Rebuild a minimal in-memory zip: central directory + a synthetic EOCD, so
    # zipfile can parse the entry table without the (huge) payload.
    stub = io.BytesIO()
    stub.write(b"\0" * cd_offset)
    stub.write(central)
    stub.write(
        struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 0, 0, cd_size, cd_offset, 0)
    )
    stub.seek(0)
    with zipfile.ZipFile(stub) as index:
        infos = [i for i in index.infolist() if i.filename.startswith(WANTED_PREFIX)]
    if not infos:
        raise RuntimeError(f"no members matching {WANTED_PREFIX!r} in {url}")

    dest_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    for info in infos:
        # Local header is variable length; read a header-sized window first.
        head = http_range(url, info.header_offset, info.header_offset + 29)
        name_len, extra_len = struct.unpack("<HH", head[26:30])
        data_start = info.header_offset + 30 + name_len + extra_len
        data_end = data_start + info.compress_size - 1
        payload = http_range(url, data_start, data_end)

        if info.compress_type == zipfile.ZIP_STORED:
            blob = payload
        elif info.compress_type == zipfile.ZIP_DEFLATED:
            blob = zlib.decompressobj(-zlib.MAX_WBITS).decompress(payload)
        else:
            raise RuntimeError(f"unsupported compression in {info.filename}")
        if zlib.crc32(blob) & 0xFFFFFFFF != info.CRC:
            raise RuntimeError(f"checksum mismatch for {info.filename}")

        name = pathlib.PurePosixPath(info.filename).name
        (dest_dir / name).write_bytes(blob)
        written.append(name)
    return written


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="e.g. 4.6.3-stable")
    ap.add_argument("--dest", default=".godot-sdk", help="where to unpack the editor")
    ap.add_argument("--templates-only", action="store_true")
    ap.add_argument("--editor-only", action="store_true")
    args = ap.parse_args()

    version = args.version
    numeric, _, flavour = version.partition("-")
    flavour = flavour or "stable"
    dest = pathlib.Path(args.dest).resolve()
    dest.mkdir(parents=True, exist_ok=True)

    if not args.templates_only:
        editor_zip = dest / "editor.zip"
        url = f"{MIRROR}/{version}/Godot_v{version}_linux.x86_64.zip"
        print(f"[fetch] editor  {url}", flush=True)
        download(url, editor_zip)
        with zipfile.ZipFile(editor_zip) as z:
            z.extractall(dest)
        editor_zip.unlink()
        binaries = sorted(dest.glob("Godot_v*_linux.x86_64"))
        if not binaries:
            raise RuntimeError("editor binary missing after extraction")
        target = dest / "godot"
        if target.exists() or target.is_symlink():
            target.unlink()
        binaries[0].rename(target)
        target.chmod(0o755)
        print(f"[fetch] editor -> {target}", flush=True)

    if not args.editor_only:
        # Godot looks templates up under <data>/export_templates/<numeric>.<flavour>/
        tpl_dir = (
            pathlib.Path(
                os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")
            )
            / "godot/export_templates"
            / f"{numeric}.{flavour}"
        )
        url = f"{MIRROR}/{version}/Godot_v{version}_export_templates.tpz"
        print(f"[fetch] web templates from {url}", flush=True)
        names = extract_web_templates(url, tpl_dir)
        # version.txt marks the pack as complete for the template manager.
        (tpl_dir / "version.txt").write_text(f"{numeric}.{flavour}\n")
        print(f"[fetch] templates -> {tpl_dir}", flush=True)
        for n in sorted(names):
            print(f"         {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
