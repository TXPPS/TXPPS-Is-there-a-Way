class_name Interactor
extends Node3D

## Finds the one thing in front of the player worth reaching for.
##
## A ray from the centre of the view, not a tap on the world: a thumb cannot
## point accurately at something small on a phone, and a centre-screen ray means
## the player aims with the camera they are already aiming.

signal target_changed(target: Interactable)

## Metres. About an arm plus a step -- far enough to read an intent, near enough
## that the player has to actually walk over.
@export_range(0.5, 6.0, 0.1) var reach: float = 2.8

## Physics layer 3, "interactable". See project.godot.
@export_flags_3d_physics var mask: int = 4

## Asked before accepting a target: is the point on screen underneath a control?
## Wired to HudRects through Hud, so the player can never pick up something their
## own thumb is covering.
var occluded: Callable = Callable()

var _target: Interactable
var _scanning := true


func target() -> Interactable:
	return _target


func set_scanning(on: bool) -> void:
	if _scanning == on:
		return
	_scanning = on
	if not _scanning:
		_set_target(null)


func _physics_process(_delta: float) -> void:
	if _scanning:
		_set_target(_look_for_one())


func _look_for_one() -> Interactable:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var query := PhysicsRayQueryParameters3D.create(
		from, from - global_transform.basis.z * reach, mask
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var found := hit["collider"] as Interactable
	if found == null or not found.available or _is_covered(hit["position"] as Vector3):
		return null
	return found


func _is_covered(world_point: Vector3) -> bool:
	if not occluded.is_valid():
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_point):
		return true
	return bool(occluded.call(camera.unproject_position(world_point)))


func _set_target(next: Interactable) -> void:
	if next == _target:
		return
	_target = next
	target_changed.emit(_target)
