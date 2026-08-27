@tool
class_name SurfaceType
extends Resource

## What a floor sounds and feels like underfoot.
##
## P1 ships this silent: the player emits footstep events carrying a SurfaceType
## and nothing listens yet. P3 hooks the audio generator to `footstep_bus` and
## the entity's hearing model to `loudness`. Defining the interface now means P3
## adds a listener rather than rewriting the controller.

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
