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
