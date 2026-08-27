extends RefCounted

## Settings persist the moment they change, survive a fresh load, and refuse
## values outside their own declared range.

const CHECKS: Dictionary = {
	&"look_sensitivity_x": 1.85,
	&"stick_deadzone": 0.22,
	&"invert_y": 1.0,
	&"look_style": 1.0,
	&"volume_music": 0.35,
	&"subtitle_size": 3.0,
}


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var settings: GameSettings = main.get_node("Settings")
	for key in CHECKS:
		settings.set_value(key, CHECKS[key])
	await tree.process_frame

	var reloaded := GameSettings.new()
	reloaded.spec = settings.spec
	tree.root.add_child(reloaded)
	await tree.process_frame
	for key in CHECKS:
		expect.near(reloaded.value(key), CHECKS[key], 0.0001, "'%s' survives a reload" % key)
	reloaded.queue_free()

	settings.set_value(&"look_sensitivity_x", 99.0)
	expect.near(
		settings.value(&"look_sensitivity_x"), 2.5, 0.0001,
		"a value past the maximum is clamped, not stored"
	)
	settings.set_value(&"stick_deadzone", -5.0)
	expect.near(settings.value(&"stick_deadzone"), 0.0, 0.0001, "a value below the minimum is clamped")
	settings.set_value(&"invert_y", 0.3)
	expect.near(settings.value(&"invert_y"), 0.0, 0.0001, "a toggle stores only 0 or 1")

	# An Array, because a lambda captures a local by value and would count into
	# its own copy.
	var live: Array[int] = [0]
	settings.changed.connect(func(_k: StringName, _v: float) -> void: live[0] += 1)
	settings.set_value(&"brightness", 1.25)
	expect.ok(live[0] == 1, "a change announces itself exactly once")
	settings.set_value(&"brightness", 1.25)
	expect.ok(live[0] == 1, "setting the same value again announces nothing")

	settings.reset_all()
	await tree.process_frame
	expect.near(settings.value(&"look_style"), 0.0, 0.0001, "reset returns the default look style")
