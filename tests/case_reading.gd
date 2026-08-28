extends RefCounted

## Reading a page.
##
## The whole thing rides on the focused-interaction contract built in P1: engage
## a Readable and the sticks go away, the gestures that would have turned the
## camera scroll the page instead, and the action button says "Put it down".
## Nothing here is new machinery -- which is the point of having built the
## machinery first.

const TOUCH := preload("res://tests/touch.gd")
## A step off the hall's west wall, where the sequence card is.
const STAND_AT := Vector3(-6.6, 0.0, -4.0)
const FACING := 90.0


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
	_no_document_needs_a_monospace_font(main, expect)
	await _the_index_is_complete(tree, main, expect)
	await _the_menu_lists_what_was_read(tree, main, expect)

	player.global_position = STAND_AT
	player.face(deg_to_rad(FACING), 0.0)
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


## Every document on disk is in the index, and the index is what the journal
## reads back from. A document that exists and is not listed is one the player
## can find once and then lose, and nothing else would notice.
func _the_index_is_complete(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var journal: Journal = main.get_node("Journal")
	expect.ok(journal.index != null, "the journal has an index")

	var on_disk := PackedStringArray()
	var dir := DirAccess.open("res://assets/documents")
	for name in dir.get_files():
		var file := name.trim_suffix(".remap")
		if not file.ends_with(".tres") or file == "index.tres" or file.ends_with("_card.tres"):
			continue
		on_disk.append(file)
	on_disk.sort()

	expect.eq(
		journal.total(), on_disk.size(),
		"and it lists every document on disk (%d of %d)" % [journal.total(), on_disk.size()]
	)

	var missing := PackedStringArray()
	for file in on_disk:
		var document := load("res://assets/documents/%s" % file) as Document
		if document != null and journal.index.find(document.id) == null:
			missing.append(file)
	expect.ok(missing.is_empty(), "with none missing (%s)" % " ".join(missing))

	var blank := PackedStringArray()
	for document in journal.index.documents:
		if document == null or document.id == &"" or document.title.is_empty() \
				or document.body.strip_edges().is_empty():
			blank.append("" if document == null else String(document.id))
	expect.ok(blank.is_empty(), "and none of them empty (%s)" % " ".join(blank))
	await tree.process_frame


## What was read can be read again, from the menu, without walking back for it.
func _the_menu_lists_what_was_read(
	tree: SceneTree, main: Node, expect: RefCounted
) -> void:
	var journal: Journal = main.get_node("Journal")
	var menu: PauseMenu = main.get_node("PauseMenu")
	var reader: Reader = main.get_node("Reader")

	var kept := journal.save_state()
	journal.load_state({"read": []})
	expect.ok(journal.read_documents().is_empty(), "nothing read is nothing listed")

	var first: Document = journal.index.documents[0]
	journal.mark_read(first)
	var listed := journal.read_documents()
	expect.eq(listed.size(), 1, "read one and one is listed")
	expect.ok(listed[0] == first, "and it is the one that was read")

	menu.open()
	await tree.process_frame
	var titles := PackedStringArray()
	for node in menu.get_node("Safe/Panel/Pad/Body/Scroll/Column/Groups").get_children():
		if node is Button:
			titles.append((node as Button).text)
	expect.ok(
		titles.has(first.title),
		"the menu offers it by name (%s)" % " | ".join(titles)
	)

	menu.close()
	await tree.process_frame
	reader.show_document(first)
	await tree.process_frame
	expect.ok(reader.is_open(), "and it opens in the same reader the world uses")
	reader.close()
	await tree.process_frame

	journal.load_state(kept)


## `STORY.md`: **no document may depend on column alignment.**
##
## The reader has one proportional font -- there is no licensed monospace in
## this project and no budget for a generated one -- so a four-column table does
## not line up, it drifts. The rule is to write records as one line per field,
## and on a 956-point screen that reads better anyway.
##
## The rule was written after Act 1's documents were fixed, and then most of
## Acts 2 to 4 were written as tables anyway, including the panel schedule that
## P2.3 turns on. Nothing noticed, because nothing was looking.
##
## What a table looks like from here: a line with two or more runs of three or
## more spaces in it, which is somebody lining up columns by eye.
func _no_document_needs_a_monospace_font(main: Node, expect: RefCounted) -> void:
	var journal: Journal = main.get_node("Journal")
	var offenders := PackedStringArray()
	for document in journal.index.documents:
		if document == null:
			continue
		for line in document.body.split("\n"):
			var runs := 0
			var spaces := 0
			for index in line.length():
				if line[index] == " ":
					spaces += 1
					continue
				if spaces >= 3:
					runs += 1
				spaces = 0
			# A leading indent is not a column; two gaps inside a line are.
			if runs >= 2:
				offenders.append("%s: %s" % [document.id, line.strip_edges()])
				break
	expect.ok(
		offenders.is_empty(),
		"no document lines up columns the font will not keep (%s)" % " | ".join(offenders)
	)
