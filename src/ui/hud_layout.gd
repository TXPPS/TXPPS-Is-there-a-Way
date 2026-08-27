@tool
class_name HudLayout
extends Resource

## Where every on-screen control lives, in one editable place.
##
## Nothing in the HUD may hard-code a position or a size. Anchors are expressed
## as insets from a corner of the *safe* rect, so a notch, a home indicator or a
## rounded corner moves the controls rather than being drawn under.
##
## Units are viewport units, not points. The two differ on a phone -- the
## viewport is stretched to a fixed 1280-wide design space -- so anything with a
## minimum size a thumb has to hit is checked in points at runtime against
## `min_touch_points`. See docs/ARCHITECTURE.md, "Reserved HUD rects".

@export_group("Sticks")

## Centre of the movement stick, measured in from the bottom-left safe corner.
@export var move_stick_inset: Vector2 = Vector2(132.0, 124.0)

## Centre of the look stick, measured in from the bottom-right safe corner.
@export var look_stick_inset: Vector2 = Vector2(132.0, 124.0)

## Distance from a stick's centre to full deflection.
@export_range(48.0, 200.0, 1.0) var stick_radius: float = 96.0

## Radius of the moving knob.
@export_range(12.0, 80.0, 1.0) var knob_radius: float = 34.0

## Grown onto the drawn ring to make the region a thumb may land in. A stick you
## have to hit dead centre is a stick you look down at.
@export_range(0.0, 120.0, 1.0) var claim_padding: float = 52.0

@export_group("Action buttons")

## Buttons sit on an arc swung around the look stick, so the thumb that is
## already there reaches them without the hand moving. Distance from the look
## stick's centre to a button.
@export_range(80.0, 340.0, 1.0) var action_arc_radius: float = 230.0

## Where the first button sits, in degrees anticlockwise from straight up. The
## arc has to clear the look stick's own claim region, which is why it starts
## above rather than beside it.
@export_range(0.0, 120.0, 1.0) var action_arc_start_degrees: float = 15.0

## Angle between neighbouring buttons.
@export_range(10.0, 90.0, 1.0) var action_arc_step_degrees: float = 40.0

@export_range(20.0, 90.0, 1.0) var action_button_radius: float = 38.0

@export_group("Pause")

## Top-right, and deliberately far from the build stamp in the HTML shell's
## top-left corner: neither may be within a thumb's slip of the other.
@export var pause_inset: Vector2 = Vector2(46.0, 44.0)

@export_range(24.0, 90.0, 1.0) var pause_radius: float = 34.0

@export_group("Reach")

## Apple's floor for a touch target, in points. Enforced at runtime against the
## live point-to-viewport scale, so a smaller phone grows the controls instead
## of shrinking them below what a thumb can hit.
@export_range(30.0, 64.0, 1.0) var min_touch_points: float = 44.0


## Centre of the movement stick inside `safe`, with the player's offset applied.
func move_stick_centre(safe: Rect2, offset: Vector2) -> Vector2:
	return Vector2(
		safe.position.x + move_stick_inset.x + offset.x,
		safe.end.y - move_stick_inset.y - offset.y
	)


func look_stick_centre(safe: Rect2, offset: Vector2) -> Vector2:
	return Vector2(
		safe.end.x - look_stick_inset.x - offset.x,
		safe.end.y - look_stick_inset.y - offset.y
	)


func pause_centre(safe: Rect2) -> Vector2:
	return Vector2(safe.end.x - pause_inset.x, safe.position.y + pause_inset.y)


## Centre of the `index`-th action button: up and to the left of the look stick,
## so buttons stack away from the screen edge rather than into it.
func action_centre(safe: Rect2, offset: Vector2, index: int) -> Vector2:
	var radians := deg_to_rad(
		action_arc_start_degrees + action_arc_step_degrees * float(index)
	)
	var arc := Vector2(-sin(radians), -cos(radians)) * action_arc_radius
	return look_stick_centre(safe, offset) + arc


## A square rect of `radius` around `centre`, grown to `min_touch_points` if the
## configured size would be smaller than a thumb on this screen.
func touch_rect(centre: Vector2, radius: float, points_to_units: float) -> Rect2:
	var floor_radius := min_touch_points * points_to_units * 0.5
	var r := maxf(radius, floor_radius)
	return Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)
