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
	await _saving(tree, saves, logic, expect)


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


func _saving(
	tree: SceneTree, saves: SaveService, logic: PowerhouseLogic, expect: RefCounted
) -> void:
	expect.ok(saves.save_to(SaveService.MANUAL), "the act saves")
	logic.load_state({"wrench": false, "reached": []})
	logic.get_parent().get_node("GalleryDoor").open = false
	await tree.physics_frame
	expect.ok(not logic.has_wrench(), "the act's own state can be cleared")
	expect.ok(saves.load_from(SaveService.MANUAL), "and the slot loads")
	await tree.physics_frame
	expect.ok(logic.has_wrench(), "bringing the wrench back")
	expect.ok(logic.probe()["gallery"], "and the doors that were open")
	expect.ok(logic.probe()["lit"], "and the lights that were on")
	saves.erase(SaveService.MANUAL)
