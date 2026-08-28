extends RefCounted

## Act 1, played from the first breaker to the door opening.
##
## The most valuable test in the project, because it is the only one that
## answers "is this finishable". Every other suite asserts that a mechanism
## works; this one walks the act.
##
## It also walks the stair, physically, rather than teleporting past it. A stair
## built as boxes is a wall with a nice pattern on it -- Godot's CharacterBody3D
## does not step up geometry -- and the only way to know the ramp under the
## nosings is right is to put a player on it and see where they end up.

const TOUCH := preload("res://tests/touch.gd")
const LANDING := Vector3(9.9, 0.1, -1.0)
const STAIR_FOOT_Y := -3.9
const WALK_FRAMES := 260


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var house: Node3D = main.get_node("Powerhouse")
	var logic: PowerhouseLogic = house.get_node("Logic")
	var player: Player = main.get_node("Player")
	var hud: Hud = main.get_node("Hud")
	var saves: SaveService = main.get_node("Saves")
	var touch: RefCounted = TOUCH.new(tree.root)

	var seen: Array[String] = []
	logic.checkpoint_reached.connect(func(id: String) -> void: seen.append(id))

	await _dark(tree, house, logic, expect)
	await _lighting(tree, house, logic, player, hud, touch, expect)
	await _interlock(tree, logic, expect)
	await _the_stair(tree, player, hud, expect)
	await _the_gallery_door(tree, logic, expect)
	await _the_bell(tree, logic, expect)

	expect.ok(
		seen == ["lighting", "switchgear", "gallery", "shelter-answered"],
		"the act's checkpoints fire once each, in order (%s)" % [seen]
	)
	await _sounds(tree, house, player, expect)
	# Saving before the edge, deliberately: walking through the shelter door
	# frees this act, and `logic` with it.
	await _saving(tree, saves, logic, expect)
	await _the_edge(tree, main, house, player, expect)


func _dark(tree: SceneTree, house: Node3D, logic: PowerhouseLogic, expect: RefCounted) -> void:
	await tree.physics_frame
	var lamps := tree.get_nodes_in_group(&"bulkhead_lamp")
	expect.ok(lamps.size() >= 6, "the act has lamps in it (%d)" % lamps.size())
	var any_lit := false
	for node in lamps:
		if (node as BulkheadLamp).lit:
			any_lit = true
	expect.ok(not any_lit, "and every one of them starts dark")
	expect.ok(not logic.probe()["main"], "the main is open")
	expect.ok(logic.probe()["bus"], "and the bus is closed, which is why the switchgear room is not")
	expect.ok(not house.get_node("SwitchgearDoor").open, "the switchgear door is shut")


## P1.1. The first thing the player makes happen, and the first thing that
## refuses. Driven through a real touch on the real button, once, so the
## instant-interaction path is proven end to end and not just called.
func _lighting(
	tree: SceneTree, house: Node3D, logic: PowerhouseLogic, player: Player,
	hud: Hud, touch: RefCounted, expect: RefCounted
) -> void:
	var main_breaker: DeviceToggle = house.get_node("Panel/Main")
	player.global_position = Vector3(-6.0, 0.0, -3.6)
	# Aimed at the main breaker itself, computed from where the panel puts it.
	# A ray at the panel's centre passes between two fuses and finds nothing,
	# which is correct -- these are 50 mm handles on a 1.5 m board.
	player.face(deg_to_rad(-13.2), deg_to_rad(-27.0))
	await tree.physics_frame
	await tree.physics_frame

	var button: Control = hud.get_node("Controls/ActionButton")
	expect.ok(button.visible, "the panel offers itself from in front of it")
	touch.press(21, button.position)
	await tree.physics_frame
	touch.lift(21, button.position)
	await tree.physics_frame
	expect.ok(
		hud.probe()["focused"] == false,
		"a switch is used rather than engaged with: the sticks stay on screen"
	)

	# Whatever that first tap hit, put the panel in the state the puzzle starts
	# from and close the main with the faulted circuit still in.
	main_breaker.on = false
	house.get_node("Panel/Fuses/LT-6").on = true
	await tree.physics_frame
	main_breaker.on = true
	house.get_node("Panel/Main").toggled.emit(true)
	await tree.physics_frame
	expect.ok(not logic.probe()["lit"], "closing the main with LT-6 in trips it")
	for frame in 90:
		await tree.physics_frame
	expect.ok(not main_breaker.on, "and the main comes back open by itself")

	house.get_node("Panel/Fuses/LT-6").on = false
	house.get_node("Panel/Fuses/LT-6").toggled.emit(false)
	main_breaker.on = true
	house.get_node("Panel/Main").toggled.emit(true)
	await tree.physics_frame
	expect.ok(logic.probe()["lit"], "with the faulted circuit out, the main holds")
	expect.ok(_lamp(tree, &"LT-1"), "and the hall lights")
	expect.ok(not _lamp(tree, &"LT-6"), "and the stair tower does not, because its fuse is out")


func _lamp(tree: SceneTree, circuit: StringName) -> bool:
	for node in tree.get_nodes_in_group(&"bulkhead_lamp"):
		var lamp := node as BulkheadLamp
		if lamp != null and lamp.circuit == circuit:
			return lamp.lit
	return false


## P1.2. The interlock is a safety feature and the obstacle at the same time.
func _interlock(tree: SceneTree, logic: PowerhouseLogic, expect: RefCounted) -> void:
	var bus: DeviceToggle = logic.get_parent().get_node("Panel/BusMain")
	bus.on = false
	bus.toggled.emit(false)
	await tree.physics_frame
	expect.ok(logic.probe()["switchgear"], "opening the bus main releases the switchgear door")
	expect.ok(logic.probe()["lit"], "and does not put the emergency lighting out with it")


## Walked, not teleported. This is the only assertion that the stair is a stair.
func _the_stair(tree: SceneTree, player: Player, hud: Hud, expect: RefCounted) -> void:
	var move: VirtualStick = hud.get_node("Controls/MoveStick")
	player.global_position = LANDING
	player.face(deg_to_rad(180.0), 0.0)
	player.velocity = Vector3.ZERO
	for frame in 10:
		await tree.physics_frame
	expect.ok(
		absf(player.global_position.y) < 0.4,
		"the landing holds the player at hall level (%.2f)" % player.global_position.y
	)

	move.press(31, move.position)
	move.drag(31, move.position + Vector2(0.0, -140.0))
	for frame in WALK_FRAMES:
		await tree.physics_frame
	move.release(31)
	await tree.physics_frame
	expect.ok(
		player.global_position.y < STAIR_FOOT_Y + 0.6,
		"and walking south goes down the stair to the shaft floor (%.2f)" % player.global_position.y
	)
	expect.ok(
		player.global_position.z > 5.0,
		"arriving at the bottom rather than stuck on it (z %.2f)" % player.global_position.z
	)


## P1.4. The wrench is on its hook, because somebody put it back.
func _the_gallery_door(tree: SceneTree, logic: PowerhouseLogic, expect: RefCounted) -> void:
	var house := logic.get_parent()
	house.get_node("SeizedDog").pushed.emit()
	await tree.physics_frame
	expect.ok(not logic.probe()["gallery"], "the last dog will not move by hand")
	house.get_node("Wrench").pushed.emit()
	await tree.physics_frame
	expect.ok(logic.has_wrench(), "the wrench comes off its hook")
	house.get_node("SeizedDog").pushed.emit()
	await tree.physics_frame
	expect.ok(logic.probe()["gallery"], "and frees the dog")


## P1.5. The act's last beat, and the worst thing in it.
func _the_bell(tree: SceneTree, logic: PowerhouseLogic, expect: RefCounted) -> void:
	expect.near(logic.admit_delay, 11.0, 0.01, "the shelter takes eleven seconds to answer")
	logic.admit_delay = 0.4
	logic.get_parent().get_node("AdmitBell").pushed.emit()
	await tree.physics_frame
	expect.ok(not logic.probe()["shelter"], "and does not answer at once")
	for frame in 40:
		await tree.physics_frame
	expect.ok(logic.probe()["shelter"], "but it answers")
	logic.admit_delay = 11.0


## Every device makes a noise, and the stair is steel.
##
## Worth asserting because all three sounds were generated in P3 and nothing
## played them for a whole phase: a file in assets/ is not a sound in the game.
func _sounds(
	tree: SceneTree, house: Node3D, player: Player, expect: RefCounted
) -> void:
	for path in ["Panel/Main", "Panel/Fuses/LT-1"]:
		var toggle: DeviceToggle = house.get_node(path)
		expect.ok(
			(toggle.get_node("Sound") as AudioStreamPlayer3D).stream != null,
			"%s snaps when it is thrown" % path
		)
	for path in ["Wrench", "SeizedDog", "AdmitBell"]:
		var push: DevicePush = house.get_node(path)
		expect.ok(
			(push.get_node("Sound") as AudioStreamPlayer3D).stream != null,
			"%s makes a noise when pressed" % path
		)
	expect.ok(
		(house.get_node("AdmitBell/Sound") as AudioStreamPlayer3D).stream
			!= (house.get_node("Wrench/Sound") as AudioStreamPlayer3D).stream,
		"and the bell is not the same noise as the wrench"
	)
	for path in ["SwitchgearDoor", "GalleryDoor", "ShelterDoor"]:
		expect.ok(
			(house.get_node("%s/Sound" % path) as AudioStreamPlayer3D).stream != null,
			"%s is heard opening" % path
		)

	# The stair rings because it is grating, which the footstep system finds
	# through SurfaceTag rather than being told.
	var feet: Footsteps = player.get_node("Footsteps")
	var heard: Array = []
	var listener := func(surface: SurfaceType, _at: Vector3, _loud: float) -> void:
		heard.append(surface.id)
	feet.stepped.connect(listener)
	player.global_position = Vector3(9.9, -1.2, 4.5)
	for frame in 8:
		await tree.physics_frame
	feet.advance(3.0)
	# Not a count: teleporting the player onto the stair is itself travel, so
	# the mover fires a step of its own. What matters is what it was standing on.
	var all_steel := heard.size() > 0
	for id in heard:
		if id != &"grating":
			all_steel = false
	expect.ok(all_steel, "a footstep on the stair is a footstep on steel (%s)" % [heard])
	feet.stepped.disconnect(listener)


## Walking through the shelter door ends the slice. Without this the player
## steps into a three-metre concrete box and reports that nothing happened,
## which is a fair thing to report.
func _the_edge(
	tree: SceneTree, main: Node, house: Node3D, player: Player, expect: RefCounted
) -> void:
	var reader: Reader = main.get_node("Reader")
	var post: PostStack = main.get_node("PostStack")
	var end: ActEnd = house.get_node("ActEnd")
	player.global_position = Vector3(9.9, -3.8, 30.3)
	player.velocity = Vector3.ZERO
	for frame in 6:
		await tree.physics_frame
	expect.ok(not reader.is_open(), "the fade runs before the card, not with it")
	for frame in 240:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "walking through the shelter door ends the act")
	expect.near(
		float(post.probe()["exposure"]), 0.0, 0.02,
		"having faded the world out first"
	)
	var title: Label = reader.get_node("Safe/Panel/Pad/Body/Title")
	expect.ok(
		title.text.contains("Act One"),
		"and says so plainly rather than pretending to be fiction (%s)" % title.text
	)

	reader.close()
	# The swap is deferred -- freeing the act from inside a node of that act is
	# the one thing that is never safe -- so it lands on the next idle frame.
	await tree.process_frame
	await tree.process_frame
	expect.near(float(post.probe()["exposure"]), 1.0, 0.02, "putting it down brings the world back")

	var runner: ActRunner = main.get_node("Acts")
	expect.eq(runner.current(), 1, "and the shelter is what comes back")
	expect.ok(main.get_node_or_null("Powerhouse") == null, "the powerhouse is gone, not merely hidden")
	expect.ok(main.get_node_or_null("Shelter") != null, "and the shelter is mounted in its place")
	expect.ok(
		player.global_position.z > 11.0 and absf(player.global_position.x) < 2.0,
		"with the player in the shelter vestibule (%.1f, %.1f)"
			% [player.global_position.x, player.global_position.z]
	)

	# Every case after this one expects Act 1, so put it back. A case that
	# leaves the world somewhere else is a case that breaks its neighbours.
	runner.load_act(0)
	await tree.physics_frame


func _saving(
	tree: SceneTree, saves: SaveService, logic: PowerhouseLogic, expect: RefCounted
) -> void:
	var before := saves.collect()["nodes"] as Dictionary
	expect.ok(before.size() >= 12, "the act has state worth saving (%d nodes)" % before.size())
	expect.ok(saves.save_to(SaveService.MANUAL), "the act saves")

	# Not three spot checks: derange *everything* that claims to be saveable, so
	# a device added later with a broken `load_state` fails here rather than in
	# someone's playthrough.
	var refused := _derange(tree)
	expect.ok(
		refused.is_empty(),
		"every saveable node can be disturbed through its own protocol (%s)" % ", ".join(refused)
	)
	await tree.physics_frame
	expect.ok(not logic.has_wrench(), "the act's own state can be cleared")

	expect.ok(saves.load_from(SaveService.MANUAL), "and the slot loads")
	await tree.physics_frame
	var after := saves.collect()["nodes"] as Dictionary
	var lost := _differences(before, after)
	expect.ok(lost.is_empty(), "and every node comes back exactly as it was (%s)" % ", ".join(lost))
	expect.ok(logic.has_wrench(), "including the wrench")
	expect.ok(logic.probe()["gallery"], "the doors that were open")
	expect.ok(logic.probe()["lit"], "and the lights that were on")
	saves.erase(SaveService.MANUAL)


## Feeds every saveable node a state that is not the one it has, and then checks
## that the node noticed.
##
## The check matters more than the derangement. An earlier version of this only
## called `load_state` with wrong values and then reloaded the slot, which is
## circular: a `load_state` that does nothing leaves the node holding its
## original state, the reload restores what was never lost, and the test passes
## while the device is broken. Verified by breaking one on purpose -- it passed.
## So the contract asserted here is the honest one: **`load_state` must be
## observable in the next `save_state`.** A node that swallows what it is given
## is named and fails.
##
## Returns the keys that refused to change, which is the failure worth printing.
## Nodes whose saved state is *the name of another node*. A synthetic wrong
## value for one of these is a node that does not exist, and correctly ending up
## holding nothing is indistinguishable from having ignored the input. They are
## covered directly instead, by a case that hands them something real.
const BY_REFERENCE: Array[StringName] = [&"hands"]


func _derange(tree: SceneTree) -> Array[String]:
	var refused: Array[String] = []
	for node in tree.get_nodes_in_group(&"saveable"):
		if BY_REFERENCE.has(node.get("save_key")):
			continue
		var state: Dictionary = node.call("save_state")
		var wrong := {}
		var changeable := false
		for field in state:
			wrong[field] = _opposite(state[field])
			changeable = changeable or str(wrong[field]) != str(state[field])
		if not changeable:
			continue  # nothing here this check knows how to make wrong
		node.call("load_state", wrong)
		if str(node.call("save_state")) == str(state):
			refused.append("%s ignored load_state" % node.get("save_key"))
	return refused


## The wrong value for a field, whatever kind of field it is. Anything exotic is
## left alone -- a value we cannot invert is one this check cannot speak about,
## and pretending otherwise would be worse than skipping it.
##
## Arrays are opposed element by element rather than emptied. Emptying them is
## the obvious thing and it is wrong: a `load_state` that sensibly guards on
## `at.size() == 3` before trusting a position reads an empty array as absent,
## changes nothing, and gets reported as broken when it is the only one here
## doing the careful thing.
func _opposite(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL:
			return not value
		TYPE_INT:
			return int(value) + 7
		TYPE_FLOAT:
			return float(value) + 7.0
		TYPE_STRING, TYPE_STRING_NAME:
			return "%s-wrong" % value
		TYPE_ARRAY:
			return (value as Array).map(_opposite)
	return value


## Which keys did not survive the round trip, named so the failure says which
## device is broken rather than that one of them is.
##
## Numbers are compared with a tolerance and everything else exactly. That is
## not slack: a physics body settles under gravity in the frames between saving
## and loading, so the player comes back four millimetres lower than they left
## and no amount of correctness will make those two floats equal. A restore that
## has actually failed is out by metres, or by a bool.
const SLACK := 0.01


func _differences(before: Dictionary, after: Dictionary) -> Array[String]:
	var lost: Array[String] = []
	for key in before:
		if not after.has(key):
			lost.append("%s vanished" % key)
		elif not _alike(before[key], after[key]):
			lost.append("%s is %s, was %s" % [key, after[key], before[key]])
	return lost


func _alike(a: Variant, b: Variant) -> bool:
	if a is float or a is int:
		return (b is float or b is int) and absf(float(a) - float(b)) <= SLACK
	if a is Array:
		if not (b is Array) or (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _alike(a[i], b[i]):
				return false
		return true
	if a is Dictionary:
		if not (b is Dictionary) or (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for key in a as Dictionary:
			if not (b as Dictionary).has(key) or not _alike(a[key], b[key]):
				return false
		return true
	return a == b
