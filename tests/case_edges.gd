extends RefCounted

## Awkward moments.
##
## Every other case does one thing at a time, because that is how you find out
## whether the thing works. This one does two at once, on purpose, at the joins:
## pause during a fade, save while a document is up, reload while an act swap is
## still deferred. None of these is exotic — a phone takes a call whenever it
## likes, and the player pauses when they are confused, which is exactly during
## the moment they did not understand.
##
## What is being asked is not "does it look right" but "is the game still
## playable afterwards", which is a question a test can answer.

const PATIENCE := 400


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var runner: ActRunner = main.get_node("Acts")
	(main.get_node("Run") as RunState).load_state({})
	runner.restart(0)
	await tree.physics_frame

	await _pausing_during_a_fade(tree, main, expect)
	await _saving_with_a_page_up(tree, main, expect)
	await _reloading_while_an_act_is_still_swapping(tree, main, expect)

	runner.restart(0)
	await tree.physics_frame


## The end-of-act fade runs for a couple of seconds with no controls on screen.
## A player who pauses in the middle of it must not come back to a black world.
func _pausing_during_a_fade(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var menu: PauseMenu = main.get_node("PauseMenu")
	var post: PostStack = main.get_node("PostStack")
	var reader: Reader = main.get_node("Reader")
	var house: Node3D = main.get_node("Powerhouse")
	var end_area: ActEnd = house.get_node("ActEnd")

	end_area.trigger()
	for frame in 20:
		await tree.process_frame
	var midway := float(post.probe()["exposure"])
	expect.ok(midway < 1.0 and midway > 0.0, "the world is midway through fading (%.2f)" % midway)

	menu.open()
	await tree.process_frame
	expect.ok(menu.is_open(), "the menu opens over it")
	menu.close()
	for frame in PATIENCE:
		await tree.process_frame
		if reader.is_open():
			break
	expect.ok(reader.is_open(), "and the fade still finishes into the card")

	reader.close()
	for frame in 60:
		await tree.process_frame
		if main.get_node_or_null("Shelter") != null:
			break
	expect.near(
		float(post.probe()["exposure"]), 1.0, 0.02,
		"putting the card down brings the world back, not a black screen"
	)


## Saving with a document held up, and loading it back. The reader is not part
## of any act and the save says nothing about it, so what must be true is that
## the game is not left holding a page it cannot put down.
func _saving_with_a_page_up(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var saves: SaveService = main.get_node("Saves")
	var reader: Reader = main.get_node("Reader")
	var journal: Journal = main.get_node("Journal")
	var state: GameState = main.get_node("State")

	reader.show_document(journal.index.documents[0])
	await tree.process_frame
	expect.ok(reader.is_open(), "a page is up")
	expect.ok(saves.save_to(SaveService.MANUAL), "and the game saves under it")

	reader.close()
	await tree.process_frame
	expect.ok(saves.load_from(SaveService.MANUAL), "the slot loads")
	await tree.physics_frame
	expect.ok(not reader.is_open(), "and comes back with no page held")
	expect.ok(
		state.accepts_world_input(),
		"with the world taking input again, which is the thing that matters"
	)
	saves.erase(SaveService.MANUAL)


## `ActEnd` defers the act swap by a frame, because freeing the act a node is
## inside is never safe. A save applied inside that window must not land in the
## act that is about to be thrown away.
func _reloading_while_an_act_is_still_swapping(
	tree: SceneTree, main: Node, expect: RefCounted
) -> void:
	var runner: ActRunner = main.get_node("Acts")
	var saves: SaveService = main.get_node("Saves")

	runner.load_act(1)
	await tree.physics_frame
	expect.ok(saves.save_to(SaveService.MANUAL), "a save taken in the shelter")

	# Ask for act 0 the way `ActEnd` does -- queued for the next idle frame,
	# because it cannot free the act it is standing in -- and load the save
	# inside that window. The save names act 1 and has to win: it knows which
	# act it wants, and the queued request only knows which one it is leaving.
	runner.request_act(0)
	expect.ok(saves.load_from(SaveService.MANUAL), "loaded while an act change is in flight")
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame

	expect.ok(
		main.get_node_or_null("Shelter") != null,
		"the act the save names is the act that is mounted"
	)
	expect.eq(runner.current(), 1, "and the runner agrees with itself")
	saves.erase(SaveService.MANUAL)
