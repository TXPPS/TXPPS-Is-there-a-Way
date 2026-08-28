# Puzzles

> Derived from `STORY.md`. Every mechanism here traces to a line in the
> programme's equipment schedule (Appendix C) or to plant that a 1937 lock and
> dam genuinely has. Nothing is an abstract minigame in a horror skin, and
> nothing exists because a door needed something in front of it.
>
> The test each puzzle has to pass: **an engineer looking at the real object
> would try the thing the puzzle wants.**

---

> **Status: all twelve are built and walked by the suite.** `case_act1` through
> `case_act4` play every one of them, including the wrong answers that are meant
> to be interesting — the allocation that boots and then dies when the sump
> starts, and the chamber lamps shed alone. None of it has been played by a
> person; see `NEEDS_DEVICE_QA.md`.

## The grammar

Four verbs, learned in Act 1 and never added to. A game that teaches a new verb
in Act 3 is a game that has run out of ideas about Act 1's verbs.

| Verb | What it is | Where it is taught |
|---|---|---|
| **Read** | A nameplate, a panel schedule, a service tag, a card. Every solution is written on the equipment. | P1.1 |
| **Isolate** | Open a breaker, pull a fuse, shut a valve, dog a door. Making something safe is how you make it passable. | P1.1 |
| **Route** | Decide where a finite thing goes: current, water, light. | P2.3 |
| **Set** | Put a mechanism into a state and leave it there: a cam drum, a transfer switch, a schedule. | P3.1 |

Focused interaction (`ARCHITECTURE.md`) is the only input the puzzles use: a
centre-screen ray finds the device, one button engages it, and gestures go to it
until you step back. No inventory beyond what an auditor walked in carrying.

---

## Dependency graph

```
ACT 1  P1.1 emergency lighting
         ├─> P1.2 switchgear interlock
         │     └─> P1.4 gallery watertight door
         │            └─> P1.5 the admit call ──────────┐
         └─> (P1.3 the third step: hazard, not a gate)  │
                                                        v
ACT 2                                          P2.1 start the generator
                                                        │
                                               P2.2 transfer switch
                                                        │
                                               P2.3 shed the load  <────┐
                                                        │               │
                                               (P2.4 the intercom)      │
                                                        v               │
ACT 3                                          P3.1 the timeclock       │
                                                   ├─> P3.2 photometer  │
                                                   └─> P3.3 drain ──────┘
                                                            │  (re-routes P2.3)
                                                            v
                                                       P3.4 reel index
                                                            │
ACT 4                                                       v
                                                       P4.1 the held permissive
                                                            │
                                                       P4.2 the selsyn box
                                                            │
                                                       P4.3 the control house
                                                          /     \
                                                   ENDING A     ENDING B
```

**P3.3 loops back into P2.3.** That is deliberate and is the spine of the game:
the power you restored in Act 2 is not enough for everything at once, so the way
forward in Act 3 is to *take a light away*.

---

## Act 1 — The Powerhouse

The vertical slice. Four gates, one hazard, one scene. No entity, no seam,
nothing supernatural: the player is establishing that they are good at this
building.

### P1.1 — Emergency lighting

| | |
|---|---|
| **Verb** | Read, Isolate |
| **Equipment** | 125 V DC station battery and its distribution panel — standard powerhouse plant, not programme equipment |
| **Problem** | The sequence dropped the AC bus. Emergency lighting is on the station battery and is dead too: the lighting breaker trips the moment it is closed. |
| **Mechanism** | A circuit is faulted. Closing the main does nothing until the faulted circuit is out of the picture. Pull the fuse for the faulted circuit at the panel, then close the breaker. |
| **In-world information** | The **panel schedule card** behind the door: eight circuits, named, with their areas. One circuit — `LT-6 STAIR TWR` — is the one that trips. The stair tower is where the frayed conduit is, and the player will walk past Emil's tape on it three minutes later. |
| **Justification** | This is what an electrician does with a tripping breaker, in the order they do it. |
| **Failure mode** | Closing the breaker with everything in: it trips, audibly, and stays tripped for ten seconds. Nothing is lost. The game's first lesson is that trying the wrong thing is safe. |
| **Depends on** | — |
| **Teaches** | The label on the equipment is the solution. |

### P1.2 — The switchgear interlock

| | |
|---|---|
| **Verb** | Read, Isolate |
| **Equipment** | Kirk-key interlock on the 4160 V switchgear room door — 1954 plant |
| **Problem** | The switchgear room is shut. It is not locked; it is *interlocked*, and the interlock will not release its key while the bus could be live. |
| **Mechanism** | Open the bus main at the DC panel. The interlock releases the key. The key opens the door. |
| **In-world information** | The interlock's own brass plate: `KEY RELEASED WITH BREAKER OPEN`. `D-04`, the laminated sequence card, for what the bus is. |
| **Justification** | Captive-key interlocks exist so nobody opens a door onto live 4160 V. The safety feature and the obstacle are the same object, which is the most honest kind of puzzle a plant can offer. |
| **Depends on** | P1.1 (you cannot read a panel schedule in the dark) |
| **Teaches** | A door can be shut for a reason that is about electricity, not about you. |

### P1.3 — The third step *(hazard, not a gate)*

The stair tower's third step is broken through. There is a hand-lettered card —
`WATCH THE THIRD STEP` — in engineer's capitals, and the frayed conduit beside
it has been taped, neatly, with tape that is not forty years old.

No mechanism. The player steps over it. It is the first S1 beat and the first
thing in the game that is wrong.

### P1.4 — The gallery watertight door

| | |
|---|---|
| **Verb** | Isolate |
| **Equipment** | Eight-dog watertight door between the powerhouse and the gallery — 1937 plant |
| **Problem** | Seven dogs free by hand. The eighth is seized. |
| **Mechanism** | The dog wrench is on its hook beside the door, where it belongs, because somebody put it back. Engage and lever. |
| **In-world information** | The door's instruction plate (`UNDOG IN SEQUENCE — OPPOSITE PAIRS`) and the hook, which is labelled and occupied. |
| **Justification** | Watertight doors are dogged. Wrenches live on hooks. A seized dog is what forty years of river damp does. |
| **Depends on** | P1.2 (the switchgear room is the way through) |
| **Teaches** | Some problems are mechanical and take a tool that is exactly where it should be. That the tool is *on its hook* is the second S1 beat. |

### P1.5 — The admit call

| | |
|---|---|
| **Verb** | Read |
| **Equipment** | Shelter admit bell — a 1962 civil-defense fitting, so wardens outside could ask to be let in |
| **Problem** | The blast door cannot be opened from outside. It was designed to be closed by one person from inside, and it has been. |
| **Mechanism** | Beside the door is a push and a sign. You press it. Somewhere below, a bell rings. After eleven seconds, the door opens. |
| **In-world information** | The sign, stencilled in 1962: `SHELTER — RING FOR ADMITTANCE`. |
| **Justification** | Community fallout shelters had them. A shelter with no way to ask to be let in is a shelter that kills the people it was built for. |
| **Depends on** | P1.4 |
| **Teaches** | Nothing mechanical. It is the act's last beat and the worst thing in it: **the player asks to be let in, and somebody says yes.** |

---

## Act 2 — The Shelter

Three gates that are one system: get the shelter's own plant carrying load. The
act is domestic and the horror is entirely in the housekeeping.

### P2.1 — Start the generator

| | |
|---|---|
| **Verb** | Read, Isolate |
| **Equipment** | **C-10** — 30 kW diesel and battery bank |
| **Problem** | It cranks and will not fire. |
| **Mechanism** | The day tank isolating valve is shut. It is shut because Emil shuts it after every monthly run, which is correct practice. Open it, prime, crank. |
| **In-world information** | **`D-09`**, the generator service card, forty-seven monthly entries in pencil, every one ending `DAY TANK ISOL`. The answer is in his handwriting, forty-seven times. |
| **Justification** | You isolate a day tank on a standby set. Fuel does not siphon into a stopped engine's gallery on its own. |
| **Depends on** | — |
| **Teaches** | Emil is not a ghost. He is a man with a maintenance routine, and reading it is how you get anywhere. |

### P2.2 — The transfer switch

| | |
|---|---|
| **Verb** | Set |
| **Equipment** | **C-10**'s manual transfer switch, three positions |
| **Problem** | The set runs. The bus stays dead. |
| **Mechanism** | The switch is in `TEST` — the position that runs the engine without connecting it, which is exactly where it would be left after a monthly exercise. Move it to `EMERGENCY`. |
| **In-world information** | The switch's plate: `NORMAL / TEST / EMERGENCY`, and the operating card taped inside the cabinet door. |
| **Justification** | Standby sets are exercised monthly under no load, in TEST. Leaving it there is the correct end state of the last thing Emil did. |
| **Depends on** | P2.1 |

### P2.3 — Shed the load ★

**The most important puzzle in the game.**

| | |
|---|---|
| **Verb** | Route |
| **Equipment** | **C-10** and the shelter distribution panel; the loads are **C-1** (the schedule luminaires), the sump, the annex lighting, and the shelter's own circuits |
| **Problem** | The bus picks up and trips within four seconds, every time. |
| **Mechanism** | 30 kW does not carry everything. The player opens breakers at the panel until the connected load fits, and the arithmetic is on the nameplates. There is not one correct answer — there is a budget, and the player spends it. |
| **In-world information** | The panel schedule, and the nameplate on every load: the sump is 7.5 hp (≈ 6.9 kW running, and it *starts* at four times that), the annex fluorescent bank is 4.4 kW, each chamber luminaire is 150 W on a dimmer that draws more than it gives. The generator's own plate says `30 KW 37.5 KVA 0.8 PF`. |
| **Justification** | This is generator sizing, and it is the single most ordinary calculation in building services. It is also the only puzzle in the game the player can get *wrong in an interesting way*: an allocation that boots is not necessarily an allocation that survives the sump starting. |
| **Depends on** | P2.2 |
| **Teaches** | **Light is finite and you choose where it goes.** Everything Act 3 does with the entity depends on the player having internalised this in a room where nothing is hunting them. |
| **Later** | P3.3 forces the player back to this panel to take a light *away*. |

### P2.4 — The intercom *(scene, not a gate)*

**Equipment: C-3**, the observer intercom, two channels, `TALK` and `MONITOR`.

The subject-side handset is in the mess, on the wall, where a 1964 retrofit
would have put it. When the bus comes up, the panel lamp lights.

At the scheduled hour — and it is genuinely on a schedule, and the player can
find the schedule — Emil speaks. Four sentences. He does not ask a question and
does not answer one, because Protocol 4.3 says the observer shall not speak
except on the schedule, and he has followed that line for thirty-four years.

---

## Act 3 — The Annex

Where the programme's equipment stops being scenery. Three gates, one tool, one
loop back into Act 2.

### P3.1 — The timeclock ★

**This replaced the throwaway dial demo, and the demo is gone.** Same
interaction grammar — numbered wheels turned with a thumb — with a reason to
exist. `tests/case_interact.gd`, which is the focused-interaction framework's
only test, now runs against this.

| | |
|---|---|
| **Verb** | Set |
| **Equipment** | **C-2** program timeclock (cam-driven, 24 h drum) and **C-7** door interlock cabinet |
| **Problem** | Chamber B is shut. Its interlock will not release its key while chamber B's luminaire circuit is energised — Protocol 4.4, made physical, so a run cannot be broken by somebody opening a door. |
| **Mechanism** | Set the drum so that chamber B's lamp is *off* in the current window. Three thumbwheels: hour, and two cam positions. The interlock releases. The key opens the door. |
| **In-world information** | **`D-16`**, Emil's cam-cutting notes from 1966 — a workman's sketch with tooth counts and a worked example — plus the drum's own engraved face. The notes give the relationship; the face gives the current state; the player does the rest. |
| **Justification** | Cam timeclocks drove lighting schedules for fifty years. Captive-key interlocks stop a door being opened at the wrong moment. Both are on the equipment schedule because the programme could not have run without them. |
| **Depends on** | P2.3 (no power, no interlock) |
| **Teaches** | The programme's own procedure is the lock, and following it correctly is how you get through. Which is Act 4's whole problem, stated early in a room where it is only inconvenient. |

### P3.2 — The photometer

| | |
|---|---|
| **Verb** | Read |
| **Equipment** | **C-6**, portable photometer, certified quarterly |
| **Problem** | None. It is a tool, found in chamber B, and it is the only instrument in the game. |
| **Mechanism** | Held up, it reads illuminance at the player's position. Pointed at a certified luminaire it reads what `D-18` says it should. Pointed at a **seam**, it reads a drop — and the drop is not noise, it is a number, and it is the same number every time. |
| **In-world information** | **`D-18`**, the certification log: forty-four quarterly entries, each giving the lamp, the distance and the expected lux. Emil signed every one. |
| **Justification** | You certify a luminaire with a photometer. A schedule made of light is worthless if the lamp drifts, so the programme had to own one and had to use it quarterly. |
| **Depends on** | P3.1 |
| **Teaches** | **The seam is real.** This is the game's one moment of instrumented proof, and it is deliberately the same idea as the debug overlay: on a device with no console, a number you can read beats a feeling you cannot. |

### P3.3 — Drain the tank room ★

| | |
|---|---|
| **Verb** | Route |
| **Equipment** | The shelter sump (on P2.3's panel) and **C-5**, the immersion tank, which by 1998 is a reservoir |
| **Problem** | The tank room is flooded to the sill. The tape library is past it. The sump will not start — starting it needs more than the remaining headroom on a 30 kW set. |
| **Mechanism** | Go back to P2.3's panel and take something off. The only load big enough to make room is the annex fluorescent bank, or two of the three chamber luminaires. **Progress costs light.** |
| **In-world information** | The same nameplates, plus the sump's starting current on its plate. Nothing new is introduced; the player is asked to use what Act 2 taught. |
| **Justification** | Motor starting current is why standby plants are sized the way they are. This is not a contrivance; it is the reason every building has a load schedule. |
| **Depends on** | P2.3, P3.1 |
| **Teaches** | The thesis. **To go forward you must put out a lamp, and in the dark you cannot see it coming — but neither can it come.** Every player solves this differently and every solution is a statement about how frightened they are. |

### P3.4 — The reel index

| | |
|---|---|
| **Verb** | Read |
| **Equipment** | **C-8**'s reel library, and **`D-19`**, the index |
| **Problem** | Four hundred reels. One of them is Run 9. |
| **Mechanism** | The library is filed by **station accession number**, because that is how a field station files things. The index is by **run and date**. The player translates: `D-20`, the Run 9 admission sheet, gives the dates; the index gives the accession; the shelf gives the reel. |
| **In-world information** | `D-19`, `D-20`, and the shelf labels. |
| **Justification** | Archives are filed by accession and indexed by subject. Anyone who has used one has done exactly this. |
| **Depends on** | P3.3 |
| **Teaches** | Nothing new. It is the last quiet act before Act 4, and it is deliberately clerical. |

---

## Act 4 — The Gate

Three gates and a choice. No new verbs.

### P4.1 — The held permissive

| | |
|---|---|
| **Verb** | Read |
| **Equipment** | The 1954 flood-response relay panel, in the gallery |
| **Problem** | The gate pier stair is a bulkhead of the same class as Act 1's stair tower. It will not release while the sequence is latched, and the sequence is latched while the stage reads over 30 ft. |
| **Mechanism** | None, yet. The player reads the panel, finds the stage input live and impossible, and follows the cable. |
| **In-world information** | **`D-04`**, the laminated sequence card, which the player has been able to read since minute four: *`SEQ HOLDS WHILE STAGE > 30.0 FT`*. |
| **Justification** | Flood sequences latch. A sequence that unlatched on a receding river would cycle the gates every spring. |
| **Depends on** | Act 3 complete (route) |

### P4.2 — The selsyn bench unit ★

| | |
|---|---|
| **Verb** | Isolate |
| **Equipment** | A homemade selsyn driver on a shelf in the gallery, feeding the stage repeater |
| **Problem** | The gauge is lying. The float in the stilling well is disconnected; the repeater is being driven by a box somebody built. |
| **Mechanism** | Disconnect it. The true stage — 21.4 ft — reaches the panel. The sequence stops being *fed* a reason to hold. It does **not** open: it is latched, and latches are reset deliberately, at the control house. |
| **In-world information** | **`D-21`**: the box's hand-lettered label, in the same engineer's capitals as `WATCH THE THIRD STEP`, four hours and one whole game earlier. |
| **Justification** | A selsyn repeater is how a 1954 dam gets a float gauge reading into a control house, and a bench unit that drives one is a week's work for a competent plant electrician. |
| **Depends on** | P4.1 |
| **Teaches** | **The building is not doing this.** This is the moment the player stops being afraid of the structure and starts being afraid of the person, and it lands as a recognition of handwriting. |

### P4.3 — The control house

| | |
|---|---|
| **Verb** | Set |
| **Equipment** | The 1954 control desk, and **C-7**'s third interlock channel — retrofitted into the control house in 1966, by Emil, so that a run could not be broken from the surface |
| **Problem** | The latch resets with a key. The key is captive in the interlock cabinet. The cabinet will not release it until the run is concluded, and **Protocol 4.4 says a run is not concluded until the observer leaves the lamp.** |
| **Mechanism** | Two ways out, and they are the endings. |
| **In-world information** | `D-13` (Protocol 4), which the player read in Act 3 and did not yet know was about the way out. |
| **Justification** | The programme's interlock scheme physically gates the exit because Emil wired it that way in 1966 to stop exactly this. Thirty-two years later it is doing its job. |
| **Depends on** | P4.2 |

---

## The endings, as mechanisms

Both are things the player *does* with equipment, not options on a menu.

### Ending A — Conclude the run

Set the last chamber luminaire live, stand on its line, and let the seam close
over you. The interlock cabinet reads the channel as concluded and releases the
key. Reset the latch. The bulkheads open at dawn.

**Cost:** you performed the programme's final observation on yourself.
**Kept:** Reel 9-C, in your jacket, dry.

### Ending B — Open the gate

Refuse. Go out to the gate pier and take the tainter gate off its permissive by
hand at the hydraulic power unit — which an engineer can do, because the gate is
designed to be operable when the control house is dead. The pool comes through
the structure.

**Cost:** the annex, the library, Reel 9-C, and Emil, who will not leave the lamp.
**Kept:** your own judgement, and nothing anyone will believe.

---

## What is deliberately not here

- **No keys hidden in drawers.** Every key in the game is captive in an
  interlock, on a labelled hook, or already on the player's ring.
- **No codes written on notes.** The one combination in the game (`P3.1`) is a
  cam relationship in a technician's working notes, and the player derives the
  setting rather than reading it.
- **No hidden objects.** Everything needed is in plain sight on the equipment it
  belongs to. The difficulty is understanding a plant, not spotting a pixel.
- **No timed sequences.** The rising water in the lower gallery is legible and
  slow and is a pressure, not a timer. Nothing in this game kills you for
  thinking.
- **No combat, no stealth meter, no chase.** The entity's only expression is the
  interruption of light, and the only counter-play is where you stand and which
  lamps you have chosen to energise.
