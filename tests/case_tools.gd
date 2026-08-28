extends RefCounted

## Carrying something, and reading it.
##
## The first thing in this game that moves through the building with the player.
## Everything else is used where it stands, so the interesting failures here are
## all about *ownership*: who the tool is a child of, what happens to it when the
## act it was found in is thrown away, and whether a save can put it back in the
## right hand.
##
## The photometer is also the one place the entity is proved rather than felt,
## so the reading is asserted against the geometry rather than against itself.

const PHOTOMETER := preload("res://src/world/tools/photometer.tscn")

## Well clear of both acts. Same reason as `case_observer`: one physics space.
const NOWHERE := Vector3(40.0, -60.0, 0.0)


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var player: Player = main.get_node("Player")
	var hands: Hands = player.get_node("Head/Camera/Hands")
	var runner: ActRunner = main.get_node("Acts")

	# Put it in the act the way an act would, then wire the level the way an act
	# swap does. No act has a photometer in it yet -- it belongs to Act 3 -- so
	# this case brings its own.
	var tool: CarriedTool = PHOTOMETER.instantiate()
	runner.root().add_child(tool)
	tool.global_position = player.global_position + Vector3(0.0, 1.2, -1.0)
	main.call("wire_level")
	await tree.physics_frame

	await _picking_it_up(tree, hands, player, tool, expect)
	await _putting_it_down(tree, hands, player, expect)
	await _it_comes_with_you(tree, main, hands, runner, expect)
	await _a_save_remembers_the_hand(tree, main, hands, expect)
	await _the_meter_reads_the_room(tree, main, expect)
	await _the_meter_sees_the_seam(tree, main, expect)

	# This case is the only one that puts a *prop* into somebody else's act, so
	# it is the only one that has to take it out again. `case_reach` walks every
	# interactable in both acts straight after this, and a photometer left in
	# the shelter is a photometer it counts and tries to reach.
	hands.drop()
	for node in tree.get_nodes_in_group(&"carried_tool"):
		var stray := node as Node
		stray.get_parent().remove_child(stray)
		stray.free()
	await tree.process_frame
	expect.ok(
		tree.get_nodes_in_group(&"carried_tool").is_empty(),
		"the case takes its own prop back out of the level it borrowed"
	)
	runner.load_act(0)
	await tree.physics_frame


func _picking_it_up(
	tree: SceneTree, hands: Hands, player: Player, tool: CarriedTool, expect: RefCounted
) -> void:
	expect.ok(hands.empty(), "the player starts with their hands empty")
	expect.ok(not tool.held(), "and the tool is in the world")

	tool.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(hands.holding() == tool, "engaging it takes it")
	expect.ok(tool.held(), "which the tool knows")
	expect.ok(
		tool.get_parent() == hands,
		"and it is a child of the hand rather than following it (%s)" % tool.get_parent().name
	)
	expect.ok(
		not (tool.get_node("Zone") as Interactable).available,
		"a tool in your hand is not a thing to walk up to and take"
	)

	# It is under the camera, so looking around carries it. Nothing follows.
	var before: Vector3 = tool.global_position
	player.face(deg_to_rad(90.0), 0.0)
	await tree.physics_frame
	expect.ok(
		tool.global_position.distance_to(before) > 0.2,
		"turning the head takes it with you, because it *is* the camera's transform"
	)


func _putting_it_down(
	tree: SceneTree, hands: Hands, player: Player, expect: RefCounted
) -> void:
	player.global_position = Vector3(-6.0, 0.0, -2.5)
	player.face(0.0, 0.0)
	await tree.physics_frame
	await tree.physics_frame

	var tool := hands.holding()
	hands.drop()
	await tree.physics_frame
	expect.ok(hands.empty(), "putting it down empties the hand")
	expect.ok(not tool.held(), "and the tool knows that too")
	expect.ok(
		(tool.get_node("Zone") as Interactable).available,
		"and it can be picked up again"
	)
	expect.ok(
		tool.global_position.y < 0.4,
		"it lands on the floor rather than hanging at chest height (y %.2f)"
			% tool.global_position.y
	)
	expect.ok(
		tool.global_position.distance_to(player.global_position) < 1.6,
		"within reach of where the player is standing"
	)


## The point of a tool: it is worthless in the room it was found in.
func _it_comes_with_you(
	tree: SceneTree, main: Node, hands: Hands, runner: ActRunner, expect: RefCounted
) -> void:
	var tool: CarriedTool = tree.get_first_node_in_group(&"carried_tool")
	tool.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(not hands.empty(), "pick it up again")

	runner.load_act(1)
	await tree.physics_frame
	expect.ok(main.get_node_or_null("Shelter") != null, "change acts")
	expect.ok(
		hands.holding() != null and is_instance_valid(hands.holding()),
		"and it is still in your hand, because the player is not part of the act"
	)

	# And a tool put down belongs to the act, so it is freed with it rather than
	# outliving it invisibly in the middle of the next one.
	hands.drop()
	await tree.physics_frame
	var dropped: CarriedTool = tree.get_first_node_in_group(&"carried_tool")
	expect.ok(
		dropped.get_parent() == runner.root(),
		"and putting it down leaves it in the act you are in (%s)" % dropped.get_parent().name
	)


func _a_save_remembers_the_hand(
	tree: SceneTree, main: Node, hands: Hands, expect: RefCounted
) -> void:
	var saves: SaveService = main.get_node("Saves")
	var tool: CarriedTool = tree.get_first_node_in_group(&"carried_tool")
	tool.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(not hands.empty(), "hold it")
	expect.ok(saves.save_to(SaveService.MANUAL), "and save")

	hands.drop()
	await tree.physics_frame
	expect.ok(hands.empty(), "put it down")

	expect.ok(saves.load_from(SaveService.MANUAL), "load the slot")
	await tree.physics_frame
	expect.ok(
		hands.holding() != null and String(hands.holding().save_key) == "photometer",
		"and it is back in your hand"
	)

	# A save naming a tool this build does not have must not leave the player
	# holding something the save never described.
	hands.load_state({"tool": "a_tool_that_was_cut"})
	await tree.physics_frame
	expect.ok(hands.empty(), "a save naming a tool that does not exist empties the hand")
	saves.erase(SaveService.MANUAL)


## Illuminance is arithmetic on the lamps that can see you, so it is asserted
## against the geometry: twice as far is a quarter as much, and a wall is zero.
func _the_meter_reads_the_room(
	tree: SceneTree, main: Node, expect: RefCounted
) -> void:
	var room := Node3D.new()
	tree.root.add_child(room)
	var lamp := OmniLight3D.new()
	lamp.add_to_group(&"practical")
	lamp.light_energy = 4.2
	lamp.omni_range = 14.0
	room.add_child(lamp)
	lamp.global_position = NOWHERE
	await tree.physics_frame

	var space := main.get_viewport().world_3d.direct_space_state
	var lights: Array = [lamp]
	var near := Photometer.measure(space, lights, NOWHERE + Vector3(0.0, 0.0, 2.0), 114.0)
	var far := Photometer.measure(space, lights, NOWHERE + Vector3(0.0, 0.0, 4.0), 114.0)

	expect.near(near, 120.0, 5.0, "a sodium bulkhead at two metres reads about 120 lx")
	expect.near(
		far, near * 0.25, 1.0,
		"and twice as far is a quarter as much, because that is what light does"
	)

	lamp.light_energy = 0.0
	expect.near(
		Photometer.measure(space, lights, NOWHERE + Vector3(0.0, 0.0, 2.0), 114.0), 0.0, 0.001,
		"an unlit fitting contributes nothing"
	)
	room.queue_free()
	await tree.process_frame


## **The seam is real.** The game's one moment of instrumented proof: the drop
## is not noise, it is a number, and it is the same number every time.
##
## Nothing in the photometer knows the entity exists. It sums the lamps that can
## see it, and the entity's whole existence is standing between the player and a
## lamp -- so it stops counting, and the reading falls by exactly what that lamp
## was worth.
func _the_meter_sees_the_seam(
	tree: SceneTree, main: Node, expect: RefCounted
) -> void:
	var room := Node3D.new()
	tree.root.add_child(room)

	var stand_in := Node3D.new()
	room.add_child(stand_in)
	stand_in.global_position = NOWHERE

	var lamp := OmniLight3D.new()
	lamp.add_to_group(&"practical")
	lamp.light_energy = 4.2
	lamp.omni_range = 14.0
	room.add_child(lamp)
	lamp.global_position = NOWHERE + Vector3(0.0, 0.0, -5.0)

	# A body between them, on the line, with a collider so a ray can find it.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.44, 1.95, 0.1)
	shape.shape = box
	blocker.add_child(shape)
	room.add_child(blocker)
	blocker.global_position = NOWHERE + Vector3(0.0, 0.0, -2.5)
	await tree.physics_frame

	var space := main.get_viewport().world_3d.direct_space_state
	var lights: Array = [lamp]
	var interrupted := Photometer.measure(space, lights, NOWHERE, 114.0)
	expect.near(interrupted, 0.0, 0.001, "with something on the line, the lamp does not count")

	blocker.global_position = NOWHERE + Vector3(3.0, 0.0, -2.5)
	await tree.physics_frame
	var clear := Photometer.measure(space, lights, NOWHERE, 114.0)
	expect.near(clear, 19.15, 0.5, "step it off the line and the lamp is back")

	# The same number every time, which is what makes it evidence.
	blocker.global_position = NOWHERE + Vector3(0.0, 0.0, -2.5)
	await tree.physics_frame
	var again := Photometer.measure(space, lights, NOWHERE, 114.0)
	expect.near(again, interrupted, 0.001, "and the drop is the same number every time")
	expect.ok(clear - interrupted > 5.0, "a drop big enough to read (%.1f lx)" % (clear - interrupted))

	room.queue_free()
	await tree.process_frame
