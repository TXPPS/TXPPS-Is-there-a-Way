# Progress

> Read this file and `ARCHITECTURE.md` first. They are written assuming you
> remember nothing about this project.

## Resume here

**Unattended run, finished.** The work order was A finish P1, B write the story
bible, C P2 rendering, D P3 audio, E Act 1 as a vertical slice, F later acts
only if credits remained. **A through E are done and live. F was deliberately
not started** — the work order's own rule was that a polished Act 1 plus a clear
plan beats four half-dressed acts, and Act 1 has still never been played by a
human.

| | |
|---|---|
| **Live** | <https://txpps.github.io/TXPPS-Is-there-a-Way/> |
| **Stamp to expect** | `v0.1.0 4d2097d` (or later — every push deploys) |
| **First thing to do** | `docs/NEEDS_DEVICE_QA.md`, all 78 items, in order. Section "Controls" first: if that fails, stop, because everything else stands on it. |
| **Blocked on a human** | Everything unverifiable. Nothing is blocked on a decision. |
| **Frozen** | The input layer. No change to touch semantics, layout or the router without a failing test to justify it. |

### What is true now that was not

- **Act 1 is playable start to finish** and `tests/case_act1.gd` walks it every
  build — including down the stair, which is the only way to know a ramp under
  the nosings is right.
- **Every interactable is provably reachable.** `tests/case_reach.gd` works out
  where a player would have to stand for each one and asks the interactor what
  it can see from there. Written last, it found the three worst bugs in the act
  (below), none of which any screenshot or existing test could show.
- The **story bible** exists (`STORY.md`), the puzzle set is derived from it
  (`PUZZLES.md`), and every puzzle device in the game traces to a line in the
  programme's equipment schedule.
- **Both P0 render defects are fixed**, the post stack is built, and
  `docs/shots/` is a committed gallery of what it looks like.
- **Everything the game hears is generated** by a committed script, and the
  score follows one fear number.
- **Saves persist**, survive a tab being discarded, and can be exported as a
  text code — which on this platform is the only save the player really owns.

### What Act 2 needs, when it starts

`PUZZLES.md` has the design. What is missing is only content and two systems:

1. **The shelter's spaces** — bunk room, mess, latrines, plant room, ration
   store. The kit builds them; the work is dimensions and dressing.
2. **A generator that runs** (`P2.1`–`P2.3`). The devices exist; the load-shed
   panel is arithmetic on nameplates and wants a small `LoadPanel` that sums
   what is connected and trips when it exceeds the set.
3. **The intercom** (`P2.4`) — Emil's first four sentences. Needs a voice, and
   this project generates its audio, so that is a genuine open problem worth
   deciding before it is built.
4. **A second LUT** and a fluorescent practical: the palette shift from sodium
   to sick green-white is what marks leaving the dam and entering the programme.
5. **The six S1 rooms** from `STORY.md` — the staged rations, the made bunk, the
   service card. Those are the act's whole job.

Do not start it until the device QA in `NEEDS_DEVICE_QA.md` has come back.

**Engine:** Godot 4.6.3-stable, Compatibility (WebGL2), single-threaded web export.
**Target:** iPhone 16 Pro Max, Safari, **landscape**.

---

## Deploy state — exact

# **Live: <https://txpps.github.io/TXPPS-Is-there-a-Way/>**

| | Status |
|---|---|
| Build | **green.** Export, budgets (download, texture size, shipped audio), **248-check headless suite**, 55-check gameplay smoke, 28-check update-path smoke. |
| Publish | **automatic.** Every push to `main` deploys, and so does a manual **Run workflow** on `main` — both proven, runs #15 and #16. |
| Verified | the `verify` job fetches the live URL after every deploy and fails the build unless it serves *this* commit with every payload file answering 200 and the wasm as `application/wasm`. |
| Cloudflare Pages | still no credentials; that job skips. Optional — it buys `web/_headers` and nothing else. See `DEPLOY.md`. |

### What the gate was doing wrong

Both deploy jobs used to test
`github.ref_name == github.event.repository.default_branch`. The payload half is
a **snapshot taken when the event was created**, and it went stale two ways:

- a **re-run replays the original event's payload**, so attempt 2 of a run is
  gated on what was true when attempt 1 started;
- the push event a **branch rename** produces can still carry the branch's old
  name as `default_branch`.

Run #13 was a genuine `push` with `head_branch: main` — not a
`workflow_dispatch` — re-run as attempt 2 after Pages was switched on. Its
`ref_name` was `main`, its payload disagreed, both deploy jobs skipped, and the
build went green having published nothing.

The `probe` job now asks the API what the default branch is at the moment the
run executes, and both deploy jobs gate on that output. An API call cannot be
stale and does not care which event triggered the run, so a manual
**Run workflow** on `main` publishes exactly like a push. Every run prints a
**Deploy gate** table into the probe summary — event, attempt, `ref_name`, the
live default branch, the payload's version of it, and the decision — so a deploy
that does not happen always says why.

Then the deploy itself was rejected by the `github-pages` environment's
deployment-branch policy, which still named the pre-rename branch. `DEPLOY.md`
has the detail; the short version is that the job no longer declares an
`environment:`, so Actions no longer pre-approves a deployment it was going to
refuse.

## Phase plan

| Phase | Scope | State |
|---|---|---|
| P0 | Repo, CI, deploy, PWA shell, gray-box room live on the phone | **live; awaiting device QA** |
| P1 | Player controller, touch input, interaction system, settings, save/load | **done.** Controls, HUD, pause, settings, focused interaction, save/load. The interaction *grammar* — what there is to interact with — comes from P5. |
| P4 | `STORY.md` bible + plot-hole audit + narrative/document systems | **bible and puzzle set done** (moved before P2: art and puzzles are both derived from it). The narrative/document *systems* — how a page is read on a phone — belong to P5. |
| P2 | Rendering stack: post-process, materials, lighting rig, test scene | **done for Act 1's vocabulary.** Post stack, LUT grade, one triplanar material shader covering six surfaces, both P0 defects fixed. Later acts need a second LUT and a fluorescent practical. |
| P3 | Audio engine, generation pipeline, adaptive score prototype | **done.** Seventeen generated sounds, a four-layer score on the fear number, occlusion, reverb zones and footsteps. The mix has never been heard on a phone. |
| P5 | Act 1 vertical slice, fully dressed and scored | **playable end to end.** Five spaces, five puzzles, seven documents, scored, and walked by the suite every build. Dressing is graybox-plus: the kit is real, the props are boxes. |
| P6 | Acts 2–4 content, entity AI, endings | not started |
| P7 | Performance, load time, accessibility, polish, final mix | not started |

---

## What exists

**Pipeline**
- `tools/ci/fetch_godot.py` pulls the pinned engine and, by reading the export
  archive's zip index over HTTP range requests, only the Web templates (~81 MB
  instead of the full 1.26 GB pack).
- `tools/ci/build_web.sh` is the single build entry point, identical locally and
  in CI: stamp → verify generated art → import → run headless → export → harden
  → budget check.
- `tools/ci/postprocess_web.py` inlines `web/boot.js` and the build stamp into
  `index.html`, content-hashes the engine payload, rewrites every reference, and
  **fails the build if the export is threaded or asks for cross-origin
  isolation**.
- `tools/ci/service_worker.py` reworks Godot's generated worker so a new build
  can reach a phone: cache named after the build, immediate takeover,
  network-first navigation, and a `?fresh=1` bypass. Every edit is asserted
  against Godot's output, so a template change fails the build rather than
  shipping an unpatched worker.
- Three suites, all in CI (`docs/TESTING.md`): `tests/` in headless Godot (the
  control scheme, pause, the reserved rect contract, settings, interaction),
  `smoke_web.js` (does the game run, in a browser at device metrics) and
  `smoke_pwa.js` (can I get out of a bad build).

**Game**
- One gray-box room, 14 × 3.4 × 9 m on a 0.5 m grid, one sodium bulkhead lamp
  with a visible fixture, one steel crate to walk into, and a three-wheel dial
  lock on the north wall.
- First-person `CharacterBody3D` with acceleration/braking, head bob, and
  smoothed look. All feel constants live in `src/player/player_tuning.tres`.
- **Fixed twin sticks.** Left walks, right turns. The right stick is rate-based:
  deflection is angular velocity, with a response curve, separate X/Y
  sensitivity, invert-Y and a hard ceiling on turn rate. It recentres the moment
  the thumb leaves. **Drag-to-look is kept whole** behind *Look style*.
- **One `TouchRouter`** owns every touch: claimed by the region it began in,
  held until release, with the delta derived per touch index rather than read
  from the engine's `relative` field. See ARCHITECTURE.md, "Touch ownership".
- **Reserved HUD rects.** Every control registers the screen area it owns;
  nothing else may draw there and nothing in the world may be targeted through
  it. Three action-button slots are reserved before any button exists.
- **Pause menu**, top-right button: stops the simulation, drops every touch,
  ducks the mix, resumes with no camera jump. Resume, a controls diagram that
  redraws when the scheme changes, nineteen settings in four groups, Return to
  Title behind a confirm, and the build stamp at the foot, tappable to copy.
- **Settings persist on the keystroke** and apply live — no Apply button, no
  restart. Stored through IndexedDB with a synchronous localStorage mirror.
- **Audio buses** wired: Master, SFX, Music, Voice, with the volume sliders live.
- **Focused interaction**: a centre-screen ray finds an `Interactable`, the
  action button engages it, the sticks go away and every gesture goes to the
  thing engaged with. `DialLock` is the first user and is disposable.
- Safe-area insets bridged from CSS to the HUD so nothing sits under the
  Dynamic Island or the home indicator — converted from CSS points into viewport
  units, which the previous pass did not do and which left the insets about a
  third short.

**Instrumentation** — because a phone has no console
- **Build stamp**, top-left, 13 px: `v0.1.0 abc1234`. Tap it to copy a full
  report (branch, build time, payload hash, storage health, worker state,
  viewport, safe area, user agent) to the clipboard.
- **Debug overlay**, top-left under the stamp, summoned by a **three-finger
  tap**, in two columns: pack and shell build, fps, CPU frame time, draw calls,
  primitives, viewport / window / CSS size, DPR, safe-area insets, live touch
  IDs, **which control owns which finger**, both sticks' deflection, storage
  health, worker state, hum playback position, mixer latency, update state, PWA
  install state. Two columns because one is taller than the space above the
  movement stick, and the overlay may not be drawn on a control — the browser
  suite asserts both that and its clearance from the build stamp.
- **Error toasts**, top-centre: any GDScript error, engine error, or unhandled
  JavaScript exception becomes a dismissible on-screen message instead of a
  silence. Repeats fold into one toast with a count.
- **A 120 Hz ballast hum** at the lamp, synthesised in `src/world/lamp_hum.gd`,
  so the audio unlock can be confirmed by ear. Deleted in P3.
- **Self-healing.** If the engine payload will not load, the shell purges and
  reloads itself once per tab; if the clean load fails too it stops and shows a
  **Reload cleanly** button rather than looping.

**Saving**
- Versioned JSON, one autosave slot and one the player writes, and a migration
  mechanism that is exercised rather than promised. See ARCHITECTURE.md.
- Writes on a checkpoint and whenever the browser says the tab is going away
  (`freeze`, `pagehide`, hidden `visibilityState`) — the events iOS fires when
  it discards a backgrounded tab without running another frame.
- Every write is read back. A browser that will not keep a save says so on
  screen and the game carries on.
- **Export code** puts the whole save on the clipboard as `ITAW.…`, a couple of
  hundred characters. **Import code** takes it back through a browser `prompt()`.
  This is not a convenience: Safari evicts storage for a site nobody installed
  after about a week idle.
- Storage persistence is requested at boot and reported on the debug overlay.
- One-time **Add to Home Screen** offer, ninety seconds in, iOS only.

**Rendering**
- One triplanar shader (`src/render/surface.gdshader`) and one 256×256 RGBA
  tile are the whole surface vocabulary: wet concrete, oxidised steel, flaking
  marine paint, river silt, condensation, and staining as a parameter on all of
  them. No normal maps — roughness carries it, which is the most likely thing
  in the stack to be wrong on a phone.
- Post stack on a CanvasLayer below the HUD: lens (barrel + CA), LUT grade,
  fear-driven grain, ordered dither, vignette. Tonemap and bloom stayed with
  the engine, for reasons in `DECISIONS.md` D17.
- **Both P0 render defects fixed.** The lamp no longer clips to white; the
  falloff no longer bands.
- `docs/shots/` is a committed gallery of eight fixed poses, captured by
  `npm --prefix tools/web run shots`. It is how art gets reviewed without eyes
  on a device.

**Audio**
- Everything is generated by `tools/audio/make_audio.py` — pure Python, no
  dependencies, 4.4 seconds for seventeen sounds, and CI regenerates and diffs
  them like it does the icons. Modal synthesis for metal, filtered noise for
  water, a jittered impulse train for machinery.
- Tonal loops are periodic by construction, not crossfaded: 16 seconds, every
  frequency a whole multiple of 1/16 Hz.
- The score is four layers crossfaded by the fear number, gliding over 2.4 s so
  it cannot narrate. Each layer is complete on its own.
- Occlusion is one ray four times a second; reverb is one effect on SFX driven
  by whichever zone the listener is in; footsteps are distance-driven and read
  the surface from `SurfaceTag`, which is the P1 scaffolding finally wired.
- **1.09 MB shipped** against a 12 MB budget.
- `src/world/lamp_hum.gd` is gone, as its own comment said it would be in P3.

**Act 1**
- Five spaces on the 0.5 m grid — generator hall, switchgear room, lockmaster's
  office, stair shaft, gallery — built by `src/world/kit/` from their dimensions.
- All five puzzles from `PUZZLES.md`: emergency lighting (read the schedule,
  pull the faulted circuit's fuse, close the main), the switchgear interlock,
  the stair with its missing third step, the watertight door and its wrench, and
  the admit bell.
- Seven documents, each where the person who wrote it left it.
- Starts in the dark. The flashlight is the only light until the first puzzle.
- `tests/case_act1.gd` plays the whole act every build, and walks the stair
  rather than teleporting past it.

**Written down, not yet built**
- `docs/STORY.md` — the bible. Premise, the 1998 present, the four levels, the
  programme's funding line and equipment schedule, Emil Ostrander, the cast, a
  dated timeline, the rule the player must be able to learn, why every locked
  door is locked, twenty-four documents with their authors and their reasons to
  exist, the plot-hole audit, and two endings.
- `docs/PUZZLES.md` — every puzzle in every act: mechanism, the in-world
  information that solves it, its justification, and what it depends on. Four
  verbs, taught in Act 1 and never added to. The dial demo currently in the
  gray-box room is replaced by `P3.1`, the programme's own timeclock.

**Still scaffolding, not wired to anything**
`src/core/surface_type.gd` and `src/world/surface_tag.gd` — the footstep-audio
hook P3 needs. Nothing else in `src/core/` is inert any more.

---

## Known broken, or deliberately deferred

Report anything **not** on this list.

- **The runner still warns about Node 20**, and it cannot be silenced yet: the
  five actions it originally named are on their Node 24 majors, but
  `upload-artifact@v5` targets Node 20 itself, `upload-pages-artifact@v3` pins
  `upload-artifact@v4` internally, and `configure-pages` / `deploy-pages` have
  no Node 24 release. Cosmetic; not worth breaking the deploy over.
- **The `github-pages` environment still carries a branch policy naming the old
  branch.** It costs nothing now — the deploy job declares no environment — but
  it means the run page shows no environment URL. Fixable in Settings →
  Environments → github-pages if you ever want that back.
- **A save restores the act's state, not the act's staging.** Every latch,
  breaker, valve and door reports its own state and comes back — `case_act1`
  saves mid-act, feeds *every* saveable node a deliberately wrong state, checks
  each one actually noticed, reloads, and compares the whole collected
  dictionary key by key — and `PowerhouseLogic` fires a checkpoint at each of
  the five gates. What a reload does *not* restore is
  anything transient that was mid-flight when you left: a door part-way through
  its swing finishes closed, the admit bell's eleven-second delay restarts, and
  a page you were holding is put down. All three are recoverable in play, none
  of them can strand you, and fixing them properly means saving timers rather
  than states — which is worth doing when there is a second act to lose, not
  now.
- **Haptics do nothing on iOS.** The setting exists and the call site is right;
  Safari does not implement `navigator.vibrate`, so on this device it is a no-op
  by the platform's choice rather than ours. Leave it on.
- **`Colourblind cues` currently affects one thing**: a cross drawn through the
  look stick's knob, so the two sticks differ by shape and not only by which
  corner they are in. When real puzzle cues exist they read the same setting.
- **`Subtitle size` has no subtitles to size.** The Accessibility group shows a
  sample line at the chosen size so the choice is meaningful; the value is what
  subtitles will use when they exist.
- **The interaction prompt sits high on the screen**, above the action arc
  rather than under the reticle. That is deliberate: the arc is pinned to the
  bottom edge and the screen centre is not, so a centred prompt walks into the
  buttons on a short window. If it reads oddly on the device, say so and it
  moves — it is one number in `hud_layout.tres`.
- **The build stamp's tap target is in the top-left corner.** It does not eat
  touches — the element ignores pointer events and the tap is recognised by
  geometry — and it is now nowhere near a control: the sticks are at the bottom
  corners and the pause button is top-*right*.
- **The overlay's `peak` reads `n/a` on the phone.** Godot's web build never
  populates the audio bus peak monitor. `hum on 12.34s` next to it is the real
  signal: if that number is advancing, the mixer is running.
- **Desktop mouse does not drive the touch HUD.** `emulate_touch_from_mouse` is
  on, but Chromium's mobile emulation swallows synthetic mouse drags. Real touch
  works everywhere. Keyboard (WASD) works, and **Escape** opens and closes the
  pause menu.
- **The dial lock is a throwaway.** Three wheels, combination 4-1-7, an
  indicator that goes green. It exists to exercise the focused-interaction
  framework on the device in the same round as the sticks; P1 replaces it.
- **The settings list scrolls by dragging it**, like any list on a phone. There
  is more below the fold than fits: four groups, nineteen settings, and the
  build stamp at the bottom.
- **Return to Title reloads the page.** A browser has no quit, and the page is
  fully cached, so it comes straight back on the tap gate. It is not instant on
  a cold cache.
- **No orientation lock is possible on iOS Safari.** The manifest asks for
  landscape and the shell shows a rotate overlay in portrait, but the OS rotate
  lock is the only real enforcement.
- **The lamp's emissive panel clips to white**, and there is **visible colour
  banding in the light falloff**. Both are waiting on P2's filmic grade, bloom
  and ordered dither.
- **Positional shadows are on and unmeasured** on the real device. P2 budgets
  them.
- **Frame rate is not asserted at 60 fps in CI.** Under swiftshader the runner
  gets 7–9 fps and the CPU frame-time monitor is contaminated by waits on the
  software rasteriser. CI asserts draw calls and primitives (which are
  renderer-independent) and a 250 ms tripwire for a runaway loop. 60 fps is a
  device measurement — item 10 on the checklist below.

---

## Open design decisions

See `DECISIONS.md`. The three that were open here are now closed:

- **Flashlight** — held item, no battery attrition, and not a light the entity
  can travel along (D14).
- **Fear state** — one float assembled from three named contributions (D15).
- **Score generation** — still open, and correctly so: it is decided in D
  against the measured size of what the generators actually produce.

New since the bible: everything in `STORY.md` and `PUZZLES.md` is a decision,
and the expensive one is **D16, the 1998 setting**. Every document, every piece
of equipment and the whole plot-hole audit rest on it.

---

## Device QA

The checklist lives in **`docs/NEEDS_DEVICE_QA.md`** — everything that is built,
green in CI, and still unverified by a human on a real phone. It is numbered and
meant to be run in one sitting. Read that file first.
