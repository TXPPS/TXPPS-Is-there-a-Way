extends RefCounted

## The two devices Act 2 adds, on their own, before a level depends on them.
##
## Both are built out of nothing but a transform and a signal, so they are cheap
## to get subtly wrong in a way no screenshot shows: a wheel that reports open
## on the turn before it is, a selector that runs off the end of its own plate.
## They are tested here rather than through the act because a failure here
## should name the device, not the puzzle that happened to use it.

const VALVE := preload("res://src/world/devices/device_valve.tscn")
const SELECTOR := preload("res://src/world/devices/device_selector.tscn")

## Act 2's distribution panel, as nameplates: running kW, then starting kW.
## These are the numbers on the props, and the puzzle is only as good as they
## are -- so they are asserted here rather than trusted to a scene file.
const PANEL := {
	"Sump": [6.9, 26.0],
	"AnnexLighting": [4.4, 0.0],
	"ShelterLighting": [2.6, 0.0],
	"Mess": [5.2, 0.0],
	"Vent": [2.8, 8.4],
	"Chambers": [2.5, 0.0],
	"Recorders": [3.1, 0.0],
	"Well": [1.9, 7.6],
	"Heater": [9.0, 0.0],
}


func run(tree: SceneTree, _main: Node, expect: RefCounted) -> void:
	await _valve_takes_several_turns(tree, expect)
	await _valve_closes_the_way_it_opened(tree, expect)
	await _selector_walks_its_plate(tree, expect)
	await _selector_survives_a_bad_save(tree, expect)
	_the_load_budget(expect)


# --- P2.3, as arithmetic ----------------------------------------------------

## The whole of Act 2's central puzzle, with no level and no player in it.
##
## What is being protected here is the *shape* of the puzzle rather than any one
## answer: that shedding nothing fails on the continuous rating, that shedding
## the single biggest load -- which is what anyone tries first -- holds and then
## dies when the sump starts, and that there is a wide budget rather than one
## combination. Change a nameplate on a prop and this is what notices.
func _the_load_budget(expect: RefCounted) -> void:
	expect.near(ShelterLoad.CAPACITY_KW, 30.0, 0.001, "the set is the 30 kW on its plate")
	expect.near(ShelterLoad.PEAK_KW, 45.0, 0.001, "and rides 150% of it for a moment")

	var all_on := _panel([])
	expect.near(ShelterLoad.running(all_on), 38.4, 0.05, "everything at once is 38.4 kW")
	expect.ok(not ShelterLoad.carries(all_on), "which the set will not carry")
	expect.near(ShelterLoad.overload_kw(all_on), 8.4, 0.05, "and it says how much is too much")

	# The obvious first move: shed the one big load. It works, right up until
	# the float calls for the sump.
	var heater_off := _panel(["Heater"])
	expect.near(ShelterLoad.running(heater_off), 29.4, 0.05, "shedding the heater gets under the rating")
	expect.ok(ShelterLoad.carries(heater_off), "so the bus picks up and holds")
	expect.near(
		ShelterLoad.inrush(heater_off, _breaker_named(heater_off, "Sump")), 48.5, 0.05,
		"but the sump starting asks for 48.5 kW"
	)
	expect.ok(
		not ShelterLoad.survives_start(heater_off, _breaker_named(heater_off, "Sump")),
		"which drops it -- an allocation that boots is not one that holds"
	)

	var enough := _panel(["Heater", "Mess"])
	expect.ok(ShelterLoad.carries(enough), "shedding the galley as well carries")
	expect.ok(
		ShelterLoad.survives_start(enough, _breaker_named(enough, "Sump")),
		"and survives the start"
	)

	# A sump that is switched out cannot surge, so the start is a non-event.
	var no_sump := _panel(["Sump"])
	expect.near(
		ShelterLoad.inrush(no_sump, _breaker_named(no_sump, "Sump")),
		ShelterLoad.running(no_sump), 0.001,
		"a breaker that is open contributes no inrush"
	)

	var ways := _winning_allocations()
	expect.ok(
		ways >= 40,
		"there is a budget to spend rather than one right answer (%d ways)" % ways
	)

	for panel in [all_on, heater_off, enough, no_sump]:
		_discard(panel)


## Every allocation that keeps the sump and the annex lit -- the two the act
## needs -- and survives. Counted rather than asserted one by one, because the
## design's claim is about how many there are.
func _winning_allocations() -> int:
	var optional := ["ShelterLighting", "Mess", "Vent", "Chambers", "Recorders", "Well", "Heater"]
	var wins := 0
	for mask in range(1 << optional.size()):
		var shed: Array[String] = []
		for bit in optional.size():
			if (mask & (1 << bit)) != 0:
				shed.append(optional[bit])
		var panel := _panel(shed)
		if ShelterLoad.carries(panel) and ShelterLoad.survives_start(panel, _breaker_named(panel, "Sump")):
			wins += 1
		_discard(panel)
	return wins


## A throwaway panel of breakers, with the named ones switched out. Real
## DeviceToggles rather than a stub, so the arithmetic is exercised through the
## same property the scene sets.
func _panel(shed: Array) -> Array:
	var made: Array = []
	for key in PANEL:
		var breaker := DeviceToggle.new()
		breaker.name = key
		breaker.save_key = StringName(key)
		breaker.load_kw = PANEL[key][0]
		breaker.surge_kw = PANEL[key][1]
		breaker.on = not shed.has(key)
		made.append(breaker)
	return made


## Breakers made with `new()` are Nodes that never entered the tree, so nothing
## else will ever free them. 128 panels of nine is not a rounding error.
func _discard(panel: Array) -> void:
	for node in panel:
		(node as Node).free()


func _breaker_named(panel: Array, key: String) -> DeviceToggle:
	for node in panel:
		if (node as DeviceToggle).name == key:
			return node
	return null


func _valve_takes_several_turns(tree: SceneTree, expect: RefCounted) -> void:
	var valve: DeviceValve = VALVE.instantiate()
	valve.turns_to_open = 3
	tree.root.add_child(valve)
	await tree.process_frame

	expect.ok(not valve.open, "a valve starts shut")
	expect.eq(valve.remaining(), 3, "and says how far it has to go")

	var opened := [0]
	valve.opened.connect(func() -> void: opened[0] += 1)

	valve.get_node("Zone").engage()
	expect.ok(not valve.open, "one turn does not open it")
	valve.get_node("Zone").engage()
	expect.ok(not valve.open, "nor does two")
	expect.eq(valve.remaining(), 1, "with one turn left to go")

	valve.get_node("Zone").engage()
	expect.ok(valve.open, "the third turn opens it")
	expect.eq(opened[0], 1, "and says so exactly once")

	valve.queue_free()
	await tree.process_frame


## A handwheel does not latch. Turning past open winds it shut again, and the
## count has to run back down rather than start over -- otherwise a player who
## nudges it once has silently thrown away three turns of progress.
func _valve_closes_the_way_it_opened(tree: SceneTree, expect: RefCounted) -> void:
	var valve: DeviceValve = VALVE.instantiate()
	valve.turns_to_open = 3
	tree.root.add_child(valve)
	await tree.process_frame
	valve.open = true

	var closed := [0]
	valve.closed.connect(func() -> void: closed[0] += 1)

	expect.eq(valve.remaining(), 3, "an open valve is three turns from shut")
	valve.get_node("Zone").engage()
	expect.ok(valve.open, "one turn back does not shut it")
	expect.eq(valve.remaining(), 2, "it just unwinds")

	valve.get_node("Zone").engage()
	valve.get_node("Zone").engage()
	expect.ok(not valve.open, "the third turn back shuts it")
	expect.eq(closed[0], 1, "once")

	var kept := valve.save_state()
	valve.open = true
	valve.load_state(kept)
	expect.ok(not valve.open, "and a save remembers which way it was left")

	valve.queue_free()
	await tree.process_frame


func _selector_walks_its_plate(tree: SceneTree, expect: RefCounted) -> void:
	var switch: DeviceSelector = SELECTOR.instantiate()
	tree.root.add_child(switch)
	await tree.process_frame

	expect.ok(switch.at(&"NORMAL"), "a selector starts on its first position")

	var seen: Array[StringName] = []
	switch.moved.connect(func(name: StringName) -> void: seen.append(name))

	switch.get_node("Zone").engage()
	expect.ok(switch.at(&"TEST"), "one step reaches the second")
	switch.get_node("Zone").engage()
	expect.ok(switch.at(&"EMERGENCY"), "another reaches the third")
	switch.get_node("Zone").engage()
	expect.ok(
		switch.at(&"NORMAL"),
		"and the fourth wraps rather than stranding a player who overshot (%s)" % switch.selected()
	)
	expect.eq(seen.size(), 3, "each step announces where it landed")

	expect.ok(switch.select(&"EMERGENCY"), "a position can be set by name")
	expect.ok(switch.at(&"EMERGENCY"), "and it goes there")
	expect.ok(not switch.select(&"OFF"), "a name that is not on the plate is refused")
	expect.ok(switch.at(&"EMERGENCY"), "and changes nothing")

	switch.queue_free()
	await tree.process_frame


## A save from a build whose switch had more positions must not leave the handle
## pointing at a position this build does not have.
func _selector_survives_a_bad_save(tree: SceneTree, expect: RefCounted) -> void:
	var switch: DeviceSelector = SELECTOR.instantiate()
	tree.root.add_child(switch)
	await tree.process_frame

	switch.load_state({"index": 9})
	expect.ok(
		switch.selected() in switch.positions,
		"an index off the end of the plate still lands on a real position (%s)" % switch.selected()
	)
	switch.load_state({"index": -4})
	expect.ok(
		switch.selected() in switch.positions,
		"and so does a negative one (%s)" % switch.selected()
	)

	switch.queue_free()
	await tree.process_frame
