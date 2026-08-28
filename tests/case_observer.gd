extends RefCounted

## The entity's rule, as the bible states it.
##
## `STORY.md` has a five-row table headed "The rule", and every row is a promise
## to the player: this is what you see, and this is what you can do about it. A
## player is meant to be able to *learn* those rows, which means they have to be
## true every time, which means they belong in a test rather than in a designer's
## memory.
##
## Built in an empty scene with lamps made here, not in an act. The entity has
## no act yet, and the whole point of it is that it is a rule rather than a
## place.

const OBSERVER := preload("res://src/world/entity/observer.tscn")

## Sixty metres under the building. The suite runs every case against one tree
## and one physics space, so a bare lamp and a bare stand-in placed at the origin
## are inside Act 1's generator hall, and every sight line this case cares about
## is cut by a wall it never asked for. Empty space is part of the fixture.
const NOWHERE := Vector3(0.0, -60.0, 0.0)

## Far enough apart that the geometry is unambiguous at a glance.
const LAMP_AT := Vector3(0.0, 2.2, -8.0)
const PLAYER_AT := Vector3(0.0, 0.0, 0.0)


func run(tree: SceneTree, _main: Node, expect: RefCounted) -> void:
	var room := Node3D.new()
	tree.root.add_child(room)

	var player := Node3D.new()
	player.name = "Stand-in"
	room.add_child(player)
	player.global_position = NOWHERE + PLAYER_AT

	var lamp := _lamp(room, "Lamp", NOWHERE + LAMP_AT)
	var observer: Observer = OBSERVER.instantiate()
	room.add_child(observer)
	observer.bind(player)
	await tree.physics_frame

	await _it_stands_between(tree, observer, lamp, player, expect)
	await _it_approaches_along_the_axis(tree, observer, lamp, player, expect)
	await _stepping_off_the_line(tree, observer, player, expect)
	await _it_cannot_cross_the_dark(tree, observer, lamp, player, expect)
	await _two_lamps_leave_no_offset(tree, room, observer, lamp, player, expect)
	await _it_stops_short(tree, observer, lamp, player, expect)

	room.queue_free()
	await tree.process_frame


## Row 1: it occupies the space between a lit fixture and you.
func _it_stands_between(
	tree: SceneTree, observer: Observer, lamp: Light3D, player: Node3D, expect: RefCounted
) -> void:
	await tree.physics_frame
	expect.ok(observer.present(), "with a lamp lit and a clear line, it is there")

	var lamp_to_player: Vector3 = player.global_position - lamp.global_position
	var lamp_to_it: Vector3 = observer.global_position - lamp.global_position
	expect.near(
		rad_to_deg(lamp_to_player.angle_to(lamp_to_it)), 0.0, 0.5,
		"and it is on the line between them, not beside it"
	)
	expect.ok(
		lamp_to_it.length() < lamp_to_player.length(),
		"between the lamp and the player rather than beyond either"
	)


## Row 2: it can only approach along that axis.
func _it_approaches_along_the_axis(
	tree: SceneTree, observer: Observer, lamp: Light3D, player: Node3D, expect: RefCounted
) -> void:
	var before: float = observer.global_position.distance_to(player.global_position)
	for frame in 120:
		await tree.physics_frame
	var after: float = observer.global_position.distance_to(player.global_position)
	expect.ok(after < before, "it comes closer (%.2f -> %.2f m)" % [before, after])

	var lamp_to_player: Vector3 = player.global_position - lamp.global_position
	var lamp_to_it: Vector3 = observer.global_position - lamp.global_position
	expect.near(
		rad_to_deg(lamp_to_player.angle_to(lamp_to_it)), 0.0, 0.5,
		"and it is still on the line, having moved along it and nowhere else"
	)
	expect.ok(observer.nearness() > 0.0, "with something to report to the fear state")


## Row 3, and the only thing the player can do about it early: step off the line.
func _stepping_off_the_line(
	tree: SceneTree, observer: Observer, player: Node3D, expect: RefCounted
) -> void:
	var broke := [0]
	observer.broken.connect(func() -> void: broke[0] += 1)

	# A small shuffle is not stepping off the line. Breathing must not reset it.
	var was := observer.nearness()
	player.global_position += Vector3(0.3, 0.0, 0.0)
	await tree.physics_frame
	expect.ok(observer.present(), "a shuffle does not break the approach")
	expect.ok(observer.nearness() >= was - 0.05, "and does not send it back to the start")

	# A deliberate step across does.
	player.global_position += Vector3(6.0, 0.0, 0.0)
	await tree.physics_frame
	expect.ok(not observer.present(), "stepping off the line breaks it")
	expect.eq(broke[0], 1, "which it says once")

	await tree.physics_frame
	expect.ok(observer.present(), "and it begins again from the new line")
	expect.ok(
		observer.nearness() < 0.2,
		"all the way back, because a rule you can half-cheat is not a rule (%.2f)"
			% observer.nearness()
	)
	observer.broken.disconnect(observer.broken.get_connections()[0]["callable"])


## Row 4: it cannot cross unlit space. Killing the light is the one certain
## defence, and the reason the game makes it expensive is the rest of the design.
func _it_cannot_cross_the_dark(
	tree: SceneTree, observer: Observer, lamp: Light3D, player: Node3D, expect: RefCounted
) -> void:
	# Two frames: the previous check left the player off the old line, so the
	# first frame here is the break and the second is it standing on the new one.
	player.global_position = NOWHERE + PLAYER_AT
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(observer.present(), "it is there while the lamp is lit")

	lamp.light_energy = 0.0
	await tree.physics_frame
	expect.ok(not observer.present(), "and gone the moment the lamp is not")

	for frame in 60:
		await tree.physics_frame
	expect.ok(not observer.present(), "in the dark nothing comes")

	lamp.light_energy = 4.2
	await tree.physics_frame
	expect.ok(observer.present(), "light it again and it is standing there")


## Row 5: two lit fixtures from different angles leave no offset. More light is
## not more safety, which is the lesson Act 2's load budget was teaching in a
## room where nothing was hunting anybody.
func _two_lamps_leave_no_offset(
	tree: SceneTree, room: Node3D, observer: Observer, first: Light3D,
	player: Node3D, expect: RefCounted
) -> void:
	var second := _lamp(room, "Second", NOWHERE + Vector3(8.0, 2.2, 0.0))
	player.global_position = NOWHERE + PLAYER_AT
	await tree.physics_frame

	# Whichever it is standing on, stepping directly away from that lamp is the
	# move that breaks it -- and that step cannot break both at once, because
	# the two lines are ninety degrees apart.
	var standing_at: String = observer.probe()["lamp"]
	expect.ok(standing_at != "", "with two lamps lit it is still at exactly one")

	var away: Vector3 = (player.global_position - _named(room, standing_at).global_position).normalized()
	player.global_position += away * 5.0
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(
		observer.present(),
		"stepping off one line finds it standing on the other (%s -> %s)"
			% [standing_at, observer.probe()["lamp"]]
	)
	expect.ok(
		String(observer.probe()["lamp"]) != standing_at,
		"which is a different lamp, and is why more light is not more safety"
	)

	second.queue_free()
	await tree.process_frame
	first.light_energy = 4.2


## It comes as close as it comes and stops. Never a face, never a touch.
func _it_stops_short(
	tree: SceneTree, observer: Observer, lamp: Light3D, player: Node3D, expect: RefCounted
) -> void:
	player.global_position = NOWHERE + PLAYER_AT
	lamp.global_position = NOWHERE + LAMP_AT
	await tree.physics_frame

	var landed := [0]
	observer.arrived.connect(func() -> void: landed[0] += 1)
	for frame in 900:
		await tree.physics_frame
		if landed[0] > 0:
			break
	expect.eq(landed[0], 1, "it arrives, once")
	expect.near(
		observer.global_position.distance_to(player.global_position), observer.closest, 0.15,
		"and stops at the distance it stops at"
	)
	expect.near(observer.nearness(), 1.0, 0.02, "with the fear state told it is as near as it gets")

	for frame in 120:
		await tree.physics_frame
	expect.near(
		observer.global_position.distance_to(player.global_position), observer.closest, 0.15,
		"and stays there rather than arriving twice"
	)
	expect.eq(landed[0], 1, "still once")


func _lamp(room: Node3D, name: String, at: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name
	light.add_to_group(&"practical")
	light.light_energy = 4.2
	light.omni_range = 14.0
	room.add_child(light)
	light.global_position = at
	return light


func _named(room: Node3D, name: String) -> Node3D:
	return room.get_node(name) as Node3D
