@tool
class_name TouchTuning
extends Resource

## How the on-screen controls *feel*, as opposed to where they sit (HudLayout).
##
## Everything here is a default. The player's settings override the handful of
## values that are exposed in the pause menu; the rest are authoring knobs.

@export_group("Response")

## Fraction of the radius ignored, so a thumb resting on the glass does not
## drift the player or the camera.
@export_range(0.0, 0.5, 0.01) var deadzone: float = 0.09

## Shapes deflection into output. 1.0 is linear; above 1.0 the first half of the
## travel is gentler, which is what makes small corrections possible with a
## thumb that cannot feel where centre is.
@export_range(1.0, 3.0, 0.05) var response_curve: float = 1.6

@export_group("Touch")

## Largest single-frame travel any one touch may report, in viewport units.
## Anything beyond this is a teleport, not a gesture: a touch that was cancelled
## and re-issued somewhere else, or an engine-level delta measured against the
## wrong finger. Clamping is cheap; the alternative is a camera that spins.
@export_range(20.0, 800.0, 1.0) var max_touch_delta: float = 220.0

@export_group("Presentation")

## Alpha at rest. Low enough to stop the controls fighting the scene.
@export_range(0.0, 1.0, 0.01) var rest_opacity: float = 0.35

## Alpha while the thumb is down.
@export_range(0.0, 1.0, 0.01) var active_opacity: float = 0.70

@export var tint: Color = Color(0.86, 0.88, 0.92)

## Accent used for anything the player is meant to read as interactive.
@export var accent: Color = Color(0.62, 0.79, 0.94)

## Seconds for a stick to settle back to its rest look after the thumb lifts.
@export_range(0.0, 1.0, 0.01) var fade_time: float = 0.16


## Deflection shaped by the deadzone and the response curve.
##
## `raw` is (knob - centre) / radius, already clamped to length 1. Returns a
## vector in the same direction whose length is 0 inside the deadzone and rises
## to 1 at full travel.
func shape(raw: Vector2) -> Vector2:
	var magnitude := minf(raw.length(), 1.0)
	if magnitude <= deadzone:
		return Vector2.ZERO
	var past := (magnitude - deadzone) / maxf(1.0 - deadzone, 0.001)
	return (raw / magnitude) * pow(minf(past, 1.0), response_curve)
