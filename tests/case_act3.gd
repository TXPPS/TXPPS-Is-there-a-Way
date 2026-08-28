extends RefCounted

## Act 3, from the observer station to the reel.
##
## Same job as `case_act1` and `case_act2`: is it finishable. What is different
## about this one is that the act does not have its own scene -- the annex is
## rooms inside Act 2's, because P3.3 sends the player back to Act 2's panel and
## that only means anything if it is the same panel (D28). So this case walks
## *between* two logics over one building, which is exactly the seam most likely
## to be wrong.
##
## It also walks the wrong answer again: shedding the chamber luminaires alone
## looks like enough and is not, and the failure is a trip the player already
## knows from Act 2.

const PATIENCE := 900


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var runner: ActRunner = main.get_node("Acts")
	runner.load_act(1)
	await tree.physics_frame

	var shelter: Node3D = main.get_node("Shelter")
	var annex: Node3D = shelter.get_node("Annex")
	var logic: AnnexLogic = annex.get_node("Logic")
	var power: ShelterLogic = shelter.get_node("Logic")
	var breakers: Node3D = shelter.get_node("Panel/Breakers")

	var seen: Array[String] = []
	logic.checkpoint_reached.connect(func(id: String) -> void: seen.append(id))
	var trips: Array[String] = []
	power.bus_tripped.connect(func(why: String) -> void: trips.append(why))

	await _the_power_first(tree, power, shelter, breakers, expect)
	await _the_interlock_holds(tree, annex, logic, expect)
	await _the_cam(tree, annex, logic, expect)
	await _the_meter_and_the_lamp(tree, main, annex, expect)
	await _the_library_is_behind_the_flood(tree, main, annex, logic, expect)
	await _the_tank_refuses(tree, annex, logic, power, breakers, trips, expect)
	await _the_tank_drains(tree, annex, logic, power, breakers, expect)
	_the_annex_is_heard(annex, expect)
	await _the_observer_is_here(tree, main, annex, breakers, expect)
	await _the_reel(tree, main, annex, logic, expect)

	expect.ok(
		seen == ["chamber", "tank", "observed", "reel"],
		"the act's checkpoints fire once each, in order (%s)" % [seen]
	)

	# The photometer is in the player's hand and the player is not part of the
	# act, so it would walk out of here into the next case. A case that changes
	# the world puts it back.
	var hands: Hands = main.get_node("Player/Head/Camera/Hands")
	hands.drop()
	await tree.physics_frame

	runner.load_act(0)
	await tree.physics_frame


## Act 3 stands on Act 2: no power, no interlock, no sump, no light. Getting
## there is Act 2's business and `case_act2` walks it, so this only sets it up.
##
## Set rather than pressed, and deliberately. An act you left is now as you left
## it (`ActRunner` stashes it), so this case can arrive to a shelter that
## `case_act2` already solved or to one nobody has touched, depending on what
## ran before it. A setup that pressed buttons would toggle a solved act back
## into an unsolved one -- which is exactly what it did the first time this ran.
func _the_power_first(
	tree: SceneTree, power: ShelterLogic, shelter: Node3D, breakers: Node3D,
	expect: RefCounted
) -> void:
	var plant: Node3D = shelter.get_node("Plant")
	(plant.get_node("DayTankValve") as DeviceValve).open = true
	(plant.get_node("TransferSwitch") as DeviceSelector).select(&"EMERGENCY")
	for name in ["Heater", "Mess"]:
		(breakers.get_node(name) as DeviceToggle).on = false
	for name in ["Sump", "AnnexLighting", "ShelterLighting", "Chambers", "Vent",
			"Recorders", "Well"]:
		(breakers.get_node(name) as DeviceToggle).on = true
	(plant.get_node("SetMain") as DeviceToggle).on = true

	if not power.running():
		plant.get_node("Starter/Zone").engage()
		for frame in 240:
			await tree.physics_frame
			if power.running():
				break
	# Nudge the act into reassessing now that everything is where it should be.
	(plant.get_node("SetMain") as DeviceToggle).on = false
	await tree.physics_frame
	(plant.get_node("SetMain") as DeviceToggle).on = true
	for frame in PATIENCE:
		await tree.physics_frame
		if power.probe()["sump"] and power.live():
			break
	expect.ok(power.live(), "the bus is up before Act 3 starts")
	expect.ok(power.probe()["stair"], "and the stair to the annex has drained")


## P3.1. Protocol 4.4 made physical: it will not let the key go while chamber
## B's circuit is energised.
func _the_interlock_holds(
	tree: SceneTree, annex: Node3D, logic: AnnexLogic, expect: RefCounted
) -> void:
	var clock: Timeclock = annex.get_node("Timeclock")
	var interlock: DeviceInterlock = annex.get_node("Interlock")
	clock.load_state({"digits": [6, 3, 0]})
	await tree.physics_frame

	expect.ok(clock.lit(&"B"), "the drum says 06:00 and chamber B's cam covers it")
	interlock.get_node("Zone").engage()
	expect.ok(not logic.key_out(), "so the interlock keeps its key")


## Turn the drum, or cut the cam. Either works, and the notes give the rule.
func _the_cam(
	tree: SceneTree, annex: Node3D, logic: AnnexLogic, expect: RefCounted
) -> void:
	var clock: Timeclock = annex.get_node("Timeclock")
	var interlock: DeviceInterlock = annex.get_node("Interlock")

	clock.load_state({"digits": [8, 3, 0]})
	await tree.physics_frame
	expect.ok(not clock.lit(&"B"), "move the drum past the window and the lamp goes out")

	interlock.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(logic.key_out(), "and the key comes out")
	expect.ok(
		not annex.get_node("LampChamberB").lit,
		"with chamber B dark, which is what the interlock was waiting for"
	)


## P3.2. The instrument, and the number that makes the seam evidence.
func _the_meter_and_the_lamp(
	tree: SceneTree, main: Node, annex: Node3D, expect: RefCounted
) -> void:
	var player: Player = main.get_node("Player")
	var hands: Hands = player.get_node("Head/Camera/Hands")
	var meter: CarriedTool = annex.get_node("Photometer")

	meter.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(hands.holding() == meter, "the photometer is in chamber B and comes with you")
	expect.ok(meter.readout().ends_with("lx"), "and it reads in lux (%s)" % meter.readout())

	# Standing under a lit fitting reads more than standing in the dark. That is
	# the whole instrument, and it is the only thing it has to be right about.
	player.global_position = Vector3(0.0, 0.1, -16.05)
	await tree.physics_frame
	for frame in 40:
		await tree.physics_frame
	var lit_reading := (meter.get_node("Meter") as Photometer).lux()

	for node in tree.get_nodes_in_group(&"bulkhead_lamp"):
		(node as BulkheadLamp).lit = false
	for frame in 40:
		await tree.physics_frame
	var dark_reading := (meter.get_node("Meter") as Photometer).lux()
	expect.ok(
		dark_reading < lit_reading,
		"and it reads less in the dark than under a fitting (%.0f vs %.0f lx)"
			% [dark_reading, lit_reading]
	)


## P3.3 has to be *in the way*, not beside it.
##
## The flood is a door, not the water: the water is deliberately not solid,
## because the drain valve is on the far wall of the tank room and the player
## has to be able to wade to it. Which meant that for a while they could wade
## straight on through to the library, take Reel 9-C, and never meet the act's
## central puzzle at all.
func _the_library_is_behind_the_flood(
	tree: SceneTree, main: Node, annex: Node3D, logic: AnnexLogic, expect: RefCounted
) -> void:
	var door: DeviceDoor = annex.get_node("LibraryDoor")
	expect.ok(not logic.drained(), "the tank room is still flooded")
	expect.ok(not door.open, "so the door to the library is shut")

	# Shut means shut: the leaf carries its own collider, so a ray that would
	# reach the shelf hits the door instead. Anything that can walk to the reels
	# can also see them.
	var player: Player = main.get_node("Player")
	player.global_position = Vector3(-11.9, 0.1, -17.6)
	player.face(0.0, 0.0)
	await tree.physics_frame
	await tree.physics_frame
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(-11.9, 1.6, -17.6), Vector3(-11.9, 1.6, -21.5), 1
	)
	expect.ok(
		not space.intersect_ray(query).is_empty(),
		"and there is something solid between the player and the tape library"
	)


## P3.3, the wrong way. Shedding the chamber luminaires looks like enough.
func _the_tank_refuses(
	tree: SceneTree, annex: Node3D, logic: AnnexLogic, power: ShelterLogic,
	breakers: Node3D, trips: Array[String], expect: RefCounted
) -> void:
	if not power.live():
		return
	expect.ok(not logic.drained(), "the tank room is flooded")

	(breakers.get_node("Chambers") as DeviceToggle).get_node("Zone").engage()
	await tree.physics_frame
	(annex.get_node("TankDrain") as DeviceToggle).get_node("Zone").engage()
	await tree.physics_frame

	expect.ok(not logic.drained(), "shedding the chamber lamps is not enough")
	expect.ok(not power.live(), "the set drops trying to start against the tank")
	expect.ok(
		not trips.is_empty() and trips[-1].contains("tank"),
		"and says which start it was (%s)" % [trips]
	)


## P3.3, the way that works, and the thesis: progress costs light.
func _the_tank_drains(
	tree: SceneTree, annex: Node3D, logic: AnnexLogic, power: ShelterLogic,
	breakers: Node3D, expect: RefCounted
) -> void:
	var annex_bank: DeviceToggle = breakers.get_node("AnnexLighting")
	annex_bank.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(not annex_bank.on, "take the annex bank off as well")

	var main_breaker: DeviceToggle = annex.get_parent().get_node("Plant/SetMain")
	if not main_breaker.on:
		main_breaker.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(power.live(), "and the bus comes back")

	var drain: DeviceToggle = annex.get_node("TankDrain")
	if drain.on:
		drain.get_node("Zone").engage()
		await tree.physics_frame
	drain.get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(logic.drained(), "the sump starts and the tank room drains")
	expect.ok(not annex.get_node("TankWater").visible, "and the water is gone")
	expect.ok(
		(annex.get_node("LibraryDoor") as DeviceDoor).open,
		"and the way to the library opens, which is what the puzzle was for"
	)
	expect.ok(
		not annex.get_node("TubeLibrary").lit,
		"in a corridor you have just put the lights out in, which is the price"
	)


## The annex sounds like a hole in rock, and somebody left a transport threaded.
func _the_annex_is_heard(annex: Node3D, expect: RefCounted) -> void:
	expect.ok(
		(annex.get_node("Air") as AudioStreamPlayer3D).playing,
		"the annex has air of its own, deader and lower than the shelter's"
	)
	expect.ok(
		(annex.get_node("TapeDeck") as AudioStreamPlayer3D).playing,
		"and a tape transport somebody left running"
	)
	var detent: AudioStreamPlayer3D = annex.get_node("Timeclock/Detent")
	expect.ok(
		detent.stream != null,
		"the cam drum has a detent, because counting teeth by ear is the puzzle"
	)


## The entity, in a level for the first time. Not a puzzle and not a threat with
## a health bar: a rule, running, in a room with lamps in it.
##
## The point of this check is that it is *live* -- bound to the player, driven by
## the same practicals the photometer counts, and reporting to the fear state.
## An Observer that is in the scene and never wakes up is scenery.
func _the_observer_is_here(
	tree: SceneTree, main: Node, annex: Node3D, breakers: Node3D, expect: RefCounted
) -> void:
	var entity: Observer = annex.get_node("Observer")
	var player: Player = main.get_node("Player")
	var fear: FearState = main.get_node("Fear")

	# Put a light back on: the annex bank went off to drain the tank, and the
	# entity cannot cross unlit space -- which is the bargain P3.3 just made.
	#
	# The chamber luminaires, specifically. It stands only at a lamp that casts,
	# and C-1 is the only thing in the annex that does -- which is not a
	# convenience, it is the reason the programme's own fittings are the ones
	# the entity travels between.
	var bank: DeviceToggle = breakers.get_node("Chambers")
	if not bank.on:
		bank.get_node("Zone").engage()
	(annex.get_node("Timeclock") as Timeclock).load_state({"digits": [6, 3, 0]})
	player.global_position = Vector3(0.0, 0.1, -16.05)
	for frame in 8:
		await tree.physics_frame

	expect.ok(entity.present(), "with a fitting lit, it is standing on the line")
	expect.ok(
		String(entity.probe()["lamp"]) != "",
		"at a lamp it chose for itself (%s)" % entity.probe()["lamp"]
	)

	var before := fear.parts()["proximity"] as float
	for frame in 60:
		await tree.physics_frame
	expect.ok(
		(fear.parts()["proximity"] as float) > before,
		"and the fear number is hearing about it"
	)

	# Protocol 4.4, and Ending A. Letting it arrive *is* the final observation:
	# it does not attack, it reaches you, and reaching you is the whole event.
	# The control house is two acts away and will read this.
	var run: RunState = main.get_node("Run")
	run.load_state({})
	for frame in PATIENCE:
		await tree.physics_frame
		if run.run_concluded():
			break
	expect.ok(
		run.run_concluded(),
		"stand still and let it close over you, and the run is concluded"
	)
	expect.ok(
		String(entity.probe()["lamp"]) != "",
		"which happened at a lamp, because that is the only place it happens"
	)

	# The bargain, stated as a check: the schedule luminaire is its road.
	bank.get_node("Zone").engage()
	for frame in 4:
		await tree.physics_frame
	expect.ok(
		not entity.present(),
		"put the chamber lamps out and there is no line for it to stand on"
	)


## P3.4. Four hundred reels, one deduction, and the end of what is built.
func _the_reel(
	tree: SceneTree, main: Node, annex: Node3D, logic: AnnexLogic, expect: RefCounted
) -> void:
	var reels: Node3D = annex.get_node("Reels")
	expect.ok(reels.get_child_count() >= 6, "the shelf is in accession order")

	(reels.get_node("RF0838") as DevicePush).get_node("Zone").engage()
	await tree.physics_frame
	expect.ok(
		logic.probe()["reel"] == "",
		"the wrong reel costs nothing and is not the one"
	)

	(reels.get_node("RF0840") as DevicePush).get_node("Zone").engage()
	await tree.physics_frame
	expect.eq(String(logic.probe()["reel"]), "RF-0840", "RF-0840 is Run 9, box C")

	var reader: Reader = main.get_node("Reader")
	for frame in 400:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "and taking it ends what is built")
	reader.close()
	await tree.process_frame
	await tree.process_frame
