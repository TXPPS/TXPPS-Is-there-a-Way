# Testing

Everything here runs headless, in CI, on every push. There is no manual step
between a commit and knowing whether it works — except the phone, and the last
section is about what only the phone can tell us.

```sh
npm --prefix tools/web ci
npm --prefix tools/web run smoke       # gameplay + instrumentation
npm --prefix tools/web run smoke:pwa   # install, update, recovery
```

Both suites want a build in `build/`. `bash tools/ci/build_web.sh` makes one.

---

## The shared harness

`tools/web/harness.js` is the contract both suites are written against. It is
deliberately small: a server, a browser, and a tally. Everything else belongs to
the suite that needs it.

### `serve(state, port) -> Promise<http.Server>`

A static file server rooted at **`state.dir`, re-read on every request**. That
mutability is the point: reassigning `state.dir` mid-test is how a deploy
"lands" under a running client without restarting anything.

It answers with the same `Content-Type` and `Cache-Control` that `web/_headers`
tells Cloudflare to send — content-hashed payload `immutable` for a year, PNGs
for a day, everything else `no-cache, must-revalidate`. A suite that passes
here has passed against the caching contract we actually ship, which is most of
what makes the update path testable at all. If `web/_headers` changes,
`cacheControl()` changes with it or the suites start lying.

Query strings are stripped before the path lookup, so `?fresh=1` and the update
probe's cache-buster both resolve to the file they name.

### `openBrowser() -> Promise<{browser, context}>`

Chromium at iPhone 16 Pro Max landscape metrics: 956×440 CSS pixels, DPR 3,
`isMobile`, `hasTouch`, and an iOS 18 Safari user-agent string. `CHROMIUM_PATH`
overrides the binary, which is how this runs against the browser already on the
image instead of downloading another.

Launch flags and why each one is there:

| Flag | Reason |
|---|---|
| `--use-gl=swiftshader`, `--enable-unsafe-swiftshader` | CI runners have no GPU. |
| `--autoplay-policy=no-user-gesture-required` | Headless Chromium has no audio device and suspends the `AudioContext` even behind a trusted tap. |

### `tally(label) -> {check, report}`

`check(condition, message)` prints and records; `report()` prints the failures
and returns the process exit code. Suites `process.exit(t.report())`.

### What the harness deliberately does not do

No shared page object, no shared navigation helpers, no fixtures. The two suites
disagree about almost everything else — one wants a game running, the other
wants a service worker in a particular state — and a shared abstraction over
that would be a place for bugs to hide rather than a saving.

---

## `smoke_web.js` — does the game run

Serves the build, walks the tap gate, drives real touch events through CDP
(`Input.dispatchTouchEvent`; synthetic mouse drags never reach the game because
Chromium's mobile emulation swallows them), and screenshots each stage into
`build-smoke/`. CI keeps those screenshots as an artifact for 14 days.

It asserts the export variant (single-threaded, Compatibility, no
`SharedArrayBuffer`, no cross-origin isolation), that the canvas renders at CSS
resolution rather than 3×, that dragging each half of the screen does what it
should, and then opens the debug overlay and reads its numbers.

### Reading the overlay from the test

While the overlay is open, `src/ui/debug_overlay.gd` publishes its sample to
`window.__itaw_probe` as JSON. That is how CI asserts on frame budget and audio
at all — neither is legible from a screenshot. The three-finger tap that opens
it is dispatched as three simultaneous touch points, which also proves the
gesture works.

### Two numbers that need explaining

**Frame time.** The overlay reports `TIME_PROCESS + TIME_PHYSICS_PROCESS`. Under
swiftshader the main thread blocks on a software rasteriser and that wait lands
inside `TIME_PROCESS`, so the CI number is between 5 ms and 45 ms depending on
what else the runner is doing and means nothing about the phone. CI asserts a
250 ms ceiling — a tripwire for something spinning, not a performance claim. The
60 fps budget is a device measurement; see `docs/BUDGETS.md`.

Draw calls and visible primitives are renderer-independent and *are* asserted
against the real budgets (≤120, ≤150k).

**Audio.** `AudioServer.get_bus_peak_volume_left_db()` is the obvious way to
prove the mixer is producing signal, and it works on desktop — the same scene
reads −27 dB under the headless Dummy driver. On the **web** build it never
leaves its −200 dB floor whatever is playing. So the suite asserts on the
playback head instead: `src/world/lamp_hum.gd` joins the `audio_probe` group,
the overlay reports `is_playing()` and `get_playback_position()`, and the test
samples twice a second apart and requires the position to have advanced. That
proves the `AudioContext` is running and Godot's mixer is consuming the stream.
Whether any of it is *audible* is a device question.

---

## `smoke_pwa.js` — can I get out of a bad build

The suite that exists because a cache-first PWA that goes wrong is unfixable
from a phone. Four phases, each building on the last:

| | What it proves |
|---|---|
| **A install** | The worker registers, claims the open page, names its cache after the build hash, caches the payload once requests have been through it, and serves the game with the network switched off. Also: the build stamp reads version + short SHA, tapping it copies a full report, engine errors and unhandled JS exceptions become on-screen toasts, a repeating error is one toast with a count rather than a storm, and toasts dismiss. |
| **B update** | With the game *running*, the document root is swapped to a forged rebuild. The new build is detected; the banner is **withheld** because the player is mid-scene; returning from the home screen releases it; taking it swaps the live build and the old cache is gone. |
| **C gate** | The same withheld banner is also released by opening a menu (`window.__itaw_setUpdateGate(true)`). Rolling the deploy back restores the previous build and deletes the forged cache in turn. |
| **D recovery** | A poisoned entry is written straight into the worker's cache in place of the engine payload, and the whole recovery ladder is climbed: the page heals itself once (purge, clean reload, gate), records that it had to, and reports a completed purge rather than one that hit its deadline. Poisoned a second time in the same tab it does **not** purge again — it says so and offers "Reload cleanly", which then works. |

### The forged rebuild

`forgeRebuild()` copies the build, renaming `index.<hash>.*` to
`index.deadbeef01.*`, rewriting every reference in `.html`/`.js`/`.json`,
changing the commit in `window.ITAW_BUILD`, setting a distinct `CACHE_VERSION`,
and injecting a `<meta name="itaw-forged">` marker so the test can tell which
build is on screen. Both of the shell's update signals — payload name and commit
— therefore move, as they would on a real deploy.

### Why the recovery is one-shot per tab

A page that purges and reloads on every failure is a page that can loop forever
on a deploy that is simply broken. So the automatic purge fires once per tab
(`sessionStorage`, which resets with the tab) and after that the fault is shown
with a button. Phase D asserts both halves, because the second half is the one
that stops a bad build becoming an infinite one.

### Why phase D clears the HTTP cache

Chromium keeps `immutable` subresources in its own HTTP cache across a reload
and hands them straight to the page, never dispatching a `fetch` event — which
would quietly hide the poison and make D1 pass for the wrong reason. The suite
calls CDP `Network.clearBrowserCache` first, which empties the HTTP cache and
leaves Cache Storage alone. That is also the state a phone is in after Safari
evicts or the browser restarts, which is exactly when a bad cached build strands
you.

### The browser matters here

CI runs Playwright's own `chrome-headless-shell`; a dev box with
`CHROMIUM_PATH` set runs whatever full Chromium is on it. They do not agree
about service workers. The bug that made this suite go red on CI and stay green
locally was exactly that: Godot's `fetchAndCache` awaits
`event.preloadResponse`, and where the navigation preload rejects, the
network-first branch throws and the **cached** document is served — the previous
build's `index.html`, naming a payload the new deploy has already removed. Four
404s and a dead page. The navigate branch now fetches for itself and ignores
preload entirely.

If this suite ever disagrees between CI and a dev box again, that is the first
thing to suspect, and `smoke_pwa.js`'s crash dump (console, page errors, failed
requests, and what the page thinks its executable is) is what tells you.

### Ports

`smoke_web.js` uses 8099, `smoke_pwa.js` 8098, and both bind `127.0.0.1`. They
must not share a port: a service worker's scope is the origin, and one suite's
worker would answer the other suite's requests.

---

## What only the phone can tell us

Everything below is on the checklist in `docs/PROGRESS.md` because no headless
browser can answer it:

- Whether 60 fps actually holds, and what the GPU frame time is.
- Whether the hum is **audible** — CI proves the mixer runs, not that sound
  leaves the speaker, and iOS silent-switch behaviour differs from desktop.
- Whether the safe-area insets are right (the emulator reports `0,0,0,0`; a real
  iPhone in landscape reports a notch inset on one side and a home-indicator
  inset on the bottom).
- Whether an installed home-screen PWA behaves like the browser tab.
- Whether the touch targets are reachable with the thumbs that are actually
  holding the phone.
