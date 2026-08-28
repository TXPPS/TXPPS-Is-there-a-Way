extends RefCounted

## Act 2, walked from the vestibule to the annex door.
##
## Like `case_act1` this is the case that asks **is it finishable**, and it is
## the only one that runs the act's three gates against each other rather than
## one at a time. It also walks the wrong answer on purpose: shedding the single
## biggest load is what anyone tries first, it holds, and then the float calls
## for the sump nine seconds later and drops the bus. That failure is the act's
## best moment and it would be a shame to ship it broken.
##
## Time is moved by waiting physics frames rather than by poking the countdowns,
## because the countdowns are the thing most likely to be wrong.

## Long enough for any of the act's timers, at 60 Hz.
const PATIENCE := 900


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var runner: ActRunner = main.get_node("Acts")
	var saves: SaveService = main.get_node("Saves")
	runner.load_act(1)
	await tree.physics_frame

	var shelter: Node3D = main.get_node("Shelter")
	var logic: ShelterLogic = shelter.get_node("Logic")
	var plant: Node3D = shelter.get_node("Plant")
	var breakers: Node3D = shelter.get_node("Panel/Breakers")

	var seen: Array[String] = []
	logic.checkpoint_reached.connect(func(id: String) -> void: seen.append(id))
	var trips: Array[String] = []
	logic.bus_tripped.connect(func(why: String) -> void: trips.append(why))

	await _as_emil_left_it(tree, logic, plant, expect)
	await _the_set_will_not_fire(tree, logic, plant, expect)
	await _the_fuel(tree, logic, plant, expect)
	await _test_is_not_emergency(tree, logic, plant, expect)
	await _too_much_load(tree, logic, plant, breakers, trips, expect)
	await _the_obvious_answer_fails(tree, logic, plant, breakers, trips, expect)
	await _shedding_enough(tree, logic, plant, breakers, expect)
	await _the_way_on(tree, shelter, logic, expect)
	_the_set_is_heard(shelter, expect)

	expect.ok(
		seen == ["generator", "bus", "sump", "annex"],
		"the act's checkpoints fire once each, in order (%s)" % [seen]
	)
	await _saving(tree, saves, logic, expect)

	runner.load_act(0)
	await tree.physics_frame


## Every one of the act's three obstacles is the correct end state of the last
## thing Emil did. That is the subject of the act and it is worth asserting.
func _as_emil_left_it(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, expect: RefCounted
) -> void:
	await tree.physics_frame
	var valve: DeviceValve = plant.get_node("DayTankValve")
	var transfer: DeviceSelector = plant.get_node("TransferSwitch")
	expect.ok(not valve.open, "the day tank is isolated, as it is after every monthly run")
	expect.ok(transfer.at(&"TEST"), "the transfer switch is in TEST, where the exercise left it")
	expect.ok(not plant.get_node("SetMain").on, "and the set main is open")
	expect.ok(not logic.running(), "so nothing is running")
	expect.ok(not logic.live(), "and the bus is dead")


func _the_set_will_not_fire(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, expect: RefCounted
) -> void:
	plant.get_node("Starter/Zone").engage()
	for frame in 240:
		await tree.physics_frame
	expect.ok(not logic.running(), "it cranks with the tank shut and does not catch")


func _the_fuel(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, expect: RefCounted
) -> void:
	var valve: DeviceValve = plant.get_node("DayTankValve")
	for turn in valve.turns_to_open:
		valve.get_node("Zone").engage()
	expect.ok(valve.open, "three turns opens the isolating valve")

	plant.get_node("Starter/Zone").engage()
	for frame in 240:
		await tree.physics_frame
		if logic.running():
			break
	expect.ok(logic.running(), "and now it catches")


## The set runs and the bus stays dead, because TEST is the position that runs
## the engine without connecting it.
func _test_is_not_emergency(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, expect: RefCounted
) -> void:
	var main_breaker: DeviceToggle = plant.get_node("SetMain")
	main_breaker.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(main_breaker.on, "the set main closes")
	expect.ok(not logic.live(), "and the bus is still dead, because the switch is in TEST")

	plant.get_node("TransferSwitch/Zone").engage()
	await tree.physics_frame
	expect.ok(
		(plant.get_node("TransferSwitch") as DeviceSelector).at(&"EMERGENCY"),
		"one step reaches EMERGENCY"
	)
	expect.ok(logic.live(), "and the bus picks up")


## Everything is still switched in, which is 38.4 kW on a 30 kW set.
func _too_much_load(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, breakers: Node3D,
	trips: Array[String], expect: RefCounted
) -> void:
	expect.near(
		float(logic.probe()["load_kw"]), 38.4, 0.05,
		"with everything still switched in"
	)
	for frame in PATIENCE:
		await tree.physics_frame
		if not logic.live():
			break
	expect.ok(not logic.live(), "the set drops it")
	expect.ok(not plant.get_node("SetMain").on, "by opening its own main, which is legible at the panel")
	expect.ok(trips.size() == 1 and trips[0].contains("8.4"), "and it says how much was too much (%s)" % [trips])


## The obvious first move: shed the one big load. It works. Then the sump starts.
func _the_obvious_answer_fails(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, breakers: Node3D,
	trips: Array[String], expect: RefCounted
) -> void:
	(breakers.get_node("Heater") as DeviceToggle).get_node("Zone").engage()
	plant.get_node("SetMain/Zone").engage()
	await tree.physics_frame
	expect.ok(logic.live(), "shedding the heater and re-closing brings the bus back")

	# Long enough to be past the four seconds a continuous overload takes.
	for frame in 400:
		await tree.physics_frame
	expect.ok(logic.live(), "and it holds, because 29.4 kW is inside the rating")

	for frame in PATIENCE:
		await tree.physics_frame
		if not logic.live():
			break
	expect.ok(not logic.live(), "until the float calls for the sump, and the start drops it")
	expect.ok(
		trips.size() == 2 and trips[1].contains("sump"),
		"which is a different failure from the first, and says so (%s)" % [trips]
	)
	expect.ok(not logic.probe()["sump"], "the sump never ran")


func _shedding_enough(
	tree: SceneTree, logic: ShelterLogic, plant: Node3D, breakers: Node3D, expect: RefCounted
) -> void:
	(breakers.get_node("Mess") as DeviceToggle).get_node("Zone").engage()
	plant.get_node("SetMain/Zone").engage()
	await tree.physics_frame
	expect.near(float(logic.probe()["load_kw"]), 24.2, 0.05, "shedding the galley as well leaves 24.2 kW")
	expect.ok(logic.live(), "the bus picks up")

	for frame in PATIENCE:
		await tree.physics_frame
		if logic.probe()["sump"]:
			break
	expect.ok(logic.live(), "and rides the sump starting")
	expect.ok(logic.probe()["sump"], "which runs")


func _the_way_on(
	tree: SceneTree, shelter: Node3D, logic: ShelterLogic, expect: RefCounted
) -> void:
	expect.ok(logic.probe()["stair"], "the stair drains")
	expect.ok(not shelter.get_node("StairWater").visible, "and the water is gone from it")
	expect.ok(shelter.get_node("AnnexDoor").open, "the annex door is found already open")
	expect.ok((shelter.get_node("Seam") as LightSeam).was_shown(), "and the seam happens, once")


## The set has a voice, and the voice is running because the set is.
##
## Checked on the playback head rather than a bus meter: an AudioStreamPlayer
## with no stream is silent, an AudioStreamPlayer that finished is silent, and
## a bus peak of zero in a headless run means nothing at all. `playing` is the
## only one of the three that is a fact about this act.
func _the_set_is_heard(shelter: Node3D, expect: RefCounted) -> void:
	var diesel: AudioStreamPlayer3D = shelter.get_node("Plant/Diesel")
	expect.ok(diesel.stream != null, "the set has a sound")
	expect.ok(diesel.playing, "and it is running, because the set is")
	expect.ok(
		(diesel.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"and it loops, rather than playing once and leaving the room silent"
	)
	var crank: AudioStreamPlayer3D = shelter.get_node("Plant/Crank")
	var caught: AudioStreamPlayer3D = shelter.get_node("Plant/Catch")
	expect.ok(
		crank.stream != null and caught.stream != null and crank.stream != caught.stream,
		"and cranking without fuel is a different sound from catching"
	)


## The act's own state, not its devices'. Same sweep as Act 1: every saveable
## node is fed a state it does not have, and has to notice.
func _saving(
	tree: SceneTree, saves: SaveService, logic: ShelterLogic, expect: RefCounted
) -> void:
	expect.ok(saves.save_to(SaveService.MANUAL), "the act saves")
	var stored: Dictionary = JSON.parse_string(Storage.read("save." + SaveService.MANUAL))
	expect.eq(int(stored.get("act", -1)), 1, "and records which act it was in")

	logic.load_state({"running": false, "live": false, "sump": false, "reached": []})
	await tree.physics_frame
	expect.ok(not logic.live(), "the act's own state can be cleared")

	expect.ok(saves.load_from(SaveService.MANUAL), "and the slot loads")
	await tree.physics_frame
	expect.ok(logic.live(), "bringing the bus back")
	expect.ok(logic.probe()["sump"], "and the sump that had run")
	saves.erase(SaveService.MANUAL)
