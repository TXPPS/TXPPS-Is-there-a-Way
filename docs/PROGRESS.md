# Progress

> Read this file and `ARCHITECTURE.md` first. They are written assuming you
> remember nothing about this project.

**Current phase:** P0 built, green in CI, **waiting on one deploy switch**.
**Engine:** Godot 4.6.3-stable, Compatibility (WebGL2), single-threaded web export.
**Target:** iPhone 16 Pro Max, Safari, **landscape**.

> ### The one thing blocking a live URL
> CI builds, smoke-tests and packages the site on every push. It cannot publish
> it yet, because both hosts need a credential this repo does not have:
>
> - **GitHub Pages** — GitHub's workflow token is not permitted to create a
>   Pages site. Switch it on once: repo → **Settings** → **Pages** → *Source* →
>   **GitHub Actions**, then re-run the latest workflow. Four taps, no secrets.
> - **Cloudflare Pages** (primary) — needs `CLOUDFLARE_API_TOKEN` and
>   `CLOUDFLARE_ACCOUNT_ID` as repository secrets. See `DEPLOY.md`.
>
> Until then the `deploy-pages` job prints the instructions in the run summary
> and does not fail the build. The finished site is downloadable from any run as
> the `web-build` artifact.

---

## Phase plan

| Phase | Scope | State |
|---|---|---|
| P0 | Repo, CI, deploy, PWA shell, gray-box room live on the phone | **done** |
| P1 | Player controller, touch input, interaction system, settings, save/load | next |
| P2 | Rendering stack: post-process, materials, lighting rig, test scene | not started |
| P3 | Audio engine, generation pipeline, adaptive score prototype | not started |
| P4 | `STORY.md` bible + plot-hole audit + narrative/document systems | not started |
| P5 | Act 1 vertical slice, fully dressed and scored | not started |
| P6 | Acts 2–4 content, entity AI, endings | not started |
| P7 | Performance, load time, accessibility, polish, final mix | not started |

---

## P0 — what exists

**Pipeline**
- `tools/ci/fetch_godot.py` pulls the pinned engine and, by reading the export
  archive's zip index over HTTP range requests, only the Web templates (~81 MB
  instead of the full 1.26 GB pack).
- `tools/ci/build_web.sh` is the single build entry point, identical locally and
  in CI: stamp → verify generated art → import → run headless → export → harden
  → budget check.
- `tools/ci/postprocess_web.py` content-hashes the engine payload, rewrites every
  reference, and **fails the build if the export is threaded or asks for
  cross-origin isolation**.
- `tools/web/smoke_web.js` loads the real export in headless Chromium at iPhone
  landscape metrics, walks the tap gate, and drives real touch events. 13 checks.
- `.github/workflows/build-and-deploy.yml` builds, smoke-tests, then deploys to
  Cloudflare Pages (when its secrets exist) and GitHub Pages (once it is
  switched on). Verified green on `claude/is-there-a-way-setup-kah9su`.

**Game**
- One gray-box room, 14 × 3.4 × 9 m on a 0.5 m grid, one sodium bulkhead lamp
  with a visible fixture, one steel crate to walk into.
- First-person `CharacterBody3D` with acceleration/braking, head bob, and
  smoothed look. All feel constants live in `src/player/player_tuning.tres`.
- Floating virtual stick (left half) and drag-to-look pad (right half), drawn
  with primitives, tuned by `src/input/touch_tuning.tres`.
- Safe-area insets bridged from CSS to the HUD so nothing sits under the
  Dynamic Island or the home indicator.
- Build stamp in the corner, so the phone can tell you which commit it is running.

---

## Outstanding work

### Before P1 can be called done
- Interaction system (raycast + context prompt + tap-and-hold).
- Focused-interaction mode (camera locks, puzzle takes gestures).
- Settings menu: sensitivity, invert-Y, stick size/opacity, brightness, audio
  mix, reduce-motion, subtitle size, colourblind-safe cues.
- Save/load.
- Haptics via `Input.vibrate_handheld()` where iOS allows it.

### Known gaps and bugs
- **Desktop mouse does not drive the touch HUD.** `emulate_touch_from_mouse` is
  on, but Chromium's mobile emulation swallows synthetic mouse drags. Real touch
  works everywhere. Keyboard (WASD) works. Revisit in P1 if desktop parity
  matters for authoring.
- **No orientation lock is actually possible on iOS Safari.** The manifest asks
  for landscape and the shell shows a rotate-your-device overlay in portrait,
  but the OS rotate lock is the only real enforcement. The shell says so.
- **The lamp's emissive panel clips to white.** Correct-ish for a practical, but
  it wants the P2 filmic grade and bloom before it reads as film rather than
  as a blown texel.
- **Visible colour banding in the light falloff.** Expected in 8-bit with no
  dither; the P2 ordered-dither pass is aimed exactly at this.
- Positional shadows are enabled and appear to work under Compatibility, but
  have not been measured on the actual device. Verify in P2 and budget them.

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

## Test checklist for the phone (P0)

1. Page loads black, title fades up, hairline progress rule fills.
2. "TAP TO BEGIN" appears; tapping it starts the game (this is also what
   unlocks Web Audio for every later phase).
3. Left thumb anywhere on the left half raises a ring and knob where the thumb
   landed; dragging walks. Right thumb drags to look.
4. Walking into the crate stops you; you cannot leave the room.
5. Nothing sits under the Dynamic Island or the home indicator.
6. No rubber-band scroll, no double-tap zoom, no text selection, no page chrome.
7. Rotating to portrait shows the rotate overlay.
8. Add to Home Screen → launches full-screen with a black background and the
   seam icon; after one online run, it opens with the network off.
9. The corner stamp matches the commit that was deployed.
