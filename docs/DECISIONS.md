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

## D8 — Fixed twin sticks, with drag-look kept whole

Device QA killed the floating stick. It planted its origin wherever a touch-down
landed, which is the point of a floating stick — but *any* touch-down re-planted
it, including the ones iOS re-issues after cancelling a gesture mid-drag, and
the base appeared to slide across the screen with the thumb. A fixed base is not
a workaround for that; it removes the mechanism. `VirtualStick` no longer has a
line that writes its own position, and `HudLayout` is the only thing that does.

The default is now two fixed sticks: left walks, right turns. The right stick is
**rate-based** — deflection maps to angular velocity, not to a position — with a
response curve so small deflections stay precise, separate X and Y sensitivity,
and a hard ceiling on turn rate that no combination of sliders can exceed.

Drag-look is kept whole behind *Look style*, not deprecated. It is the more
precise of the two and there is a real chance of switching back to it; a code
path that is one setting away stays honest, while one that is commented out
stops compiling within a month. Both styles end at the same two methods on
`Player`, so neither can drift.

## D9 — Never read `InputEventScreenDrag.relative`

Godot 4.6's web display server keys its previous-touch-position table by the
touch's slot in the DOM event's `changedTouches` list, not by the touch
identifier it stamps on the event it emits
(`platform/web/display_server_web.cpp:748`). With one finger the two agree. With
two they do not, and every move event for the second thumb reports travel
measured from wherever the first thumb last was.

That is an engine bug, upstream of anything in this repository, and the fix here
is not to wait for it: `TouchRouter` derives every delta from `position`, keyed
by touch index. The field is never read. `tests/case_input.gd` sets it to ±9999
and asserts nothing moves, so if someone reaches for it later the suite says so.

## D10 — Two save slots, and a text code as the real one

**Decided:** one autosave and one player-written save, plus an exportable text
code. **Alternatives:** several numbered slots; a save browser; no code at all.

Slots are cheap to add later and expensive to take away, so the reversible
choice is the small one. The code is not a power-user feature and is not
optional: Safari evicts storage for a site nobody has added to their home screen
after roughly a week idle, so on this platform the only save the player really
owns is one they can hold in a message to themselves. Cost to reverse: low —
adding slots is a key prefix and a list.

## D11 — Version 0 means "no version field"

**Decided:** the schema is at version 1, and `migrate()` treats a save with no
version field as version 0 and has a real step for it. **Alternatives:** ship at
version 1 with an empty migration table and a comment promising to fill it in;
invent a version 0 that never existed to have something to migrate from.

An empty migration table is a mechanism nobody has run, and the first person to
need it discovers its bugs while holding a player's only save. Version 0 is not
invented: a hand-edited or hand-written code genuinely has no version field, and
import is a door it can come through. So the table has one entry, that entry is
real, and the suite exercises it. Cost to reverse: nil.

## D12 — Text entry goes through the browser, not through Godot

**Decided:** importing a save code uses `window.prompt()` via the shell.
**Alternatives:** a Godot `LineEdit`; an on-canvas keyboard.

Raising the iOS keyboard from a canvas needs `html/experimental_virtual_keyboard`,
which is experimental and would have to be verified on a device this session
cannot reach. `prompt()` is drawn by Safari, always works, and needs nothing
enabled. It is ugly. Cost to reverse: low, and the call site is one function.

## D13 — The Add-to-Home-Screen offer is gated on the user agent

**Decided:** the offer fires when the UA says iOS, or when `navigator.standalone`
exists. **Alternatives:** gate only on `navigator.standalone`, which is the
precise Safari-only signal.

The precise signal is untestable: Chromium does not define it even under an
iPhone user agent, so gating on it alone meant the feature could never be
exercised by the suite — and an unexercised one-shot that writes a flag is a
feature that fails silently forever the first time it breaks. The advice names
an iOS menu, so a UA check is not a heuristic here, it is the actual condition.
Cost to reverse: one line.

## D14 — The flashlight is not a light the entity can use

**Decided:** the auditor's four-cell is navigation, not danger. The entity
travels only between **fixtures** — the schedule luminaires and the plant
lighting — never along the player's own beam. **Alternatives:** make the torch a
liability, so carrying light is always a risk; make it a helmet lamp with no
management at all.

Making the torch a liability sounds like better horror and is worse design: the
player would simply never turn it on, and a game whose optimal play is walking
in the dark is a game nobody can see. It also collapses `P2.3` and `P3.3`, which
are the spine of the puzzle set — "you must put out a lamp to make progress"
means nothing if you carry one.

The distinction is derivable rather than arbitrary, which is the point.
Protocol 4.1: *the chamber shall be dark except for the schedule luminaire.* The
observer's position is defined relative to a luminaire on a schedule. A hand
torch is not one. Cost to reverse: moderate — it would change how every space is
lit, so if it is going to change it should change before P5 dresses Act 1.

**Also decided: no battery attrition.** A four-cell alkaline lamp in 1998 runs
for hours; draining it would be invented scarcity, and the scarcity this game
actually has is generated fixture light, which is finite for a reason the player
can read off a nameplate. Cost to reverse: one number.

## D15 — Fear is one number, assembled from three

**Decided:** consumers (the score, the grain, the post stack) read a single
`fear` float, 0..1. It is computed from three named contributions — **exposure**
(how much of you is on a lamp line), **proximity** (how near the nearest seam
has been, decaying), and **dark_time** (how long since you last stood in light)
— which are separately tunable but are summed before anyone sees them.
**Alternatives:** a three-component vector all the way to the consumers; a
single opaque scalar with no internal structure.

A vector at the interface is three times as many things to tune, and this
session cannot evaluate *any* of it: swiftshader cannot tell me whether a grain
response feels right and a headless runner has no ears. Tuning three curves
blind is exactly the gold-plating rule 7 warns about. One number with named
contributions gets the same expressiveness where it matters — in the
computation — and can be split later without touching a consumer, because the
consumers were never given more than a float to begin with.

Cost to reverse: low. Splitting it is adding two more properties beside one that
already exists.

## D16 — The story is set in March 1998

**Decided:** the present is 1998, not the present day. **Alternatives:** now;
unspecified.

Three problems solve themselves at once. A mobile phone in the protagonist's
pocket ends the game in the first four minutes, and "no signal" is the tiredest
line in the genre; in 1998 the radio is on the truck's tailgate charger because
that is where a field engineer leaves it while doing the exterior survey. A
programme that closed in 1977 is twenty-one years past, which is close enough
that its technician is sixty and still fit to maintain a plant, and close enough
that the hardware still runs. And the entire document set — reel-to-reel tape,
chart recorders, selsyn repeaters, pencil logbooks — is period-correct rather
than nostalgic set dressing.

Cost to reverse: high, and rising. Every document, every piece of equipment and
the whole plot-hole audit rest on it. This is the one decision in this run that
would be genuinely expensive to undo, which is why it is written down with its
reasons rather than assumed.
