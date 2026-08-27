extends RefCounted

## The control scheme, asserted as behaviour rather than as intent.
##
## Every case here corresponds to something that went wrong on a real phone:
## a stick base that travelled, a camera that spun when the second thumb landed,
## a first frame that jumped, a thumb that stopped belonging to the control it
## started on.

const TOUCH := preload("res://tests/touch.gd")
## Enough for a drag to be unambiguous, small enough to stay on screen.
const FAR := 400.0


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var hud: Hud = main.get_node("Hud")
	var player: Player = main.get_node("Player")
	var settings: GameSettings = main.get_node("Settings")
	var move: VirtualStick = hud.get_node("Controls/MoveStick")
	var look: VirtualStick = hud.get_node("Controls/LookStick")
	var touch: RefCounted = TOUCH.new(tree.root)
	# Camera easing would make every look assertion a race against a lerp.
	settings.set_value(&"reduce_motion", 1.0)
	await tree.physics_frame

	await _base_is_fixed(tree, touch, move, expect)
	await _two_thumbs_are_independent(tree, touch, move, look, expect)
	await _replanting_does_not_disturb_the_other(tree, touch, move, look, expect)
	await _ownership_survives_leaving_the_region(tree, touch, hud, move, look, expect)
	await _relative_is_never_trusted(tree, touch, settings, player, hud, expect)
	await _first_move_is_free(tree, touch, settings, player, hud, expect)


## Bug 1. The ring is where HudLayout put it, before, during and after a drag
## that ends far outside it, and the knob never leaves the ring.
func _base_is_fixed(
	tree: SceneTree, touch: RefCounted, move: VirtualStick, expect: RefCounted
) -> void:
	var centre := move.position
	touch.press(1, centre + Vector2(20.0, 0.0))
	await tree.physics_frame
	touch.drag(1, centre + Vector2(FAR, -FAR))
	await tree.physics_frame
	expect.same(move.position, centre, "stick base does not move during a drag")
	expect.ok(
		move.knob_offset().length() <= move.radius + 0.01,
		"knob is clamped to the max radius (%.1f <= %.1f)" % [move.knob_offset().length(), move.radius]
	)
	expect.near(move.value.length(), 1.0, 0.001, "a drag past the ring reads as full deflection")
	expect.near(
		move.value.angle(), Vector2(1.0, 1.0).angle(), 0.01,
		"deflection is free analogue, not snapped to an axis"
	)
	touch.lift(1, centre + Vector2(FAR, -FAR))
	await tree.physics_frame
	expect.same(move.position, centre, "stick base does not move on release")
	expect.same(move.value, Vector2.ZERO, "the stick recentres instantly on release")


## The assertion this whole pass exists for: two thumbs, and lifting either one
## leaves the other exactly where it was.
func _two_thumbs_are_independent(
	tree: SceneTree, touch: RefCounted, move: VirtualStick, look: VirtualStick,
	expect: RefCounted
) -> void:
	touch.press(1, move.position)
	touch.press(2, look.position)
	await tree.physics_frame
	touch.drag(1, move.position + Vector2(0.0, -60.0), Vector2(9999.0, 9999.0))
	touch.drag(2, look.position + Vector2(70.0, 0.0), Vector2(-9999.0, -9999.0))
	await tree.physics_frame
	expect.ok(move.value.y > 0.2, "left thumb drives movement forward (%.3f)" % move.value.y)
	expect.ok(look.value.x > 0.2, "right thumb drives look right (%.3f)" % look.value.x)

	var move_before := move.value
	touch.lift(2, look.position + Vector2(70.0, 0.0))
	await tree.physics_frame
	expect.same(move.value, move_before, "lifting the right thumb leaves movement untouched")
	expect.same(look.value, Vector2.ZERO, "the look stick recentres when its thumb lifts")

	var look_after_press := Vector2.ZERO
	touch.press(2, look.position)
	await tree.physics_frame
	expect.same(look.value, look_after_press, "re-planting the right thumb starts from centre")
	expect.same(move.value, move_before, "re-planting the right thumb leaves movement untouched")
	touch.lift(1, move.position + Vector2(0.0, -60.0))
	touch.lift(2, look.position)
	await tree.physics_frame


## "I could not lift my left thumb without the view misbehaving."
func _replanting_does_not_disturb_the_other(
	tree: SceneTree, touch: RefCounted, move: VirtualStick, look: VirtualStick,
	expect: RefCounted
) -> void:
	touch.press(2, look.position)
	touch.drag(2, look.position + Vector2(60.0, -20.0))
	await tree.physics_frame
	touch.drag(2, look.position + Vector2(60.0, -20.0))
	await tree.physics_frame
	var held := look.value
	var disturbed := false
	for cycle in 6:
		touch.press(1, move.position + Vector2(0.0, 10.0 * cycle))
		await tree.physics_frame
		touch.drag(1, move.position + Vector2(30.0, -40.0))
		await tree.physics_frame
		touch.lift(1, move.position + Vector2(30.0, -40.0))
		await tree.physics_frame
		if look.value != held:
			disturbed = true
	expect.ok(not disturbed, "six rapid left-thumb replants leave the look stick untouched")
	touch.lift(2, look.position + Vector2(60.0, -20.0))
	await tree.physics_frame


func _ownership_survives_leaving_the_region(
	tree: SceneTree, touch: RefCounted, hud: Hud, move: VirtualStick, look: VirtualStick,
	expect: RefCounted
) -> void:
	touch.press(1, move.position)
	await tree.physics_frame
	touch.drag(1, look.position)
	await tree.physics_frame
	var claims: Dictionary = hud.probe()["claims"]
	expect.ok(
		claims.get("move_stick", -1) == 1 and not claims.has("look_stick"),
		"a touch dragged across the screen still belongs to the stick it began on"
	)
	expect.same(look.value, Vector2.ZERO, "the stick it wandered into stays at rest")
	touch.lift(1, look.position)
	await tree.physics_frame


## Bug 2, as a regression test. The engine's own `relative` is wrong whenever a
## second finger is down; a lie in that field must change nothing.
func _relative_is_never_trusted(
	tree: SceneTree, touch: RefCounted, settings: GameSettings, player: Player, hud: Hud,
	expect: RefCounted
) -> void:
	settings.set_value(&"look_style", 1.0)
	await tree.physics_frame
	var start := Vector2(700.0, 220.0)
	touch.press(3, start)
	await tree.physics_frame
	touch.drag(3, start, Vector2(-800.0, 400.0))
	await tree.physics_frame
	var after_guard := player.rotation.y
	touch.drag(3, start + Vector2(-100.0, 0.0), Vector2(-800.0, 400.0))
	await tree.physics_frame
	var turned := rad_to_deg(player.rotation.y - after_guard)
	# 100 units of leftward travel at 0.16 deg per unit is a 16 degree turn to
	# the left, and yaw grows anticlockwise. The relative field says otherwise
	# and is not consulted.
	expect.near(turned, 16.0, 0.6, "look follows measured travel, not the reported relative")
	touch.lift(3, start + Vector2(-100.0, 0.0))
	await tree.physics_frame


func _first_move_is_free(
	tree: SceneTree, touch: RefCounted, settings: GameSettings, player: Player, hud: Hud,
	expect: RefCounted
) -> void:
	var start := Vector2(700.0, 220.0)
	var before := player.rotation.y
	touch.press(4, start)
	await tree.physics_frame
	touch.drag(4, start + Vector2(-260.0, 90.0))
	await tree.physics_frame
	expect.near(player.rotation.y, before, 0.0001, "the first move of a look touch turns nothing")

	var tuning: TouchTuning = hud.tuning
	touch.drag(4, start + Vector2(-4000.0, 90.0))
	await tree.physics_frame
	var travelled := rad_to_deg(absf(player.rotation.y - before)) / 0.16
	expect.ok(
		travelled <= tuning.max_touch_delta + 1.0,
		"a single absurd jump is clamped to max_touch_delta (%.0f <= %.0f units)"
			% [travelled, tuning.max_touch_delta]
	)
	touch.lift(4, start + Vector2(-4000.0, 90.0))
	settings.set_value(&"look_style", 0.0)
	await tree.physics_frame
