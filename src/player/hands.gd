class_name Hands
extends Node3D

## What the player is carrying, which is at most one thing.
##
## Reparenting rather than a "carried" flag on the tool: a tool held is a tool
## whose transform is the camera's, and anything else means writing a follow
## behaviour that will disagree with the camera on some frame. It also means a
## tool crosses an act boundary in the player's hand without any special case,
## because the player is not part of the act.

signal picked_up(tool: CarriedTool)
signal put_down(tool: CarriedTool)

@export var save_key: StringName = &"hands"

## How far in front of the player a dropped tool lands, and how far it may fall
## looking for a floor. A tool put down in a doorway should end up on the floor
## of the room, not hanging where the player's chest was.
@export_range(0.3, 2.0, 0.05) var drop_reach: float = 0.75
@export_range(0.5, 8.0, 0.5) var drop_fall: float = 3.0

var _tool: CarriedTool


func holding() -> CarriedTool:
	return _tool


func empty() -> bool:
	return _tool == null


## Takes a tool. Whatever was already held is put down first: two things in one
## hand is a state with no way to draw it and no way to explain it.
func take(tool: CarriedTool) -> void:
	if tool == null or tool == _tool:
		return
	if _tool != null:
		drop()
	var keep := tool.get_parent()
	if keep != null:
		keep.remove_child(tool)
	add_child(tool)
	tool.transform = tool.hold_offset
	tool.set_held(true)
	_tool = tool
	picked_up.emit(tool)


## Puts it down in front of the player, on whatever floor is under that spot.
func drop() -> void:
	if _tool == null:
		return
	var tool := _tool
	_tool = null

	var where := _floor_in_front()
	remove_child(tool)
	var host := _level()
	host.add_child(tool)
	tool.global_transform = where
	tool.set_held(false)
	tool.announce_dropped()
	put_down.emit(tool)


func save_state() -> Dictionary:
	return {"tool": "" if _tool == null else String(_tool.save_key)}


## Restoring is by key rather than by reference: the tool the save names may be
## sitting in the act that was just mounted, and may not exist at all in a build
## where that act was cut.
func load_state(state: Dictionary) -> void:
	var wanted := String(state.get("tool", ""))
	if wanted.is_empty():
		drop()
		return
	if _tool != null and String(_tool.save_key) == wanted:
		return
	for node in get_tree().get_nodes_in_group(&"carried_tool"):
		var tool := node as CarriedTool
		if tool != null and String(tool.save_key) == wanted:
			take(tool)
			return
	# The save names a tool this build does not have -- an act that was cut, or
	# a hand-edited code. Holding nothing is the honest answer; leaving whatever
	# was already in the hand would be the game inventing a state the save did
	# not describe.
	drop()


## A metre or so ahead, dropped onto the floor. Upright, and turned to face the
## player, because a tool lying face-down is a tool the player has to pick up
## again to find out what it is.
func _floor_in_front() -> Transform3D:
	var camera := get_viewport().get_camera_3d()
	var eye: Vector3 = global_position if camera == null else camera.global_position
	var ahead: Vector3 = -global_transform.basis.z if camera == null else -camera.global_transform.basis.z
	ahead.y = 0.0
	if ahead.length_squared() < 0.0001:
		ahead = Vector3.FORWARD
	ahead = ahead.normalized()

	var spot := eye + ahead * drop_reach
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		spot, spot + Vector3.DOWN * drop_fall, 1
	)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		spot = (hit["position"] as Vector3) + Vector3.UP * 0.06

	var facing := -ahead
	return Transform3D(
		Basis(Vector3(facing.z, 0.0, -facing.x), Vector3.UP, facing), spot
	)


## Where a dropped tool belongs: the act, so it is freed with the act rather
## than outliving it invisibly.
func _level() -> Node:
	var act := get_tree().get_first_node_in_group(&"act")
	return act if act != null else get_tree().current_scene
