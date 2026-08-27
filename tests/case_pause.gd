extends RefCounted

## Pause is only a pause if it stops the world, drops every thumb, and gives
## control back without the camera having moved in the meantime.

const TOUCH := preload("res://tests/touch.gd")
const SETTLE_FRAMES := 12


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var hud: Hud = main.get_node("Hud")
	var menu: PauseMenu = main.get_node("PauseMenu")
	var player: Player = main.get_node("Player")
	var move: VirtualStick = hud.get_node("Controls/MoveStick")
	var touch: RefCounted = TOUCH.new(tree.root)

	touch.press(1, move.position)
	touch.drag(1, move.position + Vector2(0.0, -120.0))
	for frame in SETTLE_FRAMES:
		await tree.physics_frame
	var walked := player.global_position
	expect.ok(walked.distance_to(Vector3(0.5, 0.05, 3.2)) > 0.05, "the player walks before pausing")

	menu.open()
	await tree.physics_frame
	expect.ok(tree.paused, "opening the menu pauses the tree")
	expect.same(move.value, Vector2.ZERO, "pausing releases the stick that was held")
	expect.ok(hud.probe()["claims"].is_empty(), "pausing drops every claimed touch")
	expect.ok(AudioBuses.is_ducked(), "pausing ducks the game buses")

	var frozen := player.global_position
	var aim := Vector2(player.rotation.y, player.get_node("Head").rotation.x)
	touch.press(2, Vector2(700.0, 220.0))
	touch.drag(2, Vector2(400.0, 300.0))
	for frame in SETTLE_FRAMES:
		await tree.physics_frame
	expect.ok(
		player.global_position.distance_to(frozen) < 0.0001,
		"the simulation does not advance while paused"
	)

	menu.close()
	await tree.physics_frame
	expect.ok(not tree.paused, "closing the menu resumes the tree")
	expect.ok(not AudioBuses.is_ducked(), "closing the menu restores the game buses")
	var resumed := Vector2(player.rotation.y, player.get_node("Head").rotation.x)
	expect.near(resumed.x, aim.x, 0.0001, "resume produces no yaw jump")
	expect.near(resumed.y, aim.y, 0.0001, "resume produces no pitch jump")
	expect.same(move.value, Vector2.ZERO, "no stick is still held after a resume")
	touch.lift(1, move.position)
	touch.lift(2, Vector2(400.0, 300.0))
	await tree.physics_frame
