extends RefCounted

## The mix, asserted as numbers.
##
## A headless runner has no ears, so nothing here is about how it sounds. It is
## about whether the machinery moves: that the buses exist and the sliders reach
## them, that the score's layers come in where the tuning says, that a wall
## between a source and the listener is heard as a wall, that a room sets the
## reverb, and that a stride's worth of walking makes exactly one footstep.
##
## How it *sounds* is a device question and is queued in NEEDS_DEVICE_QA.md.

const STRIDE_PROBE := 3.0


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var score: AudioDirector = main.get_node("Score")
	var fear: FearState = main.get_node("Fear")
	var settings: GameSettings = main.get_node("Settings")
	var player: Player = main.get_node("Player")
	var hum: AudioStreamPlayer3D = main.get_node("GrayboxRoom/BulkheadLamp/Hum")

	_buses(expect)
	await _volumes(tree, settings, expect)
	await _score_layers(tree, score, fear, expect)
	await _occlusion(tree, player, hum, expect)
	await _reverb(tree, expect)
	await _footsteps(tree, player, expect)


func _buses(expect: RefCounted) -> void:
	for bus in [AudioBuses.MASTER, AudioBuses.SFX, AudioBuses.MUSIC, AudioBuses.VOICE]:
		expect.ok(AudioServer.get_bus_index(bus) >= 0, "the %s bus exists" % bus)
	expect.ok(AudioBuses.reverb() != null, "and SFX carries the one reverb in the mix")


func _volumes(tree: SceneTree, settings: GameSettings, expect: RefCounted) -> void:
	settings.set_value(&"volume_sfx", 1.0)
	await tree.process_frame
	expect.near(AudioBuses.volume_db(AudioBuses.SFX), 0.0, 0.1, "a slider at full is unity gain")
	settings.set_value(&"volume_sfx", 0.5)
	await tree.process_frame
	expect.near(
		AudioBuses.volume_db(AudioBuses.SFX), -6.02, 0.2,
		"and half is about six decibels down, not half a decibel"
	)

	AudioBuses.set_ducked(true)
	var ducked := AudioBuses.volume_db(AudioBuses.SFX)
	AudioBuses.set_ducked(false)
	var back := AudioBuses.volume_db(AudioBuses.SFX)
	expect.near(ducked, -6.02 + AudioBuses.PAUSE_DUCK_DB, 0.2, "the pause duck ducks")
	expect.near(back, -6.02, 0.2, "and comes all the way back off")

	# The bug this is really guarding: moving a slider while ducked must not
	# leave the duck welded into the level.
	AudioBuses.set_ducked(true)
	settings.set_value(&"volume_sfx", 0.8)
	AudioBuses.set_ducked(false)
	await tree.process_frame
	expect.near(
		AudioBuses.volume_db(AudioBuses.SFX), linear_to_db(0.8), 0.2,
		"a slider moved while ducked still ends up where it was put"
	)
	settings.set_value(&"volume_sfx", 1.0)
	await tree.process_frame


## The director is normally driven by FearState, which keeps announcing itself
## every frame. Setting the fear by hand while that is connected means the next
## frame overwrites it -- which is correct behaviour and makes the mix
## untestable, so the wire comes off for the duration and goes back on after.
func _score_layers(
	tree: SceneTree, score: AudioDirector, fear: FearState, expect: RefCounted
) -> void:
	fear.changed.disconnect(score.set_fear)
	score.set_fear(0.0)
	var calm := score.targets()
	expect.ok(calm["score_bed"] > 0.4, "the bed is always there (%.2f)" % calm["score_bed"])
	expect.near(calm["score_room"], 0.0, 0.001, "and nothing else is, at rest")
	expect.near(calm["score_strain"], 0.0, 0.001, "nor the strain layer")
	expect.near(calm["score_edge"], 0.0, 0.001, "nor the edge")

	score.set_fear(0.5)
	var uneasy := score.targets()
	expect.ok(uneasy["score_room"] > 0.8, "the room layer is up by halfway (%.2f)" % uneasy["score_room"])
	expect.ok(
		uneasy["score_strain"] > 0.0 and uneasy["score_strain"] < 0.8,
		"and the strain layer is on its way in rather than switched on (%.2f)" % uneasy["score_strain"]
	)
	expect.near(uneasy["score_edge"], 0.0, 0.001, "the edge holds back")

	score.set_fear(1.0)
	var afraid := score.targets()
	for layer in ["score_bed", "score_room", "score_strain", "score_edge"]:
		expect.ok(afraid[layer] > 0.4, "at full fear every layer is up (%s %.2f)" % [layer, afraid[layer]])

	# The glide is what stops the score narrating. It has to actually move -- and
	# it moves in wall-clock seconds, which a headless runner burns through far
	# faster than sixty a second, so this waits for movement rather than for a
	# frame count that would mean something on a device and nothing here.
	var before: float = score.probe()["score_edge"]
	var after := before
	for frame in 4000:
		await tree.process_frame
		after = score.probe()["score_edge"]
		if after > before:
			break
	expect.ok(after > before, "levels glide toward their target (%.3f -> %.3f)" % [before, after])
	# How long the glide takes is a wall-clock property, and a headless runner
	# burns through frames with whatever delta it likes -- so the duration is a
	# device-QA item and what is asserted here is the contract that produces it.
	expect.ok(
		score.tuning.glide_seconds >= 1.0,
		"and the tuning says take at least a second (%.1f s)" % score.tuning.glide_seconds
	)
	score.set_fear(0.0)
	fear.changed.connect(score.set_fear)


## A wall between a source and the ear has to be heard as a wall.
func _occlusion(
	tree: SceneTree, player: Player, hum: AudioStreamPlayer3D, expect: RefCounted
) -> void:
	var occluder: AudioOccluder = hum.get_node("Occluder")
	var home := hum.global_position
	player.global_position = Vector3(0.5, 0.0, 0.0)
	await tree.physics_frame
	for frame in 40:
		await tree.physics_frame
	expect.near(occluder.blockage(), 0.0, 0.05, "a clear path is not filtered")
	var open_hz := hum.attenuation_filter_cutoff_hz

	# Beyond the north wall: the ray now crosses 400 mm of concrete.
	hum.global_position = Vector3(0.5, 1.6, -6.0)
	for frame in 60:
		await tree.physics_frame
	expect.ok(occluder.blockage() > 0.8, "a wall in the way blocks (%.2f)" % occluder.blockage())
	expect.ok(
		hum.attenuation_filter_cutoff_hz < open_hz * 0.2,
		"and takes the top off (%.0f Hz from %.0f)" % [hum.attenuation_filter_cutoff_hz, open_hz]
	)

	hum.global_position = home
	for frame in 60:
		await tree.physics_frame
	expect.near(occluder.blockage(), 0.0, 0.05, "and it opens again when the wall goes")


func _reverb(tree: SceneTree, expect: RefCounted) -> void:
	for frame in 20:
		await tree.process_frame
	var effect := AudioBuses.reverb()
	expect.ok(effect.wet > 0.0, "the room has set a reverb the listener is standing in")
	expect.ok(
		effect.room_size > 0.5,
		"and it is the size of a powerhouse (%.2f)" % effect.room_size
	)


func _footsteps(tree: SceneTree, player: Player, expect: RefCounted) -> void:
	var feet: Footsteps = player.get_node("Footsteps")
	var heard: Array = []
	var listener := func(surface: SurfaceType, _at: Vector3, loudness: float) -> void:
		heard.append([surface.id, loudness])
	feet.stepped.connect(listener)
	await tree.physics_frame

	feet.advance(STRIDE_PROBE)
	expect.ok(heard.size() == 1, "a stride's worth of walking is one footstep, not three")
	expect.ok(
		heard.size() > 0 and heard[0][0] == &"concrete",
		"and it knows what it is standing on (%s)" % ("-" if heard.is_empty() else heard[0][0])
	)
	expect.ok(
		heard.size() > 0 and heard[0][1] > 0.0,
		"and carries the loudness P6's hearing model will want"
	)
	heard.clear()
	feet.advance(0.1)
	expect.ok(heard.is_empty(), "and standing still makes none")
	feet.stepped.disconnect(listener)
