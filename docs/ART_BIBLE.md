# Art Bible

Status: **first pass, written in P0 to set direction.** P2 builds the lighting
and material test scene and this document is revised against screenshots.

---

## The thesis

Darkness is the budget. WebGL2 will not give us global illumination, screen-space
occlusion or volumetrics, so we do not pretend to have them. We light almost
nothing, we light it from a source the player can see, and we let the falloff go
to black. That is not a compromise: it is how the era this facility comes from
was actually photographed.

Everything that reads as expensive in this game is a shader, and shaders cost
kilobytes. See `BUDGETS.md` — there is ~30 MB gzipped of headroom for content,
and almost none of it should go to texture data.

## Lighting rules

1. **Every light has a fixture.** A pool of light with no visible source reads as
   an engine demo. If the player can see the lit floor, they can find the lamp.
2. **One dominant practical per space**, plus at most one motivated fill (a
   distant corridor, a panel LED, the flashlight). Never a lighting rig
   pretending to be ambient.
3. **Ambient is cold, dim, and lies about its origin.** A low blue-grey fill at
   0.3–0.5 energy stands in for bounce. Warm light comes only from a source.
4. **Falloff is hard.** Sodium lamps in wet concrete do not bloom gently across a
   room; they make a bright wall and a black one. Range and attenuation are
   tuned for contrast, not coverage.
5. **Shadows are a spend, not a default.** Positional shadows are enabled per
   light, deliberately, and counted against the draw budget.

   This was written in P0 and then not followed: every fitting shipped with
   shadows on, and a shadow-casting omni draws the scene once per cubemap face.
   Fifteen of them took the annex to 4086 draw calls against a budget of 120.
   Four fittings cast in the whole game now — the generator hall's dominant
   practical and the three schedule luminaires — and the rest are lights.

   The three that cast are not negotiable: the entity's only expression is the
   interruption of light, so it stands only at a lamp that casts. That is why
   C-1, the programme's own fitting, is the one it travels between.
6. **The dark must be navigable.** Ordered dither plus a floor of ambient keeps
   "unlit" from becoming "unreadable" — especially on a phone in daylight, which
   is the real viewing condition.

## Materials

Procedural PBR from committed generators (`tools/gen/`), plus shader detail,
triplanar-mapped on anything large enough that a UV seam would show.

The material vocabulary, in the order the game needs it:

| Material | What sells it |
|---|---|
| Wet concrete | broad roughness variation, darker where water pools, mineral bloom at the edges |
| Oxidised steel | metallic with roughness breakup, rust as a *mask* on roughness and albedo, never a decal |
| Flaking marine paint | two-layer: paint over primer over steel, edges lifted, chipping follows geometry |
| River silt | matte, near-zero specular, settles on upward faces and in corners |
| Mineral staining | vertical streaks that respect gravity, not the UV axis |
| Condensation | high-frequency normal detail, roughness near zero in droplets only |

Never a flat albedo. Never an untreated sharp edge: everything gets a chamfer,
because a chamfer is what catches a highlight and tells the eye the object is
made of something.

## Geometry

A modular kit on a **0.5 m grid**: concrete forms, catwalk grating, pipe runs,
bulkhead doors, valve assemblies. Consistent units so rooms can be assembled by
hand in the desktop editor later. The gray-box room in `src/world/graybox/`
already sits on this grid, so P2's kit drops into the same footprint.

Triangle budget goes to the objects that are actually lit. Anything living in
shadow can be a box.

## Palette

One coherent palette per act. Act 1 (powerhouse and upper shelter levels):

| Role | Colour | Where |
|---|---|---|
| Sodium practical | `#FFB054` → `#C26018` | bulkhead lamps, the game's only warm source |
| Wet concrete | `#32343A` … `#191B1E` | every large surface |
| Oxidised steel | `#26241F` … `#141312` | doors, rail, plant |
| Cold fill | `#1B2128` | the lie that stands in for bounce |
| Silt / stain | `#2E291F` | waterlines, corners, the low third of every wall |
| Emergency red | `#8E1F1A` | used at most twice in the act |
| True black | `#000000` | the majority of most frames |

Later acts shift the practical, not the concrete: the shelter levels move from
sodium to a sick fluorescent green-white, which is the visual marker that the
player has left the *dam* and entered the *programme*.

**Both grades are built.** `assets/luts/annex.png` is that shift, and it is
measured rather than eyeballed — at the top end, Act 1 runs red-minus-blue
`+0.080` with a green lead of `+0.017`; the annex runs `-0.018` and `+0.054`.
Cool instead of warm, with three times the green. Neither lifts true black.

The fitting that goes with it is `src/world/kit/fluorescent.tscn`: a four-foot
tube in a painted trough, wider and dimmer than the sodium bulkhead because a
tube is a line of light and Compatibility has no area lights. It runs the same
script — the script is the behaviour, the scene is the fitting — and the only
thing it adds is a stumble. A tired tube does not shimmer, it fails to strike
for a fraction of a second and recovers, which is why it is modelled as an
occasional dip rather than as noise on the brightness. Noise reads as a bad
shader; a dip reads as a bad tube.

**The annex palette has never been seen on a device**, and the room it is for
does not exist yet. It is verified numerically and by the suite, and nothing
more than that.

## Never do this

- Purple-and-teal gradient lighting. It is the genre's uniform and it is not ours.
- Default Godot materials or an untextured flat grey box in a shipping scene.
- A jump scare as the primary tool. Loud is not scary; anticipated is scary.
- Showing the entity in full. See below.
- Blocky voxel-scale geometry, or a chamfer-free edge on anything lit.
- A light with no fixture.
- Text on the icon or the title card. The image carries it.
- Coloured fog used as depth. Depth comes from light falloff and silhouette.

## The entity's motif

The entity is never fully shown, so it needs a signature the player learns to
read instead. The motif is **a vertical seam of light that should not be there.**

The game's icon is that image: a sealed bulkhead in the dark with one line of
sodium light escaping the join, crossed by the faint silt line of an old flood.
It is generated by `tools/gen/make_icons.py`, so the motif is literally a
committed script.

In play the motif appears as:
- a door that is very slightly ajar when the player knows it was sealed;
- a vertical highlight moving *across* a gap rather than along it;
- the interruption of a seam — the light goes out for the width of a body, and
  comes back.

The rule the player is meant to learn: **the entity is only ever between you and
a light.** That is what makes it visible at all, and it is why the facility's
power is both the win condition and the risk. It also comes straight out of the
programme's methodology, which is what D2 asks for — what the facility did to
people in the dark is what the entity now does with the light.

## Post-process stack — **built**

Built in P2. `src/render/post.gdshader` plus two stages that turned out to
belong to the engine. See `ARCHITECTURE.md`, "Rendering", for where each one
ended up and why; the list below is the intent, and the status is what happened.

One fullscreen shader, every parameter drivable from gameplay:

1. filmic tonemap
2. hand-authored LUT grade (per act)
3. bloom on practical sources only, thresholded high
4. chromatic aberration and barrel distortion, edge-weighted, subtle
5. anisotropic film grain whose intensity and anisotropy breathe with the fear state
6. ordered dither in the shadows — this is what kills the banding visible in the
   P0 screenshots
7. optional 1970s-camera vignette, off by default, on for tape playback

| # | Status |
|---|---|
| 1 filmic tonemap | **engine.** `WorldEnvironment`, the hardware path. Doing it twice makes the grade fight the curve. |
| 2 LUT grade | **built.** `tools/gen/make_lut.py` writes each grade as a function of the four numbers it turns on. Two exist: `act1` and `annex`. |
| 3 thresholded bloom | **engine.** `Environment.glow`. A hand-rolled version from the screen's mip chain produced no halo: Compatibility gives the backbuffer no mips. |
| 4 CA + barrel | **built**, edge-weighted, one lens. Off under `reduce motion`. |
| 5 anisotropic grain | **built**, breathing with the fear state. Softened, not removed, under `reduce motion` — it also hides banding the dither does not reach. |
| 6 ordered dither | **built.** 8×8 Bayer, computed not looked up, in the shadows only. This is the fix for the P0 banding. |
| 7 vignette | **built**, off by default, ready for tape playback. |

`reduce-motion` disables 4 and softens 5, as required. It deliberately does not
touch 6: that is legibility, not motion.

**Both P0 defects are fixed.** The lamp panel clipped to flat white because its
emissive sat above the filmic shoulder; it is 1.5 rather than 2.6 and the glow
does the work of making it read as bright. The banding in the falloff is the
dither. Both are visible in `docs/shots/`, and neither has been seen on a
phone.
