class_name SlabGroup
extends Node3D

## A pile of boxes that draws once.
##
## Dressing is many small solids -- bunks, drums, cartons, a table, a tank, a
## relay panel -- and each one was a `Slab` with its own `MeshInstance3D`. That
## is fine for six and wrong for a hundred: it cost more draw calls than the
## rooms did.
##
## Colliders stay one per box. Physics does not cost draw calls, a box shape is
## the cheapest collider there is, and one concave mesh for a room's worth of
## furniture would be slower to test against and far worse to debug.

@export var sizes: PackedVector3Array = PackedVector3Array()
@export var positions: PackedVector3Array = PackedVector3Array()
@export var material: Material
@export var solid: bool = true


func _ready() -> void:
	var boxes: Array = []
	for index in mini(sizes.size(), positions.size()):
		boxes.append([sizes[index], positions[index]])
	var mesh := BoxMeshBuilder.build(boxes)
	if mesh == null:
		return

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	add_child(instance)

	if not solid:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for index in boxes.size():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = boxes[index][0]
		shape.shape = box
		shape.position = boxes[index][1]
		body.add_child(shape)
	add_child(body)
