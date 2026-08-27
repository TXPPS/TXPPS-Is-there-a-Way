extends RefCounted

## Saving, loading, migrating, exporting, and failing to save.
##
## The last one matters most: Safari can refuse storage outright, and a game
## that crashes when it cannot save is worse than one that says so and carries
## on. `Storage.simulate_unavailable` exists to make that path reachable here
## rather than only on a phone nobody can reproduce.

const HERE := Vector3(-2.0, 0.0, 1.5)
const THERE := Vector3(3.0, 0.0, -2.0)
const AIM := 0.9


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var saves: SaveService = main.get_node("Saves")
	var player: Player = main.get_node("Player")
	var lock: DialLock = main.get_node("GrayboxRoom/DialLock")

	await _round_trip(tree, saves, player, lock, expect)
	await _codes(tree, saves, player, expect)
	await _migration(tree, saves, player, expect)
	await _degrades(tree, saves, expect)
	await _slots(tree, saves, expect)


func _round_trip(
	tree: SceneTree, saves: SaveService, player: Player, lock: DialLock, expect: RefCounted
) -> void:
	player.global_position = HERE
	player.face(AIM, 0.0)
	lock.load_state({"digits": [3, 3, 3], "open": false})
	await tree.physics_frame
	expect.ok(saves.save_to(SaveService.MANUAL), "a save is written and read back")

	player.global_position = THERE
	player.face(0.0, 0.0)
	lock.load_state({"digits": [9, 9, 9], "open": true})
	await tree.physics_frame
	expect.ok(saves.load_from(SaveService.MANUAL), "the slot loads")
	await tree.physics_frame
	expect.near(player.global_position.x, HERE.x, 0.01, "the player is put back where they were")
	expect.near(player.rotation.y, AIM, 0.01, "and pointing where they were pointing")
	expect.ok(lock.digits() == PackedInt32Array([3, 3, 3]), "the wheels read what they read")
	expect.ok(not lock.is_open(), "and an unsolved lock stays unsolved")

	saves.checkpoint("test-checkpoint")
	expect.ok(saves.has(SaveService.AUTO), "a checkpoint writes the autosave")
	expect.ok(saves.checkpoint_id() == "test-checkpoint", "and records where it was")


func _codes(
	tree: SceneTree, saves: SaveService, player: Player, expect: RefCounted
) -> void:
	player.global_position = HERE
	await tree.physics_frame
	var code := saves.export_code()
	expect.ok(code.begins_with("ITAW."), "a save code is recognisable at a glance")
	expect.ok(code.length() < 2000, "and short enough to paste (%d chars)" % code.length())

	player.global_position = THERE
	await tree.physics_frame
	expect.ok(saves.import_code(code), "a code imports")
	await tree.physics_frame
	expect.near(player.global_position.x, HERE.x, 0.01, "and restores the world it carried")

	expect.ok(not saves.import_code(code.substr(0, code.length() - 12)), "a truncated code is refused")
	expect.ok(not saves.import_code("ITAW.10.deadbeef.zzzz"), "a corrupt code is refused")
	expect.ok(not saves.import_code("hello"), "so is something that is not a code at all")
	await tree.physics_frame
	expect.near(
		player.global_position.x, HERE.x, 0.01,
		"and a refused code leaves the world exactly as it was"
	)


## The migration path, through the door it is actually reachable by: an import
## of something with no version field.
func _migration(
	tree: SceneTree, saves: SaveService, player: Player, expect: RefCounted
) -> void:
	var unversioned := {"nodes": {"player": {"at": [4.0, 0.0, -1.0], "aim": [0.25, 0.0]}}}
	expect.ok(SaveGame.migrate(unversioned).get("version") == SaveGame.VERSION,
		"an unversioned save migrates to the current version")
	expect.ok(saves.apply(unversioned), "and applies")
	await tree.physics_frame
	expect.near(player.global_position.x, 4.0, 0.01, "carrying its state with it")

	var future := {"version": SaveGame.VERSION + 99, "nodes": {"player": {"at": [0.0, 0.0, 0.0]}}}
	expect.ok(SaveGame.migrate(future).is_empty(), "a save from a newer build is refused")
	expect.ok(not saves.apply(future), "and does not reach the world")
	await tree.physics_frame
	expect.near(player.global_position.x, 4.0, 0.01, "which is left where it was")


func _degrades(tree: SceneTree, saves: SaveService, expect: RefCounted) -> void:
	var reasons: Array[String] = []
	var listener := func(reason: String) -> void: reasons.append(reason)
	saves.failed.connect(listener)
	Storage.simulate_unavailable = true
	expect.ok(not saves.save_to(SaveService.MANUAL), "a save that cannot be read back reports failure")
	expect.ok(reasons.size() == 1, "exactly once")
	expect.ok(
		reasons.size() > 0 and reasons[0].contains("Export code"),
		"and says what the player can do instead (%s)" % ("-" if reasons.is_empty() else reasons[0])
	)
	Storage.simulate_unavailable = false
	await tree.physics_frame
	expect.ok(saves.save_to(SaveService.MANUAL), "and saving works again once storage does")
	saves.failed.disconnect(listener)


func _slots(tree: SceneTree, saves: SaveService, expect: RefCounted) -> void:
	expect.ok(saves.has(SaveService.MANUAL), "the manual slot is occupied")
	saves.erase(SaveService.MANUAL)
	expect.ok(not saves.has(SaveService.MANUAL), "and can be emptied")
	expect.ok(not saves.load_from(SaveService.MANUAL), "loading an empty slot fails cleanly")
	expect.ok(saves.has(SaveService.AUTO), "the autosave is untouched by that")
	await tree.physics_frame
