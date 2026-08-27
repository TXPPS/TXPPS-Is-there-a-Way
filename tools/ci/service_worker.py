#!/usr/bin/env python3
"""Rework Godot's generated service worker into one that can be updated.

Godot's worker is cache-first and, like every default service worker, installs a
new version and then waits for every tab to close before taking over. On an
installed iOS PWA "every tab closed" can be *never*, which strands the player on
a stale build with no recourse from a phone. Five changes fix that:

1. The cache name is keyed to a hash of the files it caches, so a rebuild is a
   different cache and the old one is deleted on activation.
2. The new worker takes over immediately (`skipWaiting` + `clients.claim`)
   rather than waiting, and the page notices and offers a reload.
3. Navigation is network-first with a cache fallback, so the *first* reload
   after a deploy already serves the new build. Engine assets stay cache-first,
   which is what makes the game playable offline.
4. Any request carrying `?fresh=1` -- in its own URL or its referrer -- bypasses
   the worker entirely, so the escape hatch in web/boot.js is reachable even when
   every cached file is broken.
5. Navigation preload is switched back off, because nothing reads it and an
   enabled preload is a second, discarded request for index.html per navigation.

Every edit to generated code is asserted: if Godot's output changes shape, the
build fails loudly here instead of silently shipping an unpatched worker.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import re


class Failure(Exception):
    pass


# The exact branch Godot generates for navigation requests: consult the cache
# first, and only touch the network when something is missing.
_NAVIGATE_CACHE_FIRST = """\t\t\t\tif (isNavigate) {
\t\t\t\t\t// Check if we have full cache during HTML page request.
\t\t\t\t\t/** @type {Response[]} */
\t\t\t\t\tconst fullCache = await Promise.all(FULL_CACHE.map((name) => cache.match(name)));
\t\t\t\t\tconst missing = fullCache.some((v) => v === undefined);
\t\t\t\t\tif (missing) {
\t\t\t\t\t\ttry {
\t\t\t\t\t\t\t// Try network if some cached file is missing (so we can display offline page in case).
\t\t\t\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);
\t\t\t\t\t\t\treturn response;
\t\t\t\t\t\t} catch (e) {
\t\t\t\t\t\t\t// And return the hopefully always cached offline page in case of network failure.
\t\t\t\t\t\t\tconsole.error('Network error: ', e); // eslint-disable-line no-console
\t\t\t\t\t\t\treturn caches.match(OFFLINE_URL);
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t}
"""

# Replacement: the document that decides which build is live is always fetched
# fresh when the network allows it, and falls back to the cache when it does not.
_NAVIGATE_NETWORK_FIRST = """\t\t\t\tif (isNavigate) {
\t\t\t\t\t// PATCHED (tools/ci/service_worker.py): network-first for the
\t\t\t\t\t// document. index.html names the content-hashed engine payload, so
\t\t\t\t\t// serving it from cache pins the player to whichever build they
\t\t\t\t\t// first loaded. Offline still works: we fall back to the cached
\t\t\t\t\t// document, and only then to the offline page.
\t\t\t\t\t//
\t\t\t\t\t// Deliberately not fetchAndCache(): that awaits
\t\t\t\t\t// event.preloadResponse, and a navigation preload that rejects
\t\t\t\t\t// sends us down the fallback below -- which serves the *previous*
\t\t\t\t\t// build's document, whose payload the deploy we are trying to
\t\t\t\t\t// pick up has already removed. A 404 on the engine wasm is the
\t\t\t\t\t// symptom, and it is not recoverable by reloading.
\t\t\t\t\ttry {
\t\t\t\t\t\tconst doc = await self.fetch(event.request);
\t\t\t\t\t\tif (!doc || !doc.ok) {
\t\t\t\t\t\t\tthrow new Error(`document status ${doc && doc.status}`);
\t\t\t\t\t\t}
\t\t\t\t\t\tcache.put(event.request, doc.clone());
\t\t\t\t\t\treturn doc;
\t\t\t\t\t} catch (e) {
\t\t\t\t\t\tconst offlineDoc = await cache.match(event.request) || await cache.match(CACHED_FILES[0]);
\t\t\t\t\t\treturn offlineDoc || caches.match(OFFLINE_URL);
\t\t\t\t\t}
\t\t\t\t}
"""

# The head of Godot's fetch listener. Everything the worker does hangs off this
# line, which makes it the one place to install an unconditional bypass.
_FETCH_HEAD = """\t(event) => {
\t\tconst isNavigate = event.request.mode === 'navigate';
"""

# ?fresh=1 is the recourse when the cache has gone wrong, so it cannot be served
# by the thing that went wrong. Returning without calling respondWith() hands the
# request back to the browser, which fetches it as though no worker existed.
#
# The referrer test is the half that matters: the document carries fresh=1, but
# the scripts it then loads do not, and a poisoned engine payload would break the
# page before the escape hatch in web/boot.js ever ran.
_FETCH_HEAD_PATCHED = """\t(event) => {
\t\t// PATCHED (tools/ci/service_worker.py): the ?fresh=1 escape hatch must
\t\t// reach the network even when every cached file is broken, so nothing
\t\t// loaded by such a page enters this handler at all. See web/boot.js.
\t\tif (FRESH.test(event.request.url) || FRESH.test(event.request.referrer || '')) {
\t\t\treturn;
\t\t}
\t\tconst isNavigate = event.request.mode === 'navigate';
"""

# Declared next to the other constants at the top of the generated worker.
_FRESH_CONST = "const FRESH = /[?&]fresh=1(&|$)/;\n"

_EPILOGUE = """
// --- appended by tools/ci/service_worker.py ---------------------------------
// Take over as soon as we are installed instead of waiting for every tab to
// close. An installed PWA on iOS may never close a tab, and a player who cannot
// reach a new build from their phone has no recourse at all. The page watches
// for this and offers "New version - tap to reload"; see web/boot.js.
self.addEventListener('install', () => {
\tself.skipWaiting();
});

self.addEventListener('activate', (event) => {
\tevent.waitUntil((async () => {
\t\tawait self.clients.claim();
\t\t// Godot's own activate handler switches navigation preload on. The
\t\t// navigate branch above deliberately does not read event.preloadResponse
\t\t// -- a preload that rejects would send it to the cache fallback and serve
\t\t// the previous build's document -- so leaving preload enabled just means a
\t\t// second, discarded request for index.html on every single navigation.
\t\t// Turn it off, after Godot has turned it on.
\t\tif (self.registration.navigationPreload) {
\t\t\tawait self.registration.navigationPreload.disable();
\t\t}
\t})());
});
"""


def _read_array(text: str, name: str) -> list:
    match = re.search(rf"const {name} = (\[.*?\]);", text, re.S)
    if not match:
        raise Failure(f"could not find {name} in the service worker")
    return json.loads(match.group(1))


def cache_version(build: pathlib.Path, names: list) -> str:
    """A digest of everything the worker caches, so a rebuild is a new cache."""
    digest = hashlib.sha256()
    for name in sorted(names):
        path = build / name
        if not path.exists():
            raise Failure(f"service worker caches {name}, which the build does not contain")
        digest.update(name.encode())
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()[:16]


def harden(worker: pathlib.Path, build: pathlib.Path) -> str:
    text = worker.read_text()

    cached = _read_array(text, "CACHED_FILES") + _read_array(text, "CACHEABLE_FILES")
    version = cache_version(build, cached)

    text, count = re.subn(
        r"const CACHE_VERSION = '[^']*';",
        f"const CACHE_VERSION = '{version}';",
        text,
        count=1,
    )
    if count != 1:
        raise Failure("could not key CACHE_VERSION to the build hash")

    if _FETCH_HEAD not in text:
        raise Failure(
            "the generated service worker's fetch listener is not the shape this "
            "script knows how to patch. Godot's template changed: re-read "
            "build/index.service.worker.js and update _FETCH_HEAD."
        )
    text = text.replace(_FETCH_HEAD, _FETCH_HEAD_PATCHED, 1)
    text = text.replace("const FULL_CACHE = ", _FRESH_CONST + "const FULL_CACHE = ", 1)

    if _NAVIGATE_CACHE_FIRST not in text:
        raise Failure(
            "the generated service worker's navigation branch is not the shape this "
            "script knows how to patch. Godot's template changed: re-read "
            "build/index.service.worker.js and update _NAVIGATE_CACHE_FIRST."
        )
    text = text.replace(_NAVIGATE_CACHE_FIRST, _NAVIGATE_NETWORK_FIRST, 1)

    text += _EPILOGUE
    worker.write_text(text)
    return version


def assert_hardened(worker: pathlib.Path, version: str) -> None:
    """Re-read from disk and prove every property actually holds."""
    text = worker.read_text()
    checks = {
        "cache name is keyed to the build": f"const CACHE_VERSION = '{version}';" in text,
        "new worker takes over immediately": "self.skipWaiting();" in text,
        "new worker claims open pages": "self.clients.claim()" in text,
        "navigation is network-first, and ignores navigation preload":
            "const doc = await self.fetch(event.request);" in text,
        "navigation preload is off, since nothing reads it":
            "navigationPreload.disable()" in text,
        "?fresh=1 bypasses the worker, document and sub-resources alike":
            "FRESH.test(event.request.url) || FRESH.test(event.request.referrer" in text
            and "const FRESH = " in text,
    }
    missing = [name for name, ok in checks.items() if not ok]
    if missing:
        raise Failure("service worker hardening did not take: " + "; ".join(missing))
