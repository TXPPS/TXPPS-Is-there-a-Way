# Testing

Everything here runs headless, in CI, on every push. There is no manual step
between a commit and knowing whether it works — except the phone, and the last
section is about what only the phone can tell us.

```sh
godot --headless --script res://tests/run_tests.gd   # controls, pause, layout, settings
npm --prefix tools/web ci
npm --prefix tools/web run smoke       # gameplay + instrumentation
npm --prefix tools/web run smoke:pwa   # install, update, recovery
```

The browser suites want a build in `build/`. `bash tools/ci/build_web.sh` makes
one, and runs the headless suite on the way past — a control scheme that fails
its own assertions never reaches an export.

---

## `tests/` — the control scheme, headless

The browser is the wrong place to assert arithmetic. Chromium's touch emulation
is another layer to be wrong about, screenshots cannot tell you *why* a stick
moved, and a wall-clock frame in a software rasteriser is not a frame. So
everything that is a number lives here, in the real `main.tscn`, driven by real
`InputEventScreenTouch` / `InputEventScreenDrag` pushed straight at the viewport.

```
tests/run_tests.gd     SceneTree entry point; sizes the window, runs the cases
tests/expect.gd        assertion tally
tests/touch.gd         synthetic touches, including deliberately wrong ones
tests/case_input.gd    the control scheme
tests/case_interact.gd targeting, engaging, gestures reaching the focused thing
tests/case_pause.gd    pause halts, releases, ducks, and resumes without a jump
tests/case_layout.gd   the reserved rect contract
tests/case_settings.gd persistence, clamping, and change announcements
tests/case_save.gd     round-trip, codes, migration, and failing to save
tests/case_render.gd   post-stack wiring, reduce motion, and the fear number
tests/case_audio.gd    buses, the score's layers, occlusion, reverb, footsteps
tests/case_reading.gd  picking a page up, scrolling it, and remembering it
tests/case_devices.gd  Act 2's parts on their own, and the load arithmetic
tests/case_act1.gd     the whole act, from the first breaker to the door
tests/case_act2.gd     the shelter, including the answer that looks right
tests/case_act3.gd     the annex, and the price of getting through it
tests/case_act4.gd     the gate, and both ways out of it
tests/case_tools.gd    carrying something, and what the meter reads
tests/case_observer.gd the entity's rule, row by row from the bible
tests/case_playthrough.gd the whole game, once, by the doors
tests/case_reach.gd    can a player actually stand somewhere and touch each thing
```

### What `case_reach` is for

`case_act1` proves the act can be *completed* — but it completes it by putting
the player at a known-good spot in front of each device, which is exactly the
information a level author is most likely to get wrong. `case_reach` asks the
opposite question: given only the prop's own transform, where would a person
have to stand, and can they see it from there?

It steps back `1.15 m` along the prop's facing, drops to whatever floor is
underneath, aims from `1.62 m` eye height, and calls the real `Interactor`. It
reports why it failed rather than merely that it did — no floor, wrong thing
found, sight line blocked, or nothing there at all — because "unreachable" on
its own tells you nothing about which of four unrelated bugs you have.

It was written after the act was already green and immediately found three:
every east- and west-facing prop was mounted facing *into* its wall, the
interactor could target through concrete, and the demo lock was behind a
cabinet. None of them are visible in a screenshot: the props were flat panels
on a wall, and a wall-mounted panel looks identical from the front whichever
way its normal points. It is the cheapest test in the suite by far and it has
the best record.

Two things about the harness are worth knowing before adding a case.

**The window has to be sized.** Headless opens a placeholder window, and the
project's `canvas_items` stretch then scales it up to the design width — making
every layout assertion a statement about a screen nobody has. `run_tests.gd`
sets `root.size` to iPhone 16 Pro Max landscape in CSS points **after** the
first frame, because the window is still settling into its own size before one.
The viewport then reads 1286×592, and the point-to-unit scale is a real 1.35.

**Only the part of the log before the summary counts.** `build_web.sh` reads the
suite's output down to the `headless: ...` line and no further. Below it is
teardown, and teardown races the audio server: it holds a playback for a moment
after a player stops, so freeing the tree by hand makes "resources still in use
at exit" intermittent and *not* freeing it makes it certain. There is no third
option from GDScript. It says nothing about the run.

**Touches are pushed as local coordinates.** `root.push_input(event, true)`.
Without the `true`, Godot converts the position from window space to viewport
space and the touch lands at a fraction of where the test aimed it.

`tests/touch.gd` can set `relative` on a drag, and `case_input.gd` sets it to
±9999 on purpose. Godot 4.6's web build computes that field against the wrong
finger whenever more than one is down (see ARCHITECTURE.md, "Touch ownership");
the assertion is that a lie in it changes nothing.

### Two of these caught real bugs

Worth saying, because a suite that has never failed is a suite nobody should
trust. `case_audio`'s occlusion check found that the occluder only advanced its
glide on the frames it re-cast the ray — it recomputed the target as "wherever
we already are" in between — which made a door opening four times slower than
the glide time said. `case_audio`'s score check found nothing wrong with the
score and everything wrong with the test: the live fear state was overwriting
the value the test set, every frame, which is correct behaviour and makes the
mix untestable until the wire comes off for the duration.

### What each case is defending

| Case | The device symptom it exists for |
|---|---|
| base is fixed | the stick's ring travelled across the screen with the thumb |
| two thumbs are independent | lifting the left thumb disturbed the view |
| replanting | the same, at speed, six times in a row |
| ownership survives leaving the region | a thumb sliding onto the other stick stole it |
| relative is never trusted | the camera spun when the second thumb landed |
| first move is free | a jump on the first frame of a look gesture |
| pause | a stick still held on resume; a camera that jumped |
| layout | a prompt drawn under a thumb; a target below 44 pt |
| interact | a target offered through a control; a drag turning the wrong wheel |
| save | a slot that does not come back; a code that crashes on a bad paste; a browser that refuses storage taking the game down with it |
| render | an accessibility setting that does not reach the shader; a fear number that leaves 0..1 and takes the grain with it |
| audio | a volume slider moved while ducked staying ducked; a wall that is not heard as a wall; one stride making three footsteps |
| reading | a page that scrolls the wrong way; a document read in Act 1 that a reload forgets |
| act1 | **is it finishable.** Every other case asserts a mechanism; this one walks the act. It also walks the stair rather than teleporting past it, because the only way to know a ramp under the nosings is right is to put a player on it and see where they end up. |
| devices | a valve that reports open one turn early; a selector that runs off the end of its own plate; a nameplate edited on a prop until the load puzzle has one answer or none |
| act2 | **is the wrong answer still interesting.** It walks the shed-the-heater allocation that holds for nine seconds and then dies when the sump starts, because that failure is the act's best moment and would ship broken silently |
| tools | a tool that follows the camera instead of being it; one that vanishes when the act it was found in is thrown away; a save that puts it in the wrong hand |
| observer | every row of STORY.md's rule table, because the player is meant to *learn* those rows and a rule that is true four times in five is not a rule |
| act3 | **does one building hold two logics.** The annex is rooms in Act 2's scene, so this case walks across the seam between `ShelterLogic` and `AnnexLogic` — and it is the only case that watches the entity run in a level rather than in a fixture |
| act4 | **does it end.** The first thing in this project that branches, so the only case that walks the same act twice and expects two different answers. It reloads between runs rather than undoing an ending: a test that could take one back would be testing something the player cannot do |
| playthrough | **do the acts join up.** Every other act case sets its own preconditions, which is the right trade and leaves exactly one thing uncovered. This one never calls `load_act`: it walks through the shelter door, takes the reel, and comes out in the gallery, and it is the only check that the act runner, the stashes and the two handovers work in the order a player meets them |
| reach | **is it touchable.** For every interactable in the act it works out where a player would have to stand, checks there is floor there, aims from eye height, and asks the interactor what it sees. It is the only case that can fail with "line of sight blocked by StaticBody3D", and it is the case that found the most: see below. |

A case that leaves the world somewhere runs before one that assumes where it is.
`case_interact.gd` puts the player where it needs them **and** calls
`Player.face()`, because the input cases before it turned the camera 27° and a
ray does not care that the test meant to look forward.

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

## `capture_shots.js` — what it looks like

Not a test. It is how art gets reviewed by somebody who has no desktop editor
session and cannot run the game.

```sh
npm --prefix tools/web run shots     # -> docs/shots/, committed
```

`src/render/shot_list.gd` exists only when the page carries `?shots=1`, walks a
fixed list of poses, and holds each still until it has been photographed. Fixed
poses are the whole point: a suite that walks the player around produces two
screenshots of two different walls, and nothing can be said about a change
between them.

It is not silent about failure. A uniformly black frame compresses to a couple
of kilobytes, so any shot under 4 kB fails the capture rather than quietly
committing a gallery of black — which is exactly what the first run of the post
stack would have produced, because the LUT's contrast pivot was at 0.5 and this
game's image lives below 0.25.

The poses are computed from the room's geometry, not eyeballed. `forward(yaw)`
is `(-sin yaw, 0, -cos yaw)`, which is not the sign anyone guesses first.

## `smoke_web.js` — does the game run

Serves the build, walks the tap gate, drives real touch events through CDP
(`Input.dispatchTouchEvent`; synthetic mouse drags never reach the game because
Chromium's mobile emulation swallows them), and screenshots each stage into
`build-smoke/`. CI keeps those screenshots as an artifact for 14 days.

It asserts the export variant (single-threaded, Compatibility, no
`SharedArrayBuffer`, no cross-origin isolation), that the canvas renders at CSS
resolution rather than 3×, and then opens the debug overlay and works through
the control scheme, the pause button and settings persistence against it.

### Multi-touch through CDP

The touch cases are duplicated here on purpose. `tests/` proves the arithmetic
against synthetic events; this proves the same behaviour survives a real browser
at the device's real metrics — CSS pixels, `devicePixelRatio` 3, a canvas that
is not the viewport, and a safe area the shell measured rather than one a test
declared. The reserved rects come back through `window.__itaw_probe` in viewport
units and the suite converts them to CSS points using the two sizes the overlay
reports, so the conversion is measured rather than assumed.

**`Input.dispatchTouchEvent`'s `touchEnd` takes the point being *released*, not
the ones remaining.** Passing the remainder lifts the wrong finger, silently,
and a suite that does it proves nothing while looking green. Chromium generates
one DOM event per changed point and fills the other live points in as
stationary, so the driver here sends exactly one changed point per call.

### What only a browser can be asked

Several assertions here have no headless equivalent because they are about the
canvas and the HTML shell sharing a screen:

- the debug overlay clears the build stamp the shell draws in the same corner,
  and is not drawn on top of any reserved rect;
- the pause panel fits the viewport and Resume is inside it — a menu taller than
  the screen puts its own buttons out of reach, and a screenshot of a canvas
  cannot be asked where its buttons are, so `PauseMenu` publishes the rects a
  frame after opening (before that, containers have not been laid out and every
  child answers with where it used to be);
- the shell's stamp hides while the menu is open and comes back when it closes;
- the game registers a suspend hook, and `pagehide` and a hidden
  `visibilityState` each write an autosave — the events iOS actually fires when
  it takes a tab away, which headless Godot never sees;
- an autosave survives a reload (the *world* in it, not the blob: reloading
  fires `pagehide`, which correctly writes a fresh one with a new timestamp);
- breaking `window.__itaw_store.write` makes the game say it cannot save rather
  than fall over;
- the Add-to-Home-Screen offer appears once and never again.

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
| **D recovery** | The host is made to hand out a document from a previous build, naming engine files this deploy no longer has. The whole recovery ladder is then climbed: the page heals itself (purge, clean reload, playable), records that it had to, and reports a purge that *completed* rather than one that hit its deadline. The same failure a second time in the same tab must **not** purge again — it says so and offers "Reload cleanly", which works. |

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

### Why phase D breaks the document, not the cache

The first version of this wrote rubbish into the worker's Cache Storage in place
of the engine script. That reproduced the *symptom* but not reliably: whether a
poisoned entry reaches the page depends on the browser and on what its own HTTP
cache is holding. It stranded the build on full Chromium and was quietly
bypassed on CI's headless shell, however hard the HTTP cache was cleared or
disabled — so the assertion kept concluding the page was fine, which it was, for
reasons that had nothing to do with what was being tested.

What phase D breaks now is the **document**, which is the failure a deploy
actually produces: `index.html` from a previous build, still being handed out,
naming payload files the new deploy has already deleted. Every reload 404s
identically and no amount of reloading fixes it. Navigation is network-first, so
that document reaches the page with no cache in the way, on any browser. The
worker stays registered and its cache stays full throughout — that is what the
purge has to clear, and what D4 counts.

### Why the stale document disarms itself

`state.stale` keeps answering document requests until a request carrying
`?fresh=1` arrives. Counting uses instead does not work: navigation preload can
spend one, and whether preload is enabled at any given moment depends on how
recently a worker activated — which made this suite pass and fail on the same
machine. Disarming on `?fresh=1` keys the change to the one event that means the
client has decided to start clean, so there is nothing timing-dependent left.

### When a run disagrees with itself

`ITAW_SERVE_LOG=1` turns the test server into a witness: every request, its
`Sec-Fetch-Mode` and `Sec-Fetch-Dest`, and whether it was answered with the
stale document. Which request got what, in what order, is usually the whole
answer — it is how the preload double-fetch above was found.

### The browser matters here

CI runs Playwright's own `chrome-headless-shell`; a dev box with
`CHROMIUM_PATH` set runs whatever full Chromium is on it. They do not agree
about service workers. The bug that made this suite go red on CI and stay green
locally was ultimately in the suite, not the product (the forged rebuild did not
replace the payload name in the shell's own config, so it loaded out of whatever
cache still held the old files) — but chasing it turned up two real ones. The
navigate branch was calling Godot's `fetchAndCache`, which awaits
`event.preloadResponse`; where a navigation preload rejects, that branch throws
and the **cached** document is served, which is the exact failure phase D now
exists to test. And navigation preload, which Godot enables and nothing here
reads, was issuing a second discarded request for `index.html` on every
navigation. The navigate branch fetches for itself now, and the worker switches
preload back off.

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

---

## One warning about writing a test that disturbs state

`case_act1`'s save check deranges every saveable node and then asserts it comes
back. The first version disturbed each node *by calling its own `load_state`*,
which is circular and proves nothing: a `load_state` that quietly does nothing
leaves the node holding the state it already had, the reload restores what was
never lost, and the check passes over a broken device. That was not reasoned
out — it was found by breaking `DeviceToggle.load_state` on purpose and watching
the suite stay green.

The fix is to assert the contract directly: **whatever `load_state` is given
must be visible in the next `save_state`.** A node that swallows its input is
named and fails.

Two lessons worth keeping:

- **A new check earns its place by failing.** Break the thing it covers and
  watch it go red before believing it. Three checks in this suite were rewritten
  after failing that.
- **A false positive is a bug in the check.** The same sweep first accused
  `Player` of ignoring `load_state`; it was the sweep emptying arrays, and the
  player's `at.size() == 3` guard correctly reading an empty array as absent.
  The careful code looked broken to the careless test.

---

## Two things about the live site that are easy to get wrong

**The build is not byte-reproducible, and that is fine.** The same commit built
here and built in CI produces the same `.wasm` and `.js` (they are the export
template, untouched) and a `.pck` that differs by a few hundred bytes. The
payload id in the filename is a content hash over those three, so the id differs
too. Do not treat "my local payload id is not the one that is live" as a failed
deploy — compare the **commit** in the build stamp, which is what
`tools/ci/verify_live.sh` does.

**Nothing points a browser at the live URL, deliberately.** The chain that makes
a deploy trustworthy is: CI builds, runs the headless suite, runs `smoke_web.js`
and `smoke_pwa.js` *against the very artifact it is about to upload*, deploys
that artifact, and then `verify_live.sh` curls the published site for the right
commit stamp, the payload it names, and the content types. So the bytes that
ship are browser-tested; what is asserted about the live host is served
correctly rather than played. Playing it live is a device-QA item, which is
where it belongs — that check needs a real phone anyway.

(An attempt to add a Playwright run against the published URL was abandoned: in
this container Chromium's HTTPS never reaches the egress proxy, so it could not
be made to work honestly. It would also have duplicated the two checks above.)

---

## Empty space is part of the fixture

Two cases build their own scene rather than using an act: `case_observer` needs
a lamp, a stand-in and nothing else, and `case_tools` needs a room with one
light in it and one body between.

Both put that scene **sixty metres under the building**, and they have to. The
suite runs every case against one tree and one physics space, so a bare lamp at
the origin is inside Act 1's generator hall, and every sight line either case
cares about is cut by a wall it never asked for. The first version of
`case_observer` failed nine checks for exactly that reason and the failures all
looked like bugs in the entity.

The matching rule: **a case that changes the world puts it back.** Cases run in
one process in order, so a case that finishes in the wrong act, or leaves a prop
in somebody else's level, breaks its *neighbours* rather than itself — which is
the worst way to find out. `case_tools` borrows the mounted act to put a
photometer in, and asserts that it took it out again.

---

## Setting state, and pressing things

`DeviceToggle.on` moves the handle and does **not** emit `toggled`. That is
right — restoring a save should put a hundred handles where they belong without
a hundred acts reassessing themselves — and it means assigning `on` in a test
changes what the panel *looks* like and tells the act nothing.

So: assign when you are standing in for progress the player already made, and
`Zone.engage()` when you are standing in for the player. `case_playthrough`
failed three checks on exactly this, in a way that read as the shelter's power
being broken.

The same distinction bit twice more:

- `DeviceSelector.select()` and `Timeclock.load_state()` are restores, not
  turns, and neither announces itself.
- `ActRunner.load_act()` on the act already mounted is a no-op, deliberately —
  walking through a door you are already behind should not rebuild the
  building. A case that wants a *new game* wants `restart()`, which clears the
  stashes and rebuilds, in that order. The other order restores the stash on
  the way out and saves it straight back.
