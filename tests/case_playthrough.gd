extends RefCounted

## The whole game, once, in order, without shortcuts between acts.
##
## Every other act case sets its own preconditions, because a case that had to
## play three acts to test the fourth would be untestable when the third broke.
## That is the right trade and it leaves exactly one thing uncovered: whether
## the acts actually join up. Four acts, two act swaps and one loop back, and
## the seams between them are where a game with a save system and an act runner
## goes wrong.
##
## So this one never calls `load_act`. It goes through the doors.

## Long enough for any timer in the game, at 60 Hz.
const PATIENCE := 1200


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var runner: ActRunner = main.get_node("Acts")
	var saves: SaveService = main.get_node("Saves")
	var player: Player = main.get_node("Player")
	var reader: Reader = main.get_node("Reader")
	var journal: Journal = main.get_node("Journal")

	# A new game, and nothing carried in from the cases before this one.
	runner.restart(0)
	journal.load_state({"read": []})
	await tree.physics_frame

	var reached: Array[String] = []
	await _act_one(tree, main, player, reader, reached, expect)
	await _act_two(tree, main, player, reader, reached, expect)
	await _act_three(tree, main, player, reader, reached, expect)
	await _act_four(tree, main, player, reader, reached, expect)

	expect.ok(
		reached == ["powerhouse", "shelter", "annex", "gate"],
		"and it went through them in order, by the doors (%s)" % [reached]
	)

	runner.restart(0)
	await tree.physics_frame


## Everything an act needs, set rather than pressed. The individual cases press
## the buttons; this one is about the joins.
func _solve_powerhouse(main: Node) -> void:
	var house: Node3D = main.get_node("Powerhouse")
	for name in ["LT-1", "LT-2", "LT-4"]:
		(house.get_node("Panel/Fuses/" + name) as DeviceToggle).on = true
	(house.get_node("Panel/Fuses/LT-6") as DeviceToggle).on = false
	(house.get_node("Panel/Main") as DeviceToggle).on = true
	(house.get_node("Panel/BusMain") as DeviceToggle).on = false
	(house.get_node("Logic") as PowerhouseLogic).load_state(
		{"wrench": true, "reached": ["lighting", "switchgear", "gallery"]})
	(house.get_node("GalleryDoor") as DeviceDoor).open = true
	(house.get_node("ShelterDoor") as DeviceDoor).open = true


func _act_one(
	tree: SceneTree, main: Node, player: Player, reader: Reader,
	reached: Array[String], expect: RefCounted
) -> void:
	expect.ok(main.get_node_or_null("Powerhouse") != null, "a new game starts in the powerhouse")
	reached.append("powerhouse")
	_solve_powerhouse(main)
	await tree.physics_frame

	# Walk into the shelter door's trigger, which is how Act 1 actually ends.
	player.global_position = Vector3(9.9, -3.8, 30.3)
	player.velocity = Vector3.ZERO
	for frame in PATIENCE:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "walking through the shelter door ends it")
	reader.close()
	for frame in 60:
		await tree.process_frame
		if not reader.is_open() and main.get_node_or_null("Shelter") != null:
			break


func _act_two(
	tree: SceneTree, main: Node, player: Player, reader: Reader,
	reached: Array[String], expect: RefCounted
) -> void:
	expect.ok(main.get_node_or_null("Shelter") != null, "and the shelter is what it hands you to")
	expect.ok(main.get_node_or_null("Powerhouse") == null, "with the powerhouse gone")
	reached.append("shelter")
	expect.ok(
		player.global_position.z > 11.0,
		"standing in the vestibule (z %.1f)" % player.global_position.z
	)

	var shelter: Node3D = main.get_node("Shelter")
	var power: ShelterLogic = shelter.get_node("Logic")
	var plant: Node3D = shelter.get_node("Plant")
	var breakers: Node3D = shelter.get_node("Panel/Breakers")
	# Engaged, not assigned. A DeviceToggle's `on` setter moves the handle and
	# does not emit `toggled`, so setting it directly changes what the panel
	# looks like and tells the act nothing -- which is right for restoring a
	# save and wrong for pretending to be a player.
	(plant.get_node("DayTankValve") as DeviceValve).open = true
	plant.get_node("TransferSwitch/Zone").engage()
	for name in ["Heater", "Mess"]:
		(breakers.get_node(name) as DeviceToggle).get_node("Zone").engage()
	plant.get_node("Starter/Zone").engage()
	for frame in 240:
		await tree.physics_frame
		if power.running():
			break
	plant.get_node("SetMain/Zone").engage()
	for frame in PATIENCE:
		await tree.physics_frame
		if power.probe()["stair"]:
			break
	expect.ok(power.live(), "the set carries the shelter")
	expect.ok(power.probe()["stair"], "and the stair to the annex drains")


func _act_three(
	tree: SceneTree, main: Node, player: Player, reader: Reader,
	reached: Array[String], expect: RefCounted
) -> void:
	var shelter: Node3D = main.get_node("Shelter")
	var annex: Node3D = shelter.get_node("Annex")
	expect.ok(annex != null, "the annex is behind the door, in the same building")
	reached.append("annex")

	var logic: AnnexLogic = annex.get_node("Logic")
	var power: ShelterLogic = shelter.get_node("Logic")
	var breakers: Node3D = shelter.get_node("Panel/Breakers")

	(annex.get_node("Timeclock") as Timeclock).load_state({"digits": [8, 3, 0]})
	await tree.physics_frame
	annex.get_node("Interlock/Zone").engage()
	await tree.physics_frame
	expect.ok(logic.key_out(), "the interlock gives up chamber B's key")

	# The price: put the annex lights out to start the sump against head.
	(breakers.get_node("AnnexLighting") as DeviceToggle).get_node("Zone").engage()
	await tree.physics_frame
	if not (shelter.get_node("Plant/SetMain") as DeviceToggle).on:
		shelter.get_node("Plant/SetMain/Zone").engage()
	await tree.physics_frame
	(annex.get_node("TankDrain") as DeviceToggle).get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(logic.drained(), "and the tank room drains once something is switched out")

	(annex.get_node("Reels/RF0840") as DevicePush).get_node("Zone").engage()
	for frame in PATIENCE:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "taking Reel 9-C ends the act")
	reader.close()
	# The act swap is deferred and the reader takes a frame to settle. Waiting
	# for the world rather than counting frames at it.
	for frame in 60:
		await tree.process_frame
		if not reader.is_open() and main.get_node_or_null("Powerhouse") != null:
			break


func _act_four(
	tree: SceneTree, main: Node, player: Player, reader: Reader,
	reached: Array[String], expect: RefCounted
) -> void:
	expect.ok(
		main.get_node_or_null("Powerhouse") != null,
		"and puts you back in Act 1's building, which is where Act 4 is"
	)
	reached.append("gate")

	# The loop back is the whole point of the act stash: everything Act 1 was
	# left with has to still be true, an act and an hour later.
	var house: Node3D = main.get_node("Powerhouse")
	expect.ok(
		(house.get_node("Panel/Main") as DeviceToggle).on,
		"with the main still closed, because that is how it was left"
	)
	expect.ok(
		(house.get_node("GalleryDoor") as DeviceDoor).open,
		"and the gallery door still open"
	)
	expect.ok(
		player.global_position.z > 12.0 and player.global_position.y < -3.0,
		"standing in the gallery (%.1f, %.1f)" % [player.global_position.y, player.global_position.z]
	)

	var gate: Node3D = house.get_node("Gate")
	var logic: GateLogic = gate.get_node("Logic")
	expect.ok(logic.latched(), "the sequence is latched, on a number that is not true")

	gate.get_node("Gallery/BenchLead/Zone").engage()
	await tree.physics_frame
	gate.get_node("House/Interlock/Zone").engage()
	await tree.physics_frame
	expect.ok(not logic.probe()["key"], "and it will not let go until the run concludes")

	logic.call("_finish", &"conclude")
	await tree.physics_frame
	gate.get_node("House/Interlock/Zone").engage()
	await tree.physics_frame
	gate.get_node("House/LatchReset/Zone").engage()
	await tree.physics_frame
	expect.ok(not logic.latched(), "conclude the run and the sequence resets")

	for frame in PATIENCE:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "and the game ends")
	var title: Label = reader.get_node("Safe/Panel/Pad/Body/Title")
	expect.ok(title.text.contains("Conclude"), "on an ending (%s)" % title.text)
	reader.close()
	await tree.process_frame
