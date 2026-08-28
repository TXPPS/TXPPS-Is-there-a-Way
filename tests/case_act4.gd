extends RefCounted

## Act 4, both ways.
##
## The first thing in this project that branches, so it is the first case that
## has to walk the same act twice and get two different answers. It reloads the
## act between runs rather than trying to undo an ending: an ending is the end,
## and a test that could take it back would be testing something the player
## cannot do.
##
## Act 4 is rooms added to Act 1, so `Powerhouse/Gate` is where it lives. P4.1
## and P4.2 are in Act 1's gallery, which the player walked in the dark in Act 1
## and did not look at.

const PATIENCE := 400


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var runner: ActRunner = main.get_node("Acts")
	runner.load_act(0)
	await tree.physics_frame

	await _the_way_up(tree, main, expect)
	await _the_gauge_is_lying(tree, main, expect)
	await _pulling_the_lead(tree, main, expect)
	await _the_latch_is_still_latched(tree, main, expect)
	await _ending_a(tree, main, runner, expect)
	await _ending_b(tree, main, runner, expect)

	# This case ends the game, twice. A case that changes the world puts it back
	# -- and putting *this* back means rebuilding the act, because `load_act`
	# on the act already mounted is deliberately a no-op.
	runner.restart(0)
	await tree.physics_frame
	expect.eq(
		String((_gate(main).get_node("Logic") as GateLogic).ending()), "",
		"and leaves a building nobody has finished, for whatever runs next"
	)


func _gate(main: Node) -> Node3D:
	return main.get_node("Powerhouse/Gate")


## The route, walked rather than teleported.
##
## Act 1's stair tower taught this: a stair built as boxes is a wall with a nice
## pattern on it, because CharacterBody3D does not step up geometry. The only
## way to know a ramp under the nosings is right is to put a player on it and
## see where they end up. This one climbs 4.5 m out of the gallery, and the deck
## it arrives at is *beside* the shaft rather than above it -- a deck over an
## open shaft has no floor anywhere, and the player falls through it.
func _the_way_up(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var player: Player = main.get_node("Player")
	var move: VirtualStick = (main.get_node("Hud") as Hud).get_node("Controls/MoveStick")

	# In the gallery, at the doorway the pier stair is behind.
	player.global_position = Vector3(10.6, -3.8, 16.0)
	player.velocity = Vector3.ZERO
	for frame in 10:
		await tree.physics_frame
	expect.ok(
		player.global_position.y > -4.2,
		"there is floor at the gallery end of it (y %.2f)" % player.global_position.y
	)

	# At the foot of the stair, and then walked up it.
	player.global_position = Vector3(13.3, -3.8, 15.6)
	player.velocity = Vector3.ZERO
	for frame in 10:
		await tree.physics_frame
	var foot := player.global_position.y
	expect.ok(foot > -4.2 and foot < -3.5, "and floor at the foot of the stair (y %.2f)" % foot)

	# North is -Z, and the stair descends along +Z from its top nosing, so
	# walking north climbs it. Through the stick, like a player.
	player.face(0.0, 0.0)
	await tree.physics_frame
	move.press(41, move.position)
	move.drag(41, move.position + Vector2(0.0, -140.0))
	for frame in 460:
		await tree.physics_frame
	move.release(41)
	await tree.physics_frame
	expect.ok(
		player.global_position.y > -0.2,
		"walking north up it climbs (y %.2f)" % player.global_position.y
	)

	# And the deck, which is a floor and not a hole.
	player.global_position = Vector3(16.7, 0.7, 12.0)
	player.velocity = Vector3.ZERO
	for frame in 20:
		await tree.physics_frame
	expect.ok(
		player.global_position.y > 0.3,
		"the pier deck holds you up (y %.2f)" % player.global_position.y
	)


## P4.1. Nothing to do: read the panel, and notice that the number is impossible.
func _the_gauge_is_lying(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var gate := _gate(main)
	var logic: GateLogic = gate.get_node("Logic")
	var gauge: DeviceGauge = gate.get_node("Gallery/StageGauge")
	await tree.physics_frame

	expect.near(gauge.reading(), 30.5, 0.01, "the stage repeater reads 30.5 ft")
	expect.ok(
		gauge.reading() > GateLogic.LATCH_FEET,
		"which is over the 30.0 the sequence holds above, and that is why it holds"
	)
	expect.ok(logic.latched(), "so the sequence is latched")
	expect.ok(
		(gate.get_node("Gallery/SeqHeld") as DeviceToggle).on,
		"and says so on the panel"
	)


## P4.2. The gauge is not broken and is not lying: it is repeating, faithfully,
## a number that is being fabricated on a shelf beside it.
func _pulling_the_lead(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var gate := _gate(main)
	var logic: GateLogic = gate.get_node("Logic")
	var gauge: DeviceGauge = gate.get_node("Gallery/StageGauge")
	var lead: DeviceToggle = gate.get_node("Gallery/BenchLead")

	var told: Array[float] = []
	logic.stage_told_the_truth.connect(func(feet: float) -> void: told.append(feet))

	lead.get_node("Zone").engage()
	await tree.physics_frame
	await tree.physics_frame
	expect.near(gauge.reading(), 21.4, 0.01, "pull the lead and the true stage reaches the panel")
	expect.eq(told.size(), 1, "which the act notices, once")
	expect.ok(
		gauge.reading() < GateLogic.LATCH_FEET,
		"and it is under the latch figure, as it has been since 1994"
	)


## The distinction the whole act turns on: a latch that has stopped being fed a
## reason to hold is still latched. Latches are reset deliberately.
func _the_latch_is_still_latched(
	tree: SceneTree, main: Node, expect: RefCounted
) -> void:
	var gate := _gate(main)
	var logic: GateLogic = gate.get_node("Logic")
	expect.ok(logic.latched(), "the sequence is still latched, because latches latch")

	var interlock: DeviceInterlock = gate.get_node("House/Interlock")
	interlock.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(
		not interlock.has_key(&"RUN"),
		"and the key stays captive, because the run has not concluded"
	)

	gate.get_node("House/LatchReset/Zone").engage()
	await tree.physics_frame
	expect.ok(logic.latched(), "so the reset does nothing at all")


## Ending A. Conclude the run: the cabinet reads the channel as concluded and
## gives up the key, and the price is that you performed the programme's final
## observation on yourself.
func _ending_a(
	tree: SceneTree, main: Node, runner: ActRunner, expect: RefCounted
) -> void:
	var gate := _gate(main)
	var logic: GateLogic = gate.get_node("Logic")
	var reader: Reader = main.get_node("Reader")

	var endings: Array[String] = []
	logic.ending_reached.connect(func(which: StringName) -> void: endings.append(String(which)))

	# Standing at the lamp and letting the seam close is what `Observer` does to
	# a player who does not step off the line; the act reads it as a concluded
	# channel. Driven directly here -- `case_observer` walks the approach.
	logic.call("_finish", &"conclude")
	await tree.physics_frame
	expect.eq(endings, ["conclude"], "concluding the run is an ending")
	expect.eq(String(logic.ending()), "conclude", "and the act knows which")

	var interlock: DeviceInterlock = gate.get_node("House/Interlock")
	interlock.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(interlock.has_key(&"RUN"), "now the cabinet gives up the key")

	gate.get_node("House/LatchReset/Zone").engage()
	await tree.physics_frame
	expect.ok(not logic.latched(), "and the sequence resets")

	for frame in PATIENCE:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "the ending is shown")
	var title: Label = reader.get_node("Safe/Panel/Pad/Body/Title")
	expect.ok(
		title.text.contains("Conclude"),
		"and it is the right one (%s)" % title.text
	)
	reader.close()
	await tree.process_frame


## Ending B. Refuse. The gate is designed to be operable when the control house
## is dead, because a 1954 dam had to be.
func _ending_b(
	tree: SceneTree, main: Node, runner: ActRunner, expect: RefCounted
) -> void:
	# A fresh act: an ending is the end, and a test that could take one back
	# would be testing something the player cannot do.
	runner.restart(0)
	await tree.physics_frame

	var gate := _gate(main)
	var logic: GateLogic = gate.get_node("Logic")
	var reader: Reader = main.get_node("Reader")
	expect.eq(String(logic.ending()), "", "a building nobody has finished yet")

	var permissive: DeviceToggle = gate.get_node("Pier/HandPump")
	expect.ok(permissive.on, "the gate is on its permissive")
	permissive.get_node("Zone").engage()
	await tree.physics_frame
	expect.eq(String(logic.ending()), "open", "taking it off by hand is the other ending")

	for frame in PATIENCE:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "which is shown too")
	var title: Label = reader.get_node("Safe/Panel/Pad/Body/Title")
	expect.ok(title.text.contains("Open the gate"), "and is the other card (%s)" % title.text)
	reader.close()
	await tree.process_frame

	# Neither ending is reachable twice, and neither turns into the other.
	permissive.get_node("Zone").engage()
	await tree.physics_frame
	expect.eq(String(logic.ending()), "open", "and an ending is not something you can take back")
