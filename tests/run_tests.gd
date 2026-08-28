extends SceneTree

## Headless suite for everything a browser cannot see.
##
##   godot --headless --script res://tests/run_tests.gd
##
## Runs the real main scene with real input events rather than unit-testing the
## pieces in isolation, because every bug this suite exists to catch was an
## interaction between two controls that were each correct alone.
##
## The browser suites (tools/web/) cover what only a browser has: the service
## worker, storage, the shell. See docs/TESTING.md.

const EXPECT := preload("res://tests/expect.gd")
const DEVICE_POINTS := Vector2i(956, 440)
const CASES: Array[String] = [
	"res://tests/case_input.gd",
	"res://tests/case_pause.gd",
	"res://tests/case_interact.gd",
	"res://tests/case_layout.gd",
	"res://tests/case_settings.gd",
	"res://tests/case_save.gd",
	"res://tests/case_render.gd",
	"res://tests/case_audio.gd",
	"res://tests/case_devices.gd",
	"res://tests/case_reading.gd",
	"res://tests/case_act1.gd",
	"res://tests/case_act2.gd",
	"res://tests/case_observer.gd",
	"res://tests/case_reach.gd",
]


func _initialize() -> void:
	_run()


func _run() -> void:
	# Headless opens a placeholder window, and the stretch settings would then
	# scale it up to the design width -- making every layout assertion a
	# statement about a screen nobody has. iPhone 16 Pro Max landscape, in CSS
	# points, is the screen this game is being built for. Set after a frame,
	# because the window is still settling into its own size before one.
	await process_frame
	root.size = DEVICE_POINTS
	await process_frame
	print("viewport %s at %s points" % [root.get_visible_rect().size, root.size])
	var expect: RefCounted = EXPECT.new()
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for path in CASES:
		print("\n== %s" % path.get_file())
		var case: RefCounted = load(path).new()
		await case.run(self, main, expect)
	var code: int = expect.report("headless")
	# Stop every voice before tearing the tree down. The audio server mixes on
	# its own thread and briefly holds a reference to whatever is playing; freeing
	# the scene out from under it makes the engine report resources still in use
	# at exit, intermittently, which reads as a build failure and is not one.
	# Everything below the summary line is teardown. The audio server holds a
	# playback for a moment after a player stops, so freeing the tree races it
	# and the engine sometimes reports resources still in use at exit; letting
	# quit() do the teardown instead makes it report that every time. Neither is
	# a failure of the run, and tools/ci/build_web.sh only reads the part of this
	# log that was produced while the suite was running.
	_silence(main)
	await process_frame
	main.queue_free()
	for frame in 3:
		await process_frame
	quit(code)


## Stopping is not enough: a stopped player still holds its stream, and the
## audio server still holds the playback it made from it. Dropping the stream as
## well is what lets both go before the engine tears down and counts what is
## left.
func _silence(node: Node) -> void:
	if node is AudioStreamPlayer:
		var flat := node as AudioStreamPlayer
		flat.stop()
		flat.stream = null
	elif node is AudioStreamPlayer3D:
		var spatial := node as AudioStreamPlayer3D
		spatial.stop()
		spatial.stream = null
	for child in node.get_children():
		_silence(child)
