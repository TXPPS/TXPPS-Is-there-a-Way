# Progress

> Read this file and `ARCHITECTURE.md` first. They are written assuming you
> remember nothing about this project.

**Current phase:** P0 built and hardened for device QA. **Waiting on one deploy
switch and on QA on the phone.** P1 does not start until that QA has been run.
**Engine:** Godot 4.6.3-stable, Compatibility (WebGL2), single-threaded web export.
**Target:** iPhone 16 Pro Max, Safari, **landscape**.

---

## Deploy state — exact

| | Status |
|---|---|
| Build | **green.** `build` job passes: export, budgets, 23-check gameplay smoke, 28-check update-path smoke. |
| Default branch | still `claude/is-there-a-way-setup-kah9su`. The rename to `main` is **blocked**, not by the token but by the API proxy this session runs behind: every write path returns *"Write access to this GitHub API path is not permitted through this proxy."* Taps below. |
| Artifact | **published to every run.** `web-build` on the run page; `smoke-screenshots` too. |
| **GitHub Pages** | **NOT switched on.** `deploy-pages` runs, asks the Pages API, gets a non-200, prints the setup into the run summary and skips the deploy. |
| **Cloudflare Pages** | **no credentials.** `probe` reports no `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID`; `deploy-cloudflare` skips. |
| **Live URL** | **none yet.** Both hosts need one manual step that no token in this session can perform. |

**The gate is verified, not assumed.** Both deploy jobs test
`github.ref_name == github.event.repository.default_branch`. On the latest green
run the `deploy-pages` job **ran** — conclusion `success`, with only its inner
steps skipped, and those skipped because Pages is off, not because of the gate.
A job whose `if:` were false shows as `skipped` outright, the way
`deploy-cloudflare` does. So the expression resolves and it matches on whatever
the default branch is called. Rename the default to `main` and pushes to `main`
give `ref_name == 'main' == default_branch`: the same expression, the same
answer, no edit here. The workflow's `on: push` already lists `main`.

### Renaming the default branch — five taps

1. `github.com/TXPPS/TXPPS-Is-there-a-Way` → **Settings** → **General**
2. Under *Default branch*, tap the **pencil / switch** icon next to
   `claude/is-there-a-way-setup-kah9su`
3. Type `main` (do **not** create a branch called `main` first — the rename
   refuses if the name is taken)
4. **Rename branch**, then confirm
5. Nothing else. GitHub retargets open PRs and redirects old links; the deploy
   gate follows automatically.

### What unblocks a URL — GitHub Pages, three taps

This is the shortest path to something openable on the phone.

1. `github.com/TXPPS/TXPPS-Is-there-a-Way` → **Settings** → **Pages**
2. *Build and deployment* → **Source** → **GitHub Actions**
3. **Actions** → latest run → **Re-run all jobs**

Then: `https://txpps.github.io/TXPPS-Is-there-a-Way/`

### Or Cloudflare Pages — better caching, one token

Only Cloudflare honours `web/_headers`. Mint a custom token with exactly
**Account · Cloudflare Pages · Edit** scoped to your account, and add it plus the
account ID as repository secrets. Full walkthrough in `DEPLOY.md`.

---

## Phase plan

| Phase | Scope | State |
|---|---|---|
| P0 | Repo, CI, deploy, PWA shell, gray-box room live on the phone | **built; awaiting device QA** |
| P1 | Player controller, touch input, interaction system, settings, save/load | blocked on device QA |
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
- Two headless suites, both in CI (`docs/TESTING.md`): `smoke_web.js` (does the
  game run) and `smoke_pwa.js` (can I get out of a bad build).

**Game**
- One gray-box room, 14 × 3.4 × 9 m on a 0.5 m grid, one sodium bulkhead lamp
  with a visible fixture, one steel crate to walk into.
- First-person `CharacterBody3D` with acceleration/braking, head bob, and
  smoothed look. All feel constants live in `src/player/player_tuning.tres`.
- Floating virtual stick (left half) and drag-to-look pad (right half), drawn
  with primitives, tuned by `src/input/touch_tuning.tres`.
- Safe-area insets bridged from CSS to the HUD so nothing sits under the
  Dynamic Island or the home indicator.

**Instrumentation** — new this pass, because a phone has no console
- **Build stamp**, top-left, 13 px: `v0.1.0 abc1234`. Tap it to copy a full
  report (branch, build time, payload hash, storage health, worker state,
  viewport, safe area, user agent) to the clipboard.
- **Debug overlay**, top-right, summoned by a **three-finger tap**: pack and
  shell build, fps, CPU frame time, draw calls, primitives, viewport / window /
  CSS size, DPR, safe-area insets, live touch IDs, storage health, worker state,
  hum playback position, mixer latency, update state, PWA install state.
- **Error toasts**, top-centre: any GDScript error, engine error, or unhandled
  JavaScript exception becomes a dismissible on-screen message instead of a
  silence. Repeats fold into one toast with a count.
- **A 120 Hz ballast hum** at the lamp, synthesised in `src/world/lamp_hum.gd`,
  so the audio unlock can be confirmed by ear. Deleted in P3.
- **Self-healing.** If the engine payload will not load, the shell purges and
  reloads itself once per tab; if the clean load fails too it stops and shows a
  **Reload cleanly** button rather than looping.

**P1 scaffolding, written but not wired to anything**
`src/core/game_state.gd`, `settings_row.gd`, `settings_spec.gd`,
`assets/settings/settings_spec.tres`, `src/core/surface_type.gd`,
`src/world/surface_tag.gd`. There is no settings menu yet; that spec is a
schema waiting for one.

---

## Known broken, or deliberately deferred

Report anything **not** on this list.

- **No live URL.** See the deploy table above. This is the top item, and it is
  three taps.
- **The default branch is not `main` yet**, and I could not rename it: the API
  proxy blocks writes. Five taps, above.
- **No settings menu**, despite `settings_spec.tres` describing fourteen
  settings. P1.
- **No save/load, no interaction system, no focused-interaction mode, no
  haptics.** All P1.
- **The build stamp's tap target is in the top-left corner.** It does not eat
  touches — the element ignores pointer events and the tap is recognised by
  geometry — but a *tap* there is also delivered to the virtual stick. A tap
  with no travel is zero deflection, so this should be invisible. If the player
  drifts while tapping the stamp, that is the cause.
- **The overlay's `peak` reads `n/a` on the phone.** Godot's web build never
  populates the audio bus peak monitor. `hum on 12.34s` next to it is the real
  signal: if that number is advancing, the mixer is running.
- **Desktop mouse does not drive the touch HUD.** `emulate_touch_from_mouse` is
  on, but Chromium's mobile emulation swallows synthetic mouse drags. Real touch
  works everywhere. Keyboard (WASD) works.
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

Run in order. The build stamp must match the commit that was deployed —
check that first, because everything else is meaningless if it does not.

**Load and shell**
1. Page loads black; title fades up; the hairline rule fills.
2. "TAP TO BEGIN" appears. Tap it — the game starts. (This tap is also what
   unlocks Web Audio for every later phase.)
3. The **top-left stamp** reads `v0.1.0 <sha>` and matches the deployed commit.
4. **Tap the stamp.** A "Build details copied." toast appears; paste it
   somewhere and confirm it names the branch, payload hash and user agent.

**Controls**
5. Left thumb anywhere on the left half raises a ring and knob where the thumb
   landed; dragging walks. Right thumb drags to look.
6. **Lift the left thumb while the right one is still dragging.** Looking must
   not stutter, jump, or stop. (This is the P1 input-hardening target; if it is
   already wrong here, say so.)
7. Walking into the crate stops you; you cannot leave the room.
8. Nothing sits under the Dynamic Island or the home indicator.
9. No rubber-band scroll, no double-tap zoom, no text selection, no page chrome.

**Instrumentation**
10. **Three-finger tap.** The overlay appears top-right. Read out `fps`, `cpu`,
    `draw`, `tris` — this is the only 60 fps measurement that means anything.
11. In the overlay: `safe` must be non-zero (the notch and home indicator),
    `dpr` should read 3, `store` should read `ok`, `sw` should read `active`
    after a reload.
12. Touch the screen with one finger, then two. The `touch` line must list the
    live touch IDs and clear when you lift.
13. **Audio.** Stand next to the lamp: a quiet mains hum. Walk away: it fades.
    In the overlay, `hum on N.NNs` must be **counting up**. Check with the
    silent switch both on and off, and note which one silences it.
14. Three-finger tap again — the overlay closes.

**The update path** (the part that decides whether I can ship you fixes)
15. Load the site, then leave the tab open.
16. Tell me, and I will push a rebuild. Wait for CI to go green.
17. Send the phone to the home screen and come back. A **"New version — tap to
    reload"** banner should appear at the top.
18. It must **not** appear while you are walking around with the tab in the
    foreground. If it does, that is a bug.
19. Tap it. The game reloads and the stamp shows the new commit.
20. **Break it deliberately:** append `?fresh=1` to the URL. The page purges and
    reloads onto the clean URL, and the game still loads. (You should not
    normally need this: a build that cannot load its payload purges itself.)

**Installed PWA**
21. Add to Home Screen. It launches full-screen, black, with the seam icon.
22. After one online run, put the phone in airplane mode and launch it again —
    it should still reach the tap gate.
23. In the overlay, `pwa` should read `true` when launched from the home screen.

**Errors**
24. If anything at all goes wrong, a toast should say what. If something goes
    wrong **silently**, that is itself the bug worth reporting.
