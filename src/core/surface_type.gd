@tool
class_name SurfaceType
extends Resource

## What a floor sounds and feels like underfoot.
##
## P1 shipped this silent. P3 wired it: `src/audio/footsteps.gd` reads `sounds`
## and `bus` and plays the generated variants; `loudness` is still waiting for
## P6's hearing model, which is the one field nothing reads yet.

## Stable identifier. Used as a dictionary key and in save data, so changing one
## is a migration, not a rename.
@export var id: StringName = &"concrete"

## Shown in authoring tools and debug overlays only. Never in the fiction.
@export var display_name: String = "Concrete"

@export_group("Footsteps")

## Linear gain applied to the generated footstep. 1.0 is the reference surface.
@export_range(0.0, 2.0, 0.01) var gain: float = 1.0

## Playback-rate multiplier. Grating rings higher than wet concrete.
@export_range(0.5, 2.0, 0.01) var pitch: float = 1.0

## Seconds of extra spacing between footfalls. Silt and standing water make the
## player instinctively slow down; this is how that reads without a cutscene.
@export_range(0.0, 0.5, 0.01) var stride_drag: float = 0.0

## How far the sound carries. P3's entity hearing model reads this; P6's stealth
## rules depend on it. 0 = silent, 1 = the whole level knows.
@export_range(0.0, 1.0, 0.01) var loudness: float = 0.6

## Which audio bus the footstep plays on. Named rather than referenced so the
## bus layout can change without touching every surface resource.
@export var bus: StringName = &"SFX"

## Basename of the generated footstep variants in assets/audio/, without the
## index: "step_concrete" finds step_concrete_1 .. step_concrete_N. Named rather
## than a list of paths, so adding a variant is regenerating and bumping a count.
@export var sounds: StringName = &"step_concrete"

@export_range(1, 8, 1) var variants: int = 3
