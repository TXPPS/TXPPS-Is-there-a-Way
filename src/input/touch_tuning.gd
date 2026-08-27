@tool
class_name TouchTuning
extends Resource

## Geometry and legibility of the on-screen touch controls. Separate from
## PlayerTuning because these are ergonomics (thumb reach, contrast) rather
## than character feel, and they get retuned whenever the HUD layout changes.

@export_group("Virtual Stick")

## Distance in pixels from the stick's origin to full deflection. Roughly the
## comfortable arc of a thumb resting on the lower-left of a 6.9" phone.
@export_range(40.0, 180.0, 1.0) var stick_radius: float = 92.0

## Radius of the moving knob.
@export_range(10.0, 70.0, 1.0) var knob_radius: float = 32.0

## Fraction of the radius ignored, so resting a thumb does not drift the player.
@export_range(0.0, 0.5, 0.01) var stick_deadzone: float = 0.09

## The controls should be visible enough to find and dim enough to disappear.
@export_range(0.05, 1.0, 0.01) var opacity: float = 0.30

@export var tint: Color = Color(0.86, 0.88, 0.92)

## Seconds for the stick to fade out after the thumb lifts.
@export_range(0.0, 1.0, 0.01) var fade_out_time: float = 0.18
