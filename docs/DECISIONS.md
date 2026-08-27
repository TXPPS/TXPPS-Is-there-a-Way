# Decisions

Settled calls, with the reasoning, so they are not relitigated every session.
Open questions live in `PROGRESS.md`.

---

## D1 — Orientation: **landscape**

The control scheme is inherently two-thumbed: a floating stick under the left
thumb, drag-to-look under the right. In portrait on a 6.9" display those two
comfortable thumb arcs overlap in the lower third of the screen — the same
third the player needs to see through. Landscape separates them completely and
puts both at the bottom corners, where they rest naturally when the phone is
held in two hands.

The framing argument is stronger still. First-person horror is a horizontal
medium: a corridor receding, a silhouette entering at the edge, negative space
to the sides that the player has to choose to look into. Portrait crops away
exactly the information the genre is built on, and forces either a punishing
vertical FOV or a fisheye that reads as cheap.

Consequences, all handled:
- The manifest requests `orientation: landscape`; iOS Safari does not honour a
  web orientation lock, so `web/shell.html` shows a rotate overlay in portrait
  and the tap gate tells the player to turn on rotate lock.
- In landscape the Dynamic Island is on a short edge, so `env(safe-area-inset-left/right)`
  matter as much as top and bottom. The shell bridges all four to the HUD.
- `display/window/handheld/orientation=0` (Landscape) in `project.godot`.

## D2 — Premise: **the seed premise stands**

The lock-and-dam premise is kept, not replaced. It earns its keep on three
counts that a horror premise usually fails:

1. **The protagonist has a professional reason to be in every room.** A
   structural auditor certifying a complex for demolition is *supposed* to open
   panels, read gauges, and go below grade. There is no "why would you go down
   there" problem, which is the most common plot hole in the genre.
2. **The antagonist's method is the environment.** An automated flood-response
   sequence triggered by a spoofed river gauge is a lock that a competent person
   can reason about, which means the puzzles can be diegetic and mechanical —
   power routing, hydraulics, pressure — rather than bolted on.
3. **The title is diegetic.** "Is there a way?" as the last audible line on the
   final program tape reframes the whole game on the last document you find.
   That is a real ending, not a twist.

Three sharpenings to carry into P4 rather than changes:
- The antagonist believing he is being kind must be legible *early*, in the
  state of the rooms — food staged for one person, a bunk kept made, hazards
  fixed rather than ignored. If his kindness only lands in the final tape it is
  a reveal; if it accretes, it is dread.
- The sensory-deprivation programme needs a specific, checkable purpose, not
  "1970s experiments". P4 must name the funding line and what it was measuring,
  because the puzzles will be built out of the equipment it left behind.
- The player must be able to *learn* the entity's rules, so the rules have to
  come from the programme's methodology. What the facility did to people is what
  the entity now does. That is the connective tissue between story and mechanic.

Full bible, timeline and plot-hole audit are P4 deliverables.

## D3 — Art direction: **darkness is the budget**

Summarised here; the working document is `ART_BIBLE.md`.

The failure mode being explicitly rejected: blocky voxel-ish geometry, default
Godot materials, flat grey boxes, and the purple-teal gradient that marks a
first-time horror project.

The approach that WebGL2 actually rewards is the one 1970s cinematography
already used: light almost nothing, and light it from a source you can see. Small
pools of practical light — flashlight cone, sodium bulkhead lamps, emergency
strobes — with hard falloff into black. Silhouette and negative space carry the
frame. Low polygon counts become invisible inside shadow, so the triangle budget
goes to chamfered edges on the few objects that are actually lit.

Where the money goes instead:
- A committed post-process stack as one fullscreen shader: filmic tonemap,
  hand-authored LUT grade, edge chromatic aberration and barrel distortion,
  anisotropic grain that breathes with the fear state, ordered dither in the
  shadows, bloom on practicals only, optional period vignette. Every parameter
  drivable from gameplay.
- Procedural PBR materials from committed generator scripts plus shader detail,
  triplanar-mapped for large surfaces: wet concrete, oxidised steel, flaking
  marine paint, river silt, mineral staining, condensation. Real normal and
  roughness variation; never a flat albedo.
- A modular kit on a 0.5 m grid — concrete forms, catwalk grating, pipe runs,
  bulkhead doors, valve assemblies — with chamfered edges, because sharp
  untreated edges are the tell of an engine demo.

This is affordable precisely because of D4: shaders cost kilobytes.

## D4 — Rendering at CSS resolution, not 3×

`display/window/dpi/allow_hidpi=false`. The phone would otherwise render
2868×1320 instead of 956×440 — nine times the pixels. For an art direction built
on grain, dither and darkness, native resolution buys almost nothing and costs
almost everything. Revisit only if P7 finds headroom.

## D5 — Godot's PWA generation, our HTML shell

Godot generates the manifest and service worker because it knows the exported
file names; hand-maintaining that list would rot. Everything the player sees is
ours: `web/shell.html` replaces the default page completely.

`progressive_web_app/ensure_cross_origin_isolation_headers` stays **false**. That
option exists to enable `SharedArrayBuffer` via service-worker-injected COOP/COEP
headers. We are single-threaded by constraint, so it would add a hard hosting
requirement in exchange for nothing. `tools/ci/postprocess_web.py` fails the
build if either that flag or thread support ever flips.

## D6 — Content-hashed payload

`index.wasm` → `index.<sha>.wasm`, and the same for the loader, pack and audio
worklets, with every reference rewritten. This is what makes
`Cache-Control: immutable` correct rather than dangerous: a returning player
cannot be served last week's engine, and `index.html` plus the service worker
stay `no-cache` and decide which build is live.

## D7 — Node tooling lives outside the Godot project tree

`tools/.gdignore` keeps `tools/web/node_modules` out of the resource scanner.
Without it Godot imported the entire dependency tree into the game data pack and
the `.pck` went from 74 KB to 25 MB. The build script also fences the output
directory for the same reason.
