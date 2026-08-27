# Progress

> Read this file and `ARCHITECTURE.md` first. They are written assuming you
> remember nothing about this project.

**Current phase:** P0 live. The **HUD, control scheme, pause menu and settings**
half of P1 was pulled forward to fix what the first device QA found, together
with the focused-interaction framework and a throwaway dial puzzle to exercise
it. The rest of P1 — a real interaction grammar and save/load — waits on the
next round of QA.
**Engine:** Godot 4.6.3-stable, Compatibility (WebGL2), single-threaded web export.
**Target:** iPhone 16 Pro Max, Safari, **landscape**.

---

## Deploy state — exact

# **Live: <https://txpps.github.io/TXPPS-Is-there-a-Way/>**

| | Status |
|---|---|
| Build | **green.** Export, budgets, **96-check headless suite**, 43-check gameplay smoke, 28-check update-path smoke. |
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
| P1 | Player controller, touch input, interaction system, settings, save/load | **controls, HUD, pause, settings and focused interaction done**; interaction grammar and save/load blocked on QA |
| P2 | Rendering stack: post-process, materials, lighting rig, test scene | not started |
| P3 | Audio engine, generation pipeline, adaptive score prototype | not started |
| P4 | `STORY.md` bible + plot-hole audit + narrative/document systems | not started |
| P5 | Act 1 vertical slice, fully dressed and scored | not started |
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
- **No save/load.** The rest of P1. Settings persist; nothing else does, so
  "Return to Title" has nothing to warn you about discarding yet — the confirm
  step is there and worded for when it does.
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

See `DECISIONS.md` for ones already settled (orientation, premise, art
direction). Still open:

- Whether the flashlight is a held item with battery pressure, or a helmet lamp
  that is always on. Affects P1's interaction grammar and P2's lighting rig.
- Whether the fear state is a single scalar or a small vector (dread, exposure,
  proximity). P3's adaptive score wants to know.
- How much of the score is generated at runtime with `AudioStreamGenerator`
  versus rendered to `.wav` in CI. Decided in P3 against the 12 MB audio budget.

---

## Device QA checklist

Open <https://txpps.github.io/TXPPS-Is-there-a-Way/> in Safari, landscape.

Run in order. The build stamp must match the commit at the top of `main` —
check that first, because everything else is meaningless if it does not. CI
already asserts it, so a mismatch means you are looking at a cached page:
append `?fresh=1` and start again.

**Load and shell**
1. Page loads black; title fades up; the hairline rule fills.
2. "TAP TO BEGIN" appears. Tap it — the game starts. (This tap is also what
   unlocks Web Audio for every later phase.)
3. The **top-left stamp** reads `v0.1.0 <sha>` and matches the deployed commit.
4. **Tap the stamp.** A "Build details copied." toast appears; paste it
   somewhere and confirm it names the branch, payload hash and user agent.

**Controls — the point of this round**
5. Two rings, bottom-left and bottom-right. **Neither base may move.** Drag each
   thumb around: only the knob travels, and it stops at the ring.
6. Left thumb walks, in any direction, at a speed that follows how far you push.
7. Right thumb turns. It is a *rate*: hold it deflected and the camera keeps
   turning; let go and it stops dead, with no drift and no glide.
8. **Both thumbs at once.** Walk and turn together, then **lift the left thumb
   while the right one is still turning.** The camera must not stutter, jump or
   change speed. Re-plant the left thumb several times quickly. This is the one
   assertion that matters most; it is what was broken.
9. Start a drag on a stick and pull your thumb right across the screen and off
   the far side. It must keep driving the stick it started on, and must not
   touch the other one.
10. Walking into the crate stops you; you cannot leave the room.
11. Nothing sits under the Dynamic Island or the home indicator, and no control
    is within a slip of the build stamp or the pause button.
12. No rubber-band scroll, no double-tap zoom, no text selection, no page chrome.

**Pause and settings**
13. **Pause button, top right.** Tap it. The world stops, the mix ducks, the
    menu appears.
14. The **Controls** diagram shows two sticks and says what each does.
15. Open **Controls** in the list and switch **Look style** to **Drag**. Resume.
    The right stick is gone and dragging anywhere turns the camera. The diagram
    updates the moment you switch. Switch back.
16. Move **Turn speed**, **Stick size**, **Stick visibility**, **Stick height**
    and **Dead zone**. Resume after each. Every one must apply immediately.
17. **Master** and **Effects** must change the lamp hum while you listen.
18. **Brightness** and **Field of view** must change the scene live.
19. Pause, resume, and confirm **the camera has not moved** and no stick is
    stuck. Pause *while both thumbs are down*, resume, and check the same.
20. Reload the page. Every setting you changed is still set.
21. The stamp at the foot of the menu matches the top-left one; tap it to copy.
22. **Return to Title** asks first, then returns you to the tap gate.

**Interaction — new, and throwaway**
23. Walk to the far wall. A **dial lock** with three wheels. When you are close
    enough, a prompt appears and a round button appears above the right stick.
24. Tap it. The sticks disappear; you are locked to the panel.
25. Drag **up and down on one wheel**. Only that wheel turns, one number per
    pull. Try each of the three.
26. Set **4 1 7**. The indicator goes green.
27. Tap the button again. The sticks come back and the camera is where you left
    it.

**Instrumentation**
28. **Three-finger tap.** The overlay appears top-right. Read out `fps`, `cpu`,
    `draw`, `tris` — this is the only 60 fps measurement that means anything.
29. In the overlay: `safe` must be non-zero (the notch and home indicator),
    `dpr` should read 3, `store` should read `ok`, `sw` should read `active`
    after a reload.
30. Touch the screen with one finger, then two. The `touch` line must list the
    live touch IDs and clear when you lift.
31. **Audio.** Stand next to the lamp: a quiet mains hum. Walk away: it fades.
    In the overlay, `hum on N.NNs` must be **counting up**. Check with the
    silent switch both on and off, and note which one silences it.
32. Three-finger tap again — the overlay closes.

**The update path** (the part that decides whether I can ship you fixes)
33. Load the site, then leave the tab open.
34. Tell me, and I will push a rebuild. Wait for CI to go green. (Or trigger
    one yourself: Actions → build and deploy → **Run workflow** on `main`.)
35. Send the phone to the home screen and come back. A **"New version — tap to
    reload"** banner should appear at the top.
36. It must **not** appear while you are walking around with the tab in the
    foreground. If it does, that is a bug.
37. Tap it. The game reloads and the stamp shows the new commit.
38. **Break it deliberately:** append `?fresh=1` to the URL. The page purges and
    reloads onto the clean URL, and the game still loads. (You should not
    normally need this: a build that cannot load its payload purges itself.)

**Installed PWA**
39. Add to Home Screen. It launches full-screen, black, with the seam icon.
40. After one online run, put the phone in airplane mode and launch it again —
    it should still reach the tap gate.
41. In the overlay, `pwa` should read `true` when launched from the home screen.

**Errors**
42. If anything at all goes wrong, a toast should say what. If something goes
    wrong **silently**, that is itself the bug worth reporting.
