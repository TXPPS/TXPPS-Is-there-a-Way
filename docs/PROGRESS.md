# Progress

> Read this file and `ARCHITECTURE.md` first. They are written assuming you
> remember nothing about this project.

## Resume here

**Unattended run, and the game is finished.** The work order was A finish P1,
B write the story bible, C P2 rendering, D P3 audio, E Act 1 as a vertical
slice, F later acts only if credits remained. **All of it is done and live.
Four acts, twelve puzzles, twenty-two findable documents and two endings,
playable from the tap gate to either card.**

`tests/case_playthrough.gd` plays the whole thing in one run every build —
through the shelter door, up out of the annex with the reel, into the gallery,
and out one of the two ends — without ever calling `load_act`. It also stops
three acts in, throws every act away, reloads from the save, and finishes from
there, which is the version of "saves work" a player actually cares about.

**What that sentence does not mean.** Not one minute of it has been played by a
person. Everything here is green in CI and unverified by a human, and the parts
I am least able to judge are the parts that decide whether it works at all:

- whether the cam relationship in P3.1 is findable or merely fair-on-paper;
- whether P2.3's load budget reads as your own miscalculation or as the game
  being unfair;
- whether the handwriting on the box in Act 4 lands as the recognition the
  whole story is built toward, or goes past;
- whether either ending feels like a choice.

`NEEDS_DEVICE_QA.md` is a hundred and sixteen numbered items for exactly that
reason, and running it is the next thing that should happen. **It is worth more
than anything else that could be built on top of this.**

| | |
|---|---|
| **Live** | <https://txpps.github.io/TXPPS-Is-there-a-Way/> |
| **Stamp to expect** | `v0.1.0 0f1dcbd` (or later — every push deploys) |
| **First thing to do** | `docs/NEEDS_DEVICE_QA.md`, all 121 items, in order. Section "Controls" first: if that fails, stop, because everything else stands on it. |
| **Blocked on a human** | Everything unverifiable. Nothing is blocked on a decision. |
| **If you only do one thing** | Play it, once, on the phone, to an ending. Every number in this file is a number I checked; not one of them is an opinion about whether it is any good. |
| **Frozen** | The input layer. No change to touch semantics, layout or the router without a failing test to justify it. |

### What is true now that was not

- **Four acts are playable start to finish** — the powerhouse, the shelter, the
  annex and the gate — and `case_act1` through `case_act4` walk all of them every
  build, including up and down both stairs, which is the only way to know a ramp
  under the nosings is right.
- **The game ends**, two ways, and both endings are things the player does with
  equipment rather than options on a menu.
- **The entity exists and runs.** Protocol 4.2 — *the observer stands at the
  lamp* — is a line in a document the player can find, and it is the whole of
  `Observer`'s behaviour; `case_observer` asserts the bible's rule table row by
  row.
- **Every interactable is provably reachable.** `tests/case_reach.gd` works out
  where a player would have to stand for each of the sixty-six of them and asks
  the interactor what it can see from there. It has found more real bugs than
  every other case put together, and none of them was visible in a screenshot.
- The **story bible** exists (`STORY.md`), the puzzle set is derived from it
  (`PUZZLES.md`), and every puzzle device in the game traces to a line in the
  programme's equipment schedule.
- **Both P0 render defects are fixed**, the post stack is built, and
  `docs/shots/` is a committed gallery of what it looks like.
- **Everything the game hears is generated** by a committed script, and the
  score follows one fear number.
- **Saves persist, and are read.** The autosave survives a tab being discarded
  and is picked up on the next boot, which for most of this project it was not:
  the whole system was complete, tested and decorative until an audit noticed
  nothing ever loaded it. It can also be exported as a text code, which on this
  platform is the only save the player really owns.

### Act 2, as built

Three gates that are one system, and every one of them is the correct end state
of the last thing Emil did — which is the act's subject, not its obstacle.

| | |
|---|---|
| **P2.1** | The set cranks and will not fire: the day tank is isolated, as it is after every monthly exercise. The service card says `DAY TANK ISOL` forty-seven times in his handwriting. |
| **P2.2** | It runs and the bus stays dead: the transfer switch is in `TEST`, which runs the engine without connecting it. |
| **P2.3** | The bus picks up and trips: 30 kW does not carry 38.4 kW. Shedding the biggest single load gets under the rating — and nine seconds later the sump's float calls, the start surge asks for 48.5 kW, and the bus goes down again. 73 of the 128 allocations work, so it is a budget to spend, not one answer. |
| **P2.4** | The intercom. Twenty-four seconds after the bus comes up, Emil says four sentences, none of them a question. He is not answering anything and cannot be answered. |

It ends with the annex door found already open, and one vertical seam of light
in a corridor already walked. Once. No sound, no consequence.

### Act 3, as built

Four gates and one loop back into Act 2, in rooms behind the shelter's annex
door — not an act of its own, because P3.3's whole thesis needs the same panel
and a real walk (D28).

| | |
|---|---|
| **P3.1** | Chamber B's interlock will not release its key while the chamber's lamp is on. Set the cam timeclock so the lamp is dark in the current window. The relationship — tooth n covers hours 2n and 2n+1 — is written once, in Emil's handwriting, with a worked example. Opening the chamber breaker at the panel is a second, honest route, and it costs every chamber lamp. |
| **P3.2** | The photometer, in chamber B. It reads illuminance where you stand, and when something is between you and a lamp the reading drops by exactly what that lamp was worth. The same number every time, which is what makes it evidence. |
| **P3.3** | The tank room is flooded. Starting the sump against head needs 39.5 kW of headroom instead of 45, which the allocation that got you here cannot give. Go back to DP-2 and put something out: the annex bank, or the chamber lamps *and* the well. Shedding the bank leaves you blind and safe; shedding the chamber lamps leaves the corridor lit and the entity somewhere to walk. |
| **P3.4** | Four hundred reels in accession order. The index gives Run 9's block, the admission sheet's amendment gives the fortieth day, and the boxing rule gives the name. RF-0840 is Reel 9-C. |

**The entity runs here for the first time.** Not a threat with a health bar: a
rule, running, in a room with lamps in it. Protocol 4.2 — *the observer stands
at the lamp* — is its entire behaviour, and everything the bible's rule table
promises falls out of that one placement.

Act 3 ends with the reel in hand, and that is the edge of what is built.

### Act 4, as built

Rooms added to Act 1's scene rather than an act of their own, because two of its
three gates are in Act 1's gallery and belong there (D29). Getting here means
walking back down through the shelter and out the way you came in.

| | |
|---|---|
| **P4.1** | The 1954 relay panel in the gallery. The stage repeater reads 30.5 ft; the sequence card you could read in minute four says the sequence holds above 30.0. Nothing to do but understand it. |
| **P4.2** | The box on the shelf beside it, feeding the repeater. The gauge is not broken and is not lying — it repeats, faithfully, a number somebody is fabricating. The label is in the same hand as `WATCH THE THIRD STEP`, four hours and one whole act earlier. |
| **P4.3** | Pulling the lead does not open anything: a latch that has stopped being fed a reason to hold is still latched. Latches reset at a desk, with a key that is captive until Protocol 4.4 is satisfied — and Protocol 4.4 says a run is not concluded until the observer leaves the lamp. |

**Both endings are things the player does with equipment.** Conclude the run:
stand at the lamp, let the seam close, and the cabinet reads the channel as
concluded. Or refuse, walk out to the pier, and take the tainter gate off its
permissive by hand — which any engineer can do, because a 1954 dam had to be
operable with the control house dead.

Neither card says which was right. Both itemise what it cost.

### What the audits found

With the game finished, I stopped adding and started asking different questions
about what was already there. Eleven real defects in a few hours, every one of
them green in CI the whole time, because in each case what was missing was a
*connection* — and a test written from the same understanding that built a thing
makes the same assumption it does.

The questions that worked, roughly in order of yield:

1. **Does anything use this?** Signals with no listeners, classes with no
   references, settings with no consumers. Found the autosave nobody read, three
   acts with no reverb, a puzzle with no answer in it, and the largest
   contribution to the fear number being fed by nothing at all.
2. **Where else is this true?** A budget asserted in one room of four acts. A
   layout rule followed in Act 1 and abandoned afterwards. A door height right
   in one scene and wrong in another.
3. **What could a player do that nobody meant them to?** An ending reachable on
   arrival, a central puzzle you could walk around, a reload timed to land in
   the wrong building.
4. **Do the two copies agree?** Every puzzle is a fact written in a document and
   again as a constant. Nothing had ever compared them.

Each question is now a test, so each answer stays answered.

A fifth pass, after those four, found **nothing** — and that is the useful part
of the record, so it is here rather than omitted. It asked three questions:

- **Is anything shipping that should not be?** The export's exclude filter
  covers `tools/`, `tests/`, `docs/`, `web/` and the build directories; the
  payload is a 2.4 MB pck beside the engine wasm. Clean.
- **What happens to a touch the browser never ends?** The failure that would
  make the game unplayable on a phone. It is handled a layer below this
  project — the engine binds `touchcancel` to the same release path as
  `touchend`. Written up as D30, because the instinct is to fix it in the
  router and the router is frozen.
- **Is the QA checklist ordered so a partial pass still catches the worst?**
  It already leads with the frozen-input warning and says to stop if Controls
  fails.

Four passes found eleven defects; the fifth found none. That is the signal to
stop auditing, not to ask a sixth question — the remaining unknowns are the ones
that need a thumb on glass, and they are all in `NEEDS_DEVICE_QA.md`.

### What an audit for dead wiring found

Late in the run, with the game finished, I swept for things that were built and
never connected — signals nobody listens to, classes nobody instantiates,
settings nothing reads. It found three real defects in an hour, all of which
had been green in CI the whole time:

1. **Ending A could not be reached.** It had a card, a test and a name, and
   nothing in the game ever called it — the test got there through a private
   method, which is exactly the shape of a thing that looks finished and is not.
2. **Ending B could be reached immediately**, on arrival, skipping both of Act
   4's other gates and offering a refusal before there was anything to refuse.
3. **P3.3 was optional.** The tank room's flood is not solid (you have to wade
   to the drain valve), so the player could wade straight through to the tape
   library and never meet the puzzle the act is built around.
4. **The draw-call budget was blown thirty-four times over** in three acts, and
   reported green on every build, because it was asserted in one room.
5. **The autosave was never read.** Versioned, migrated, persistence-checked,
   tested, and written at every checkpoint — and nothing ever loaded it. Close
   the tab in Act 3, reopen the URL, start at the panel in the dark. Every hour
   spent on save schema was buying a file nobody opened.
6. **A puzzle with no answer.** Act 1 still carried the throwaway dial lock: a
   combination lock with no combination anywhere in the fiction, whose `solved`
   signal went nowhere. A player would have worked at it and got silence.
7. **Three acts with no reverb.** Act 1 got two zones when the system was
   written; nothing built afterwards got any, so twelve rooms were played dry in
   a game whose sound design is about knowing where you are without looking.
8. **Most of the documents were tables.** `STORY.md` has said since Act 1 that
   no document may depend on column alignment — one proportional font, no
   licensed monospace — and then the panel schedule P2.3 turns on, the log P3.2
   turns on, the index P3.4 turns on and six others were written as columns
   anyway. So were two Act 1 documents that predate the rule.
9. **Reload at the wrong moment, wake up in the wrong building.** `ActEnd`
   cannot free the act it is standing in, so its swap waits a frame — and a
   save loaded inside that window lost to the queued request.
10. **Three doors half underground.** A `DeviceDoor`'s leaf is centred on its own
   node; all three in the shelter sat at floor level, shut enough to stop a body
   and not a ray, and visibly sunk into the concrete.

None of them could fail a test, because in each case the thing that was missing
was the *connection*.

**The one that should worry a reader most** is the draw-call budget: it was
asserted on every build, reported green for weeks, and was wrong by a factor of
thirty-four in three of the four acts. A green tick is only as good as the place
it was measured.

Worth repeating on anything built over a long stretch, and worth doing before
adding more.

### Systems before rooms, which is worth doing again

Act 3 needed three things that did not exist: a second grade and a fluorescent
fitting, an entity that behaves rather than a motif that appears, and a tool the
player carries between rooms. All three were built and tested **before** a single
annex wall went up, and each landed in the level unchanged.

That is not tidiness. Each of the three is needed by every act that remains, and
an act designed around an unproven system is an act that gets rebuilt. It also
meant the entity's rule table could be asserted row by row in an empty fixture,
where a failure names the rule instead of the room.

Act 4 should be approached the same way: the held permissive and the selsyn
bench unit first, then the piers.

**Engine:** Godot 4.6.3-stable, Compatibility (WebGL2), single-threaded web export.
**Target:** iPhone 16 Pro Max, Safari, **landscape**.

---

## Deploy state — exact

# **Live: <https://txpps.github.io/TXPPS-Is-there-a-Way/>**

| | Status |
|---|---|
| Build | **green.** Export, budgets (download, texture size, shipped audio), the import-settings check, a **639-check headless suite**, 55-check gameplay smoke, 28-check update-path smoke, and a thirty-five-frame walk of every space in the game that costs each frame and uploads the gallery. |
| Last verified | `v0.1.0 0f1dcbd`, serving from GitHub Pages with every payload file answering 200 and the wasm as `application/wasm`. A recorded stamp can only ever name the commit *before* the one that records it, so if `main` is a doc-only commit or two ahead of this, that is why: those redeploy an identical game payload. CI asserts the live stamp matches `main` on every push, which is the check that does not go stale. |
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
- **Two scenes, four acts.** `powerhouse.tscn` carries Act 1 and Act 4 (D29);
  `shelter.tscn` carries Act 2 and Act 3 (D28). `ActRunner` mounts exactly one
  at a time and remembers the one it puts down, so travel is two-way and the
  breakers you threw an hour ago are still thrown.
- **Twenty rooms** on a 0.5 m grid, built from their dimensions by `RoomBox`
  rather than placed by hand, two of them generated by Python scripts that are
  committed and re-runnable.
- **Sixty-six interactables**, every one of which `case_reach.gd` proves a
  player can stand in front of and use.
- **Twelve puzzles**, twenty-two findable documents, one instrument, one entity
  and two endings.
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
  thing engaged with. The throwaway dial lock it was built against is gone — it
  was a combination lock with no combination anywhere in the fiction whose
  `solved` signal went nowhere — and its test runs against the annex timeclock,
  which is what `PUZZLES.md` always said would replace it. Seven device types
  use it — toggle, push, door, valve,
  selector, interlock and gauge — plus the timeclock and the photometer.
- **A tool the player carries.** `Hands` holds one thing by reparenting it under
  the camera, so it crosses an act boundary with no special case at all.
- **The entity.** `Observer` is Protocol 4.2 and nothing else: it stands between
  a lit fixture and the player, approaches along that line, and breaks when they
  step off it. Never shown, no collider, no sound of its own.
- **Documents can be read twice** — the pause menu lists what has been found and
  opens it in the same reader the world uses.
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

- **Three frames run 6–14% over the draw-call target.** 128, 135 and 137
  against a target of 120, all of them in the annex's eighteen-metre
  observation corridor. It was 4086 before the fix (`BUDGETS.md` has the whole
  story); 120 is a target chosen for a phone without a phone in the room, so
  whether 137 matters is a question only the device can answer. **QA item: watch
  the frame rate in the annex corridor.**

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
