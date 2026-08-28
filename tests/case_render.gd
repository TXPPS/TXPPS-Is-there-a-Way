extends RefCounted

## The post stack and the fear state.
##
## Nothing here is about how it looks -- swiftshader cannot say and a headless
## runner has no eyes. It is about the wiring: that the shader has the LUT, that
## the accessibility setting reaches the uniforms it is supposed to, that fear
## moves grain in the direction and by the amount claimed, and that the fear
## number can never leave 0..1 however it is provoked.
##
## What it looks like is `docs/shots/`, and whether that is right is
## `NEEDS_DEVICE_QA.md`.


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var post: PostStack = main.get_node("PostStack")
	var fear: FearState = main.get_node("Fear")
	var settings: GameSettings = main.get_node("Settings")

	await _wiring(tree, post, expect)
	await _reduce_motion(tree, post, settings, expect)
	await _fear_drives_grain(tree, post, expect)
	await _fear_state(tree, fear, expect)
	await _the_act_chooses_the_grade(tree, main, post, expect)
	await _the_tube_flickers(tree, expect)


## The palette shift from sodium to fluorescent is what tells the player they
## have left the dam and entered the programme, so it belongs to the act rather
## than to a setting -- and an act that names a grade nobody wrote must fail
## loudly rather than washing out to nothing.
func _the_act_chooses_the_grade(
	tree: SceneTree, main: Node, post: PostStack, expect: RefCounted
) -> void:
	var runner: ActRunner = main.get_node("Acts")
	expect.eq(String(post.grade()), "act1", "the dam is graded as the dam")

	post.set_grade(&"annex")
	expect.eq(String(post.grade()), "annex", "and the annex grade can be loaded")
	var loaded: Texture2D = (post.get_node("Screen").material as ShaderMaterial) \
		.get_shader_parameter("grade_lut")
	expect.ok(loaded != null, "with a lookup table actually in the shader")
	expect.eq(loaded.get_width(), 256, "256 wide: sixteen slices of sixteen")
	expect.eq(loaded.get_height(), 16, "and sixteen tall")

	post.set_grade(&"nothing_wrote_this")
	expect.eq(
		String(post.grade()), "annex",
		"a grade nobody wrote is refused, and the last good one stays"
	)

	# The guard above keeps a typo from washing an act out to nothing. This is
	# what keeps the typo from being shipped in the first place.
	for index in runner.acts.size():
		var act := runner.acts[index].instantiate()
		var named := String(act.get_meta(&"grade", "act1"))
		expect.ok(
			ResourceLoader.exists("res://assets/luts/%s.png" % named),
			"act %d asks for a grade that exists ('%s')" % [index, named]
		)
		act.free()

	# Remounting the act puts its own grade back, which is the path that runs
	# in play -- nothing calls set_grade by hand.
	runner.load_act(1)
	await tree.physics_frame
	expect.eq(String(post.grade()), "act1", "the shelter is still the dam's palette")
	runner.load_act(0)
	await tree.physics_frame
	await _the_threshold_changes_the_colour(tree, main, post, expect)


## The palette shift belongs to a doorway, not to a load. See DECISIONS.md D28:
## the annex is rooms inside Act 2's scene, because P3.3 sends the player back
## to Act 2's panel and that only means anything if it is the same panel.
func _the_threshold_changes_the_colour(
	tree: SceneTree, main: Node, post: PostStack, expect: RefCounted
) -> void:
	var player: Player = main.get_node("Player")
	var zone := GradeZone.new()
	zone.grade = &"annex"
	zone.collision_layer = 0
	zone.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 4.0)
	shape.shape = box
	zone.add_child(shape)
	main.add_child(zone)
	zone.global_position = Vector3(-6.0, 1.0, -2.5)
	await tree.physics_frame

	expect.eq(String(post.grade()), "act1", "outside it, the act's own colour")

	player.global_position = Vector3(-6.0, 0.1, -2.5)
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(zone.inside(), "the player crosses the threshold")
	expect.eq(String(post.grade()), "annex", "and the colour changes with them")

	player.global_position = Vector3(-6.0, 0.1, 4.0)
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(not zone.inside(), "walk back out")
	expect.eq(
		String(post.grade()), "act1",
		"and the act's colour comes back -- the zone does not decide what is outside it"
	)

	zone.queue_free()
	await tree.process_frame


## A tired tube stumbles; a sodium lamp does not. The difference is most of what
## makes a fluorescent read as a fluorescent, and it is a number on the fitting
## rather than a different class.
func _the_tube_flickers(tree: SceneTree, expect: RefCounted) -> void:
	var tube: BulkheadLamp = load("res://src/world/kit/fluorescent.tscn").instantiate()
	var bulkhead: BulkheadLamp = load("res://src/world/kit/bulkhead_lamp.tscn").instantiate()
	tree.root.add_child(tube)
	tree.root.add_child(bulkhead)
	await tree.process_frame

	expect.ok(tube.flicker_depth > 0.0, "the tube is a fitting that flickers")
	expect.near(bulkhead.flicker_depth, 0.0, 0.001, "the sodium bulkhead is not")

	var seen: Array[float] = []
	for frame in 400:
		await tree.process_frame
		seen.append((tube.get_node("Light") as OmniLight3D).light_energy)
	var low: float = seen.min()
	var high: float = seen.max()
	expect.near(high, tube.energy, 0.01, "it burns at its rated output most of the time")
	expect.ok(low < tube.energy * 0.95, "and drops below it when it stumbles (%.2f)" % low)
	expect.ok(low > 0.0, "without ever going out, which would be a different fitting")

	var steady: Array[float] = []
	for frame in 200:
		await tree.process_frame
		steady.append((bulkhead.get_node("Light") as OmniLight3D).light_energy)
	expect.near(steady.min(), steady.max(), 0.001, "and the sodium lamp is rock steady")

	tube.queue_free()
	bulkhead.queue_free()
	await tree.process_frame


func _wiring(tree: SceneTree, post: PostStack, expect: RefCounted) -> void:
	var screen: ColorRect = post.get_node("Screen")
	var material := screen.material as ShaderMaterial
	expect.ok(material != null, "the post pass has a shader material")
	expect.ok(
		material.get_shader_parameter("grade_lut") != null,
		"and the act's grade LUT is bound to it"
	)
	expect.ok(post.layer == 0, "it sits below the HUD, so the interface is not graded")
	await tree.process_frame


func _reduce_motion(
	tree: SceneTree, post: PostStack, settings: GameSettings, expect: RefCounted
) -> void:
	settings.set_value(&"reduce_motion", 0.0)
	await tree.process_frame
	expect.ok(post.probe()["barrel"] > 0.0, "the lens is on by default")

	settings.set_value(&"reduce_motion", 1.0)
	await tree.process_frame
	var reduced := post.probe()
	expect.near(reduced["barrel"], 0.0, 0.0001, "reduce motion takes the barrel off")
	expect.ok(float(reduced["aniso"]) <= 1.0001, "and stops the grain stretching")
	expect.ok(
		float(reduced["dither"]) > 0.0,
		"but leaves the dither alone -- that is legibility, not motion"
	)
	settings.set_value(&"reduce_motion", 0.0)
	await tree.process_frame


func _fear_drives_grain(tree: SceneTree, post: PostStack, expect: RefCounted) -> void:
	post.set_fear(0.0)
	var calm := float(post.probe()["grain"])
	post.set_fear(1.0)
	var afraid := float(post.probe()["grain"])
	post.set_fear(0.5)
	var middle := float(post.probe()["grain"])
	expect.ok(afraid > calm, "grain rises with fear (%.4f -> %.4f)" % [calm, afraid])
	expect.ok(
		middle > calm and middle < afraid,
		"and does so smoothly rather than in a step (%.4f)" % middle
	)
	expect.ok(
		float(post.probe()["aniso"]) > 1.0,
		"and stretches as it rises"
	)
	post.set_fear(0.0)
	await tree.process_frame


func _fear_state(tree: SceneTree, fear: FearState, expect: RefCounted) -> void:
	# `main.gd` recomputes "am I standing in light" from the lit practicals on
	# every physics frame, so setting it here and hoping is not a test -- it is
	# a race the game wins. Put the building's lights out and mean it.
	var were: Dictionary = {}
	for node in tree.get_nodes_in_group(&"bulkhead_lamp"):
		var lamp := node as BulkheadLamp
		were[lamp] = lamp.lit
		lamp.lit = false

	fear.set_exposure(0.0)
	fear.set_in_light(true)
	for frame in 40:
		await tree.process_frame
	expect.near(fear.value(), 0.0, 0.02, "standing in light with nothing near is calm")

	fear.set_in_light(false)
	for frame in 60:
		await tree.process_frame
	var dark_part := float(fear.parts()["dark"])
	expect.ok(dark_part > 0.0, "the dark accrues (%.3f)" % dark_part)

	for lamp in were:
		(lamp as BulkheadLamp).lit = were[lamp]

	fear.report_seam(1.0)
	var spiked := fear.value()
	expect.ok(spiked > 0.3, "a seam at arm's length spikes it (%.3f)" % spiked)
	for frame in 60:
		await tree.process_frame
	expect.ok(fear.value() < spiked, "and the spike decays rather than latching")

	# Provoked from every direction at once, it still cannot leave the range the
	# consumers were promised.
	fear.set_exposure(5.0)
	fear.report_seam(5.0)
	fear.set_in_light(false)
	for frame in 5:
		await tree.process_frame
	expect.ok(fear.value() <= 1.0, "and it cannot exceed 1 however it is provoked")
	fear.set_exposure(0.0)
	fear.set_in_light(true)
	await tree.process_frame
