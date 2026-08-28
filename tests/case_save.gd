extends RefCounted

## Saving, loading, migrating, exporting, and failing to save.
##
## The last one matters most: Safari can refuse storage outright, and a game
## that crashes when it cannot save is worse than one that says so and carries
## on. `Storage.simulate_unavailable` exists to make that path reachable here
## rather than only on a phone nobody can reproduce.

## Two clear spots in the generator hall, neither inside a generator set.
const HERE := Vector3(-1.5, 0.0, 3.5)
const THERE := Vector3(5.5, 0.0, 3.5)
const AIM := 0.9


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var saves: SaveService = main.get_node("Saves")
	var player: Player = main.get_node("Player")
	# A device with wheels, to prove more than a bool round-trips. Act 1's
	# throwaway dial lock used to be it; the panel's main breaker is the thing
	# that is actually there now, and PowerhouseLogic's own state carries the
	# wheels' worth of complication.
	var breaker: DeviceToggle = main.get_node("Powerhouse/Panel/Main")
	var logic: PowerhouseLogic = main.get_node("Powerhouse/Logic")

	await _round_trip(tree, saves, player, breaker, logic, expect)
	await _codes(tree, saves, player, expect)
	await _migration(tree, saves, player, expect)
	await _an_act_you_leave(tree, main, saves, expect)
	await _coming_back_to_it(tree, main, saves, expect)
	await _the_code_stays_pasteable(tree, main, saves, expect)
	await _degrades(tree, saves, expect)
	await _slots(tree, saves, expect)


func _round_trip(
	tree: SceneTree, saves: SaveService, player: Player, breaker: DeviceToggle,
	logic: PowerhouseLogic, expect: RefCounted
) -> void:
	player.global_position = HERE
	player.face(AIM, 0.0)
	breaker.on = false
	logic.load_state({"wrench": true, "reached": ["lighting"]})
	await tree.physics_frame
	expect.ok(saves.save_to(SaveService.MANUAL), "a save is written and read back")

	player.global_position = THERE
	player.face(0.0, 0.0)
	breaker.on = true
	logic.load_state({"wrench": false, "reached": []})
	await tree.physics_frame
	expect.ok(saves.load_from(SaveService.MANUAL), "the slot loads")
	await tree.physics_frame
	expect.near(player.global_position.x, HERE.x, 0.01, "the player is put back where they were")
	expect.near(player.rotation.y, AIM, 0.01, "and pointing where they were pointing")
	expect.ok(not breaker.on, "the breaker reads what it read")
	expect.ok(logic.has_wrench(), "and the act's own state comes with it")

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


## The autosave is *read*, and Return to Title means it.
##
## This is here because for a long time nothing read it. The save system was
## complete, tested and decorative: every checkpoint wrote, the tab going away
## wrote, and reopening the tab started at the panel in the dark with the whole
## thing still sitting in IndexedDB. A save nobody loads is not a save.
func _coming_back_to_it(
	tree: SceneTree, main: Node, saves: SaveService, expect: RefCounted
) -> void:
	var runner: ActRunner = main.get_node("Acts")
	var menu: PauseMenu = main.get_node("PauseMenu")
	runner.restart(0)
	await tree.physics_frame

	var breaker: DeviceToggle = main.get_node("Powerhouse/Panel/Main")
	expect.ok(not breaker.on, "a game nobody has played")
	breaker.on = true
	expect.ok(saves.save_to(SaveService.AUTO), "which autosaves at a checkpoint")

	# Everything thrown away, the way closing the tab throws it away.
	runner.restart(0)
	await tree.physics_frame
	expect.ok(
		not (main.get_node("Powerhouse/Panel/Main") as DeviceToggle).on,
		"and then the tab goes away and the building is new again"
	)

	main.call("_resume_if_any")
	await tree.physics_frame
	expect.ok(
		(main.get_node("Powerhouse/Panel/Main") as DeviceToggle).on,
		"coming back picks it up where it was left"
	)

	# And Return to Title has to mean start again, or the button does nothing a
	# player can see: the reload it triggers would resume from this same save.
	menu.discard_autosave()
	expect.ok(not saves.has(SaveService.AUTO), "Return to Title discards the autosave")
	runner.restart(0)
	await tree.physics_frame
	main.call("_resume_if_any")
	await tree.physics_frame
	expect.ok(
		not (main.get_node("Powerhouse/Panel/Main") as DeviceToggle).on,
		"so the next boot is a new game"
	)

	# Leave an autosave behind: `_slots` checks that emptying the manual slot
	# does not touch it, and a case that consumes what its neighbours rely on is
	# a case that breaks them instead of itself.
	saves.save_to(SaveService.AUTO)


## An act you walk out of is as you left it when you come back.
##
## Act 4's first two puzzles are in Act 1's gallery, so travel is two-way, and
## arriving to find every breaker back where it started would be the building
## undoing an hour of the player's work. It is also a latent bug that was there
## before anything needed it: leaving Act 1 for Act 2 used to throw Act 1 away.
func _an_act_you_leave(
	tree: SceneTree, main: Node, saves: SaveService, expect: RefCounted
) -> void:
	var runner: ActRunner = main.get_node("Acts")
	runner.load_act(0)
	await tree.physics_frame

	var main_breaker: DeviceToggle = main.get_node("Powerhouse/Panel/Main")
	var was := main_breaker.on
	main_breaker.on = not was
	await tree.physics_frame

	runner.load_act(1)
	await tree.physics_frame
	expect.ok(main.get_node_or_null("Powerhouse") == null, "leave the act entirely")

	runner.load_act(0)
	await tree.physics_frame
	var again: DeviceToggle = main.get_node("Powerhouse/Panel/Main")
	expect.ok(again != main_breaker, "come back to a freshly built one")
	expect.eq(again.on, not was, "with the breaker still where you left it")

	# And the stash travels in the save, so it survives a reload too.
	expect.ok(saves.save_to(SaveService.MANUAL), "the whole building saves")
	var stored: Dictionary = JSON.parse_string(Storage.read("save." + SaveService.MANUAL))
	expect.ok(
		(stored.get("acts", {}) as Dictionary).has("0"),
		"and the save carries a stash per act (%s)" % [(stored.get("acts", {}) as Dictionary).keys()]
	)

	again.on = was
	runner.load_act(1)
	await tree.physics_frame
	expect.ok(saves.load_from(SaveService.MANUAL), "load it back from another act")
	await tree.physics_frame
	expect.eq(
		(main.get_node("Powerhouse/Panel/Main") as DeviceToggle).on, not was,
		"and the act it names comes back as it was, not as it starts"
	)
	saves.erase(SaveService.MANUAL)

	main_breaker = main.get_node("Powerhouse/Panel/Main")
	main_breaker.on = was
	await tree.physics_frame


## The migration path, through the door it is actually reachable by: an import
## of something with no version field.
func _migration(
	tree: SceneTree, saves: SaveService, player: Player, expect: RefCounted
) -> void:
	var unversioned := {"nodes": {"player": {"at": [6.0, 0.0, 3.5], "aim": [0.25, 0.0]}}}
	expect.ok(SaveGame.migrate(unversioned).get("version") == SaveGame.VERSION,
		"an unversioned save migrates to the current version")
	expect.ok(saves.apply(unversioned), "and applies")
	await tree.physics_frame
	expect.near(player.global_position.x, 6.0, 0.01, "carrying its state with it")

	# A real v1 save, in the shape the deployed build actually wrote: a header
	# with no `act` field, because there was only one act when it was written.
	# This is not a hypothetical -- anyone who has played the live build has one.
	var v1 := {
		"version": 1,
		"saved_at": "2026-08-27T22:10:00",
		"build": "v0.1.0 3dfb78a",
		"play_seconds": 402.5,
		"checkpoint": "gallery",
		"nodes": {"player": {"at": [9.9, -3.8, 22.0], "aim": [1.5, 0.0]}},
	}
	var brought_forward := SaveGame.migrate(v1)
	expect.eq(brought_forward.get("version"), SaveGame.VERSION, "a v1 save migrates forward")
	expect.eq(brought_forward.get("act"), 0, "and lands in the act it was written in")
	expect.eq(brought_forward.get("checkpoint"), "gallery", "keeping the checkpoint it had")
	expect.near(float(brought_forward.get("play_seconds")), 402.5, 0.01, "and the time played")
	expect.ok(saves.apply(v1), "and it applies")
	await tree.physics_frame
	expect.near(player.global_position.z, 22.0, 0.01, "putting the player back where they were")

	# A v2 save, which is the shape the build that is live right now writes: it
	# knows which act it is in and nothing about the acts it is not in.
	var v2 := {
		"version": 2,
		"saved_at": "2026-08-28T04:00:00",
		"build": "v0.1.0 14c1ff4",
		"play_seconds": 1180.0,
		"checkpoint": "sump",
		"act": 1,
		"nodes": {"player": {"at": [0.0, 0.1, 6.0], "aim": [0.0, 0.0]}},
	}
	var from_v2 := SaveGame.migrate(v2)
	expect.eq(from_v2.get("version"), SaveGame.VERSION, "a v2 save migrates forward")
	expect.eq(from_v2.get("act"), 1, "keeping the act it was in")
	expect.ok(
		(from_v2.get("acts") as Dictionary).is_empty(),
		"and starting with no stashes, because it had never left an act"
	)

	var future := {"version": SaveGame.VERSION + 99, "nodes": {"player": {"at": [0.0, 0.0, 0.0]}}}
	expect.ok(SaveGame.migrate(future).is_empty(), "a save from a newer build is refused")
	expect.ok(not saves.apply(future), "and does not reach the world")
	await tree.physics_frame
	expect.near(player.global_position.z, 22.0, 0.01, "which is left where it was")


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


## A save code has to be something a person can actually send.
##
## It exists because Safari evicts storage for a site nobody has installed after
## about a week idle, so a code the player can paste back is the only save they
## really own -- and a code they cannot paste is not one. Two acts of state now
## ride along in it, which is exactly the kind of thing that grows quietly.
##
## Eight hundred and thirty-odd characters at a full game: fourteen lines in a
## message. The cap is generous and the point is that it cannot double without
## somebody deciding it should.
const CODE_LIMIT := 2000


func _the_code_stays_pasteable(
	tree: SceneTree, main: Node, saves: SaveService, expect: RefCounted
) -> void:
	var runner: ActRunner = main.get_node("Acts")
	# Both acts visited, so both stashes are full: the worst case a player can
	# actually produce.
	runner.load_act(1)
	await tree.physics_frame
	runner.load_act(0)
	await tree.physics_frame

	var data := saves.collect()
	var code := SaveGame.to_code(data)
	expect.ok(
		code.length() <= CODE_LIMIT,
		"a whole game fits in a code you can paste (%d chars of %d)"
			% [code.length(), CODE_LIMIT]
	)
	expect.ok(
		not SaveGame.from_code(code).is_empty(),
		"and it comes back out again"
	)
	expect.ok(
		(SaveGame.from_code(code).get("acts", {}) as Dictionary).size() >= 2,
		"with both acts' state still in it"
	)
