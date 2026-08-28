extends RefCounted

## Every interactable thing in the act, reached from where a player would stand.
##
## The failure this exists for is a prop placed 30 mm inside a wall, or at chest
## height on a panel the player cannot get close enough to, or facing the
## concrete. All three are invisible in a screenshot and none of them is caught
## by a test that knows where the props are, because that test was written from
## the same numbers that put them there.
##
## So this asks nothing about coordinates. For each zone it works out where
## somebody would have to stand to use it -- a step back along the face, on
## whatever floor is under that point -- puts the player there, points them at
## it, and asks the interactor what it can see. If the answer is not this zone,
## the thing is not in the game however much of it is in the scene file.

const STAND_BACK := 1.15
const EYE := 1.62


## Every act, not just the first. An act nobody walks is an act whose props are
## wherever the generator put them.
const ACTS := [
	{"index": 0, "node": "Powerhouse", "least": 25},
	{"index": 1, "node": "Shelter", "least": 40},
]


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var runner: ActRunner = main.get_node("Acts")
	for act in ACTS:
		runner.load_act(int(act["index"]))
		await tree.physics_frame
		await _walk(tree, main, String(act["node"]), int(act["least"]), expect)
	runner.load_act(0)
	await tree.physics_frame


func _walk(
	tree: SceneTree, main: Node, act_node: String, least: int, expect: RefCounted
) -> void:
	var player: Player = main.get_node("Player")
	var interactor: Interactor = player.get_node("Head/Camera/Interactor")
	# Reachability is a question about placement, not progression: a door that
	# is legitimately shut makes what is behind it unreachable *for now*, which
	# is the door working. So every door the act has is opened first, and what
	# is asked is whether the props behind them can be stood in front of at all.
	for node in _doors(main.get_node(act_node)):
		node.open = true

	# And every gated control is offered. `available` is progression -- a solved
	# lock, a permissive the sequence is still holding -- and this case is about
	# whether a prop is somewhere a player could stand in front of, which is a
	# fair question about all of them. Put back afterwards.
	var zones := _find(main.get_node(act_node))
	var were: Dictionary = {}
	for zone in zones:
		were[zone] = zone.available
		zone.available = true
	await tree.physics_frame
	await tree.physics_frame
	expect.ok(
		zones.size() >= least,
		"%s has things to interact with (%d)" % [act_node, zones.size()]
	)

	var unreachable := PackedStringArray()
	for zone in zones:
		var why := await _reach(tree, player, interactor, zone)
		if not why.is_empty():
			unreachable.append("%s: %s" % [zone.get_parent().name, why])
	expect.ok(
		unreachable.is_empty(),
		"every one of %s's can be reached from the floor (%s)"
			% [act_node, "none unreachable" if unreachable.is_empty() else " | ".join(unreachable)]
	)
	for zone in were:
		(zone as Interactable).available = were[zone]


func _doors(root: Node) -> Array[DeviceDoor]:
	var found: Array[DeviceDoor] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is DeviceDoor:
			found.append(node)
		for child in node.get_children():
			stack.append(child)
	return found


func _find(root: Node) -> Array[Interactable]:
	var found: Array[Interactable] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var zone := node as Interactable
		if zone != null:
			found.append(zone)
		for child in node.get_children():
			stack.append(child)
	return found


## A step back along the face it presents, standing on whatever is underneath.
## Returns an empty string when it can be reached, and why not otherwise --
## "unreachable" on its own tells you there is a bug and nothing about where.
func _reach(
	tree: SceneTree, player: Player, interactor: Interactor, zone: Interactable
) -> String:
	var face := zone.global_transform.basis.z.normalized()
	var target := zone.global_position
	var spot := target + face * STAND_BACK
	var floor_y := _floor_under(player, spot, target.y)
	if is_nan(floor_y):
		return "no floor to stand on at %.1f,%.1f" % [spot.x, spot.z]
	player.global_position = Vector3(spot.x, floor_y + 0.05, spot.z)
	player.velocity = Vector3.ZERO
	var eye := player.global_position + Vector3.UP * EYE
	var to := target - eye
	player.face(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
	await tree.physics_frame
	await tree.physics_frame
	if interactor.target() == zone:
		return ""
	var got := interactor.target()
	if got != null:
		return "found %s instead" % got.get_parent().name
	# Nothing at all: either the ray misses, or something opaque is in the way.
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	var blocked := space.intersect_ray(query)
	if not blocked.is_empty():
		return "line of sight blocked by %s" % (blocked["collider"] as Node).get_parent().name
	return "nothing found from %.1f,%.1f,%.1f" % [player.global_position.x,
		player.global_position.y, player.global_position.z]


func _floor_under(player: Player, spot: Vector3, from_y: float) -> float:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(spot.x, from_y + 1.0, spot.z), Vector3(spot.x, from_y - 6.0, spot.z), 1
	)
	var hit := space.intersect_ray(query)
	return NAN if hit.is_empty() else (hit["position"] as Vector3).y
