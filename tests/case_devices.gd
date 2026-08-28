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


func run(tree: SceneTree, _main: Node, expect: RefCounted) -> void:
	await _valve_takes_several_turns(tree, expect)
	await _valve_closes_the_way_it_opened(tree, expect)
	await _selector_walks_its_plate(tree, expect)
	await _selector_survives_a_bad_save(tree, expect)


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
