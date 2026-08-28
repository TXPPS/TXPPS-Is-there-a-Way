extends RefCounted

## The focused-interaction framework, through the puzzle it was built for.
##
## Targeting, engaging, gestures reaching the thing engaged with and nothing
## else, and getting back out. It used to run against a throwaway dial lock in
## Act 1's switchgear room -- a combination lock with no combination anywhere in
## the fiction, whose `solved` signal was connected to nothing. `PUZZLES.md`
## always said the annex timeclock replaced it, so the lock is gone and this
## runs against C-2, which has the same grammar and a reason to exist.

const TOUCH := preload("res://tests/touch.gd")
## In the observation corridor, a step off the north wall the clock is on.
const STAND_AT := Vector3(1.0, 0.1, -16.0)
const FACING := 0.0
## Slightly more than one click, so each drag lands exactly one step.
const STEP_TRAVEL := 47.0


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var hud: Hud = main.get_node("Hud")
	var player: Player = main.get_node("Player")
	var state: GameState = main.get_node("State")
	var rects: HudRects = hud.get_node("HudRects")
	var runner: ActRunner = main.get_node("Acts")
	runner.load_act(1)
	await tree.physics_frame
	var clock: Timeclock = main.get_node("Shelter/Annex/Timeclock")
	var interactor: Interactor = player.get_node("Head/Camera/Interactor")
	var camera: Camera3D = player.get_node("Head/Camera")
	var touch: RefCounted = TOUCH.new(tree.root)

	player.global_position = STAND_AT
	player.velocity = Vector3.ZERO
	# Earlier cases left the camera somewhere else entirely.
	player.face(deg_to_rad(FACING), 0.0)
	await tree.physics_frame
	await tree.physics_frame

	expect.ok(interactor.target() != null, "the ray finds the clock from a step away")
	expect.ok(hud.probe()["prompt"] == "Set the clock", "the prompt says what it offers")

	await _occlusion_is_respected(tree, hud, rects, interactor, expect)
	await _engaging(tree, touch, hud, state, expect)
	await _wheels_turn(tree, touch, camera, clock, expect)
	await _stepping_back(tree, touch, hud, state, interactor, expect)

	runner.load_act(0)
	await tree.physics_frame


## Nothing is offered through a control the player's thumb is already on.
func _occlusion_is_respected(
	tree: SceneTree, hud: Hud, rects: HudRects, interactor: Interactor, expect: RefCounted
) -> void:
	rects.reserve(&"test_cover", func() -> Rect2: return tree.root.get_visible_rect())
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(interactor.target() == null, "a target under a reserved rect is not offered")
	expect.ok(hud.probe()["prompt"] == "", "and the prompt goes with it")
	rects.release(&"test_cover")
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(interactor.target() != null, "uncovering it offers it again")


func _engaging(
	tree: SceneTree, touch: RefCounted, hud: Hud, state: GameState, expect: RefCounted
) -> void:
	var button: Control = hud.get_node("Controls/ActionButton")
	expect.ok(button.visible, "the action button appears with a target")
	touch.press(7, button.position)
	await tree.physics_frame
	touch.lift(7, button.position)
	await tree.physics_frame
	expect.ok(state.current == GameState.State.FOCUSED, "acting on it enters FOCUSED")
	expect.ok(hud.probe()["focused"] == true, "the HUD locks to the puzzle")
	expect.ok(
		not hud.get_node("Controls/MoveStick").visible,
		"the movement stick goes away while focused"
	)
	expect.ok(hud.probe()["prompt"] == "Step back", "the prompt offers the way out")


## Three wheels, each turned by a drag that starts on it. The numbers are the
## hour drum and two cam teeth, so getting the *wrong* wheel is not a cosmetic
## failure -- it is a chamber lit when it should be dark.
func _wheels_turn(
	tree: SceneTree, touch: RefCounted, camera: Camera3D, clock: Timeclock,
	expect: RefCounted
) -> void:
	clock.load_state({"digits": [0, 0, 0]})
	await tree.physics_frame
	var wanted := PackedInt32Array([6, 3, 1])
	for index in wanted.size():
		await _turn_one(tree, touch, camera, clock, index, wanted[index])
	expect.ok(
		clock.digits() == wanted,
		"each drag turns the wheel it started on (%s)" % [clock.digits()]
	)
	expect.ok(clock.hour() == 6, "the drum reads what was dialled into it")
	expect.ok(
		clock.lit(&"B"),
		"and tooth 3 covers 06:00, which is the whole of P3.1"
	)


## One wheel, one step per drag: the router clamps a single frame's travel, so a
## seven-click pull has to be seven pulls, which is also what a thumb does.
func _turn_one(
	tree: SceneTree, touch: RefCounted, camera: Camera3D, clock: Timeclock,
	index: int, steps: int
) -> void:
	var at := camera.unproject_position(clock.wheel_position(index))
	touch.press(8, at)
	await tree.physics_frame
	# The first move of any claim reports zero travel by design; spend it here.
	touch.drag(8, at)
	await tree.physics_frame
	var y := at.y
	for step in steps:
		y -= STEP_TRAVEL
		touch.drag(8, Vector2(at.x, y))
		await tree.physics_frame
	touch.lift(8, Vector2(at.x, y))
	await tree.physics_frame


func _stepping_back(
	tree: SceneTree, touch: RefCounted, hud: Hud, state: GameState, interactor: Interactor,
	expect: RefCounted
) -> void:
	var button: Control = hud.get_node("Controls/ActionButton")
	touch.press(9, button.position)
	await tree.physics_frame
	touch.lift(9, button.position)
	await tree.physics_frame
	expect.ok(state.current == GameState.State.FREE, "stepping back returns control")
	expect.ok(hud.probe()["focused"] == false, "the HUD unlocks")
	expect.ok(hud.get_node("Controls/MoveStick").visible, "the movement stick comes back")
	await tree.physics_frame
	# The clock is not a lock and does not stop offering itself: a schedule is
	# something you come back and change. What has to be true is that letting go
	# hands control back, which is the framework's contract and not the puzzle's.
	expect.ok(
		interactor.target() != null,
		"and the clock is still there to be set again, because a schedule is"
	)
