@tool
class_name Slab
extends Node3D

## A box that is both seen and stood on.
##
## The kit's smallest piece. A landing, a plinth, a bench, a step: anything that
## is one rectangle of concrete or steel and needs a collider under it.

@export var size: Vector3 = Vector3(1.0, 0.2, 1.0):
	set(value):
		size = value
		_rebuild()

@export var material: Material:
	set(value):
		material = value
		_rebuild()

## Off for a purely visual piece -- a fascia, a lamp housing, a sign.
@export var solid: bool = true:
	set(value):
		solid = value
		_rebuild()

const BUILT := &"kit_built"

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	# Only what this built. Anything placed on this node in the scene -- a
	# surface tag, a light, a sound -- is somebody else's and stays.
	for child in get_children():
		if child.is_in_group(BUILT):
			child.free()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.add_to_group(BUILT)
	if material != null:
		mesh.material_override = material
	add_child(mesh)
	if not solid:
		return
	var body := StaticBody3D.new()
	body.add_to_group(BUILT)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	body.add_child(shape)
	add_child(body)
