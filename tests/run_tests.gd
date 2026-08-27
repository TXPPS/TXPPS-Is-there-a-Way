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
	"res://tests/case_layout.gd",
	"res://tests/case_settings.gd",
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
	main.queue_free()
	await process_frame
	quit(code)
