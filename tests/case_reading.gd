extends RefCounted

## Reading a page.
##
## The whole thing rides on the focused-interaction contract built in P1: engage
## a Readable and the sticks go away, the gestures that would have turned the
## camera scroll the page instead, and the action button says "Put it down".
## Nothing here is new machinery -- which is the point of having built the
## machinery first.

const TOUCH := preload("res://tests/touch.gd")
const STAND_AT := Vector3(-1.5, 0.0, -3.0)


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var hud: Hud = main.get_node("Hud")
	var player: Player = main.get_node("Player")
	var reader: Reader = main.get_node("Reader")
	var journal: Journal = main.get_node("Journal")
	var saves: SaveService = main.get_node("Saves")
	var settings: GameSettings = main.get_node("Settings")
	var interactor: Interactor = player.get_node("Head/Camera/Interactor")
	var touch: RefCounted = TOUCH.new(tree.root)
	var button: Control = hud.get_node("Controls/ActionButton")

	player.global_position = STAND_AT
	player.face(0.0, 0.0)
	await tree.physics_frame
	await tree.physics_frame

	expect.ok(interactor.target() != null, "the card is offered from a step away")
	expect.ok(hud.probe()["prompt"] == "Read the card", "with the prompt the prop set")
	expect.ok(not reader.is_open(), "and nothing is on screen until it is picked up")

	touch.press(11, button.position)
	await tree.physics_frame
	touch.lift(11, button.position)
	await tree.physics_frame
	expect.ok(reader.is_open(), "acting on it opens the page")
	expect.ok(hud.probe()["focused"] == true, "and locks the HUD to it")
	expect.ok(hud.probe()["prompt"] == "Put it down", "and offers the way out")

	var title: Label = reader.get_node("Safe/Panel/Pad/Body/Title")
	expect.ok(
		title.text.contains("Flood response"),
		"showing the document the prop carries (%s)" % title.text
	)

	await _scrolling(tree, touch, reader, expect)
	await _sizing(tree, reader, settings, expect)

	touch.press(12, button.position)
	await tree.physics_frame
	touch.lift(12, button.position)
	await tree.physics_frame
	expect.ok(not reader.is_open(), "putting it down closes the page")
	expect.ok(hud.probe()["focused"] == false, "and gives the sticks back")

	await _journal(tree, journal, saves, expect)


## The page moves with the thumb, and not the other way: a drag up is a drag
## down the page, which is how every phone works and how no camera does.
func _scrolling(tree: SceneTree, touch: RefCounted, reader: Reader, expect: RefCounted) -> void:
	var scroll: ScrollContainer = reader.get_node("Safe/Panel/Pad/Body/Scroll")
	scroll.scroll_vertical = 0
	var start := Vector2(600.0, 300.0)
	touch.press(13, start)
	await tree.physics_frame
	touch.drag(13, start)
	await tree.physics_frame
	for step in 4:
		touch.drag(13, start - Vector2(0.0, 40.0 * float(step + 1)))
		await tree.physics_frame
	expect.ok(scroll.scroll_vertical > 0, "dragging up moves down the page (%d)" % scroll.scroll_vertical)
	touch.lift(13, start)
	await tree.physics_frame


func _sizing(
	tree: SceneTree, reader: Reader, settings: GameSettings, expect: RefCounted
) -> void:
	var text: Label = reader.get_node("Safe/Panel/Pad/Body/Scroll/Text")
	settings.set_value(&"subtitle_size", 0.0)
	await tree.process_frame
	var small: int = text.get_theme_font_size("font_size")
	settings.set_value(&"subtitle_size", 3.0)
	await tree.process_frame
	var large: int = text.get_theme_font_size("font_size")
	expect.ok(
		large > small,
		"the subtitle size setting sizes the page (%d -> %d)" % [small, large]
	)
	settings.set_value(&"subtitle_size", 1.0)
	await tree.process_frame


func _journal(
	tree: SceneTree, journal: Journal, saves: SaveService, expect: RefCounted
) -> void:
	expect.ok(journal.has_read(&"d04_sequence_card"), "reading it is recorded")
	expect.ok(saves.save_to(SaveService.MANUAL), "and saves")
	journal.load_state({"read": []})
	expect.ok(not journal.has_read(&"d04_sequence_card"), "the record can be cleared")
	expect.ok(saves.load_from(SaveService.MANUAL), "and the slot loads")
	await tree.process_frame
	expect.ok(
		journal.has_read(&"d04_sequence_card"),
		"bringing the record back with it -- a page read in Act 1 is still read in Act 3"
	)
	saves.erase(SaveService.MANUAL)
