@tool
class_name RenderTuning
extends Resource

## Every number in the post stack, in one editable place.
##
## Split from `ART_BIBLE.md`'s prose so the prose stays the intent and this
## stays the settings. Nothing in `post_stack.gd` may hard-code a value that
## belongs here.

@export_group("Lens")
## Edge-weighted barrel. The centre of the frame is untouched.
@export_range(0.0, 0.2, 0.001) var barrel: float = 0.045
@export_range(0.0, 0.02, 0.0001) var chroma: float = 0.0035

@export_group("Bloom")
## High, so only the practicals bloom. A bloom that catches concrete turns the
## dark grey, and the dark is the whole budget.
@export_range(0.0, 2.0, 0.01) var bloom_threshold: float = 0.78
@export_range(0.0, 2.0, 0.01) var bloom_strength: float = 0.55
@export var bloom_tint: Color = Color(1.0, 0.78, 0.52)

@export_group("Grade")
@export_range(0.0, 1.0, 0.01) var lut_amount: float = 1.0

@export_group("Grain")
## At rest.
@export_range(0.0, 0.25, 0.001) var grain_calm: float = 0.028
## At `fear` = 1.
@export_range(0.0, 0.25, 0.001) var grain_afraid: float = 0.085
## 1 is round grain. Fear stretches it horizontally.
@export_range(1.0, 8.0, 0.1) var anisotropy_calm: float = 1.0
@export_range(1.0, 8.0, 0.1) var anisotropy_afraid: float = 3.4
@export_range(0.0, 60.0, 1.0) var grain_speed: float = 24.0
## What `reduce motion` leaves of the grain. Not zero: grain is also what hides
## the banding that dither does not reach.
@export_range(0.0, 1.0, 0.01) var grain_reduced: float = 0.4

@export_group("Shadows")
## In eighths of a display LSB. This is the fix for the P0 banding.
@export_range(0.0, 4.0, 0.05) var dither: float = 1.0
## Luminance above which dithering stops and grain takes over.
@export_range(0.0, 1.0, 0.01) var dither_ceiling: float = 0.35

@export_group("Vignette")
## Off by default; on for tape playback.
@export_range(0.0, 1.0, 0.01) var vignette: float = 0.0
