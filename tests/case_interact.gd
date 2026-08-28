extends RefCounted

## The focused-interaction framework, through its first user.
##
## Targeting, engaging, gestures reaching the thing engaged with and nothing
## else, and getting back out. The dial lock itself is throwaway; this case is
## about the machinery underneath it, which is not.

const TOUCH := preload("res://tests/touch.gd")
## Just past a step's reach of the plate, looking straight at it.
## In the switchgear room, a step off the west wall the lock is on.
const STAND_AT := Vector3(-13.0, 0.0, -3.2)
const FACING := 90.0
## Slightly more than one click, so each drag lands exactly one step.
const STEP_TRAVEL := 47.0


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var hud: Hud = main.get_node("Hud")
	var player: Player = main.get_node("Player")
	var state: GameState = main.get_node("State")
	var rects: HudRects = hud.get_node("HudRects")
	var lock: DialLock = main.get_node("Powerhouse/DialLock")
	var interactor: Interactor = player.get_node("Head/Camera/Interactor")
	var camera: Camera3D = player.get_node("Head/Camera")
	var touch: RefCounted = TOUCH.new(tree.root)

	player.global_position = STAND_AT
	player.velocity = Vector3.ZERO
	# Earlier cases left the camera somewhere else entirely.
	player.face(deg_to_rad(FACING), 0.0)
	await tree.physics_frame
	await tree.physics_frame

	expect.ok(interactor.target() != null, "the ray finds the lock from a step away")
	expect.ok(hud.probe()["prompt"] == "Work the dials", "the prompt says what it offers")

	await _occlusion_is_respected(tree, hud, rects, interactor, expect)
	await _engaging(tree, touch, hud, state, expect)
	await _dials_turn(tree, touch, camera, lock, expect)
	await _stepping_back(tree, touch, hud, state, interactor, expect)


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


func _dials_turn(
	tree: SceneTree, touch: RefCounted, camera: Camera3D, lock: DialLock, expect: RefCounted
) -> void:
	var wanted := lock.combination
	for index in wanted.size():
		await _turn_one(tree, touch, camera, lock, index, wanted[index])
	expect.ok(
		lock.digits() == wanted,
		"each drag turns the wheel it started on (%s)" % [lock.digits()]
	)
	expect.ok(lock.is_open(), "the right combination opens the lock")


## One wheel, one step per drag: the router clamps a single frame's travel, so a
## seven-click pull has to be seven pulls, which is also what a thumb does.
func _turn_one(
	tree: SceneTree, touch: RefCounted, camera: Camera3D, lock: DialLock,
	index: int, steps: int
) -> void:
	var at := camera.unproject_position(lock.dial_position(index))
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
	expect.ok(
		interactor.target() == null,
		"a solved lock stops offering itself"
	)
	expect.ok(hud.probe()["prompt"] == "", "and the prompt clears")
