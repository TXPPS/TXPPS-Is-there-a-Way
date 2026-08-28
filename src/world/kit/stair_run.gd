@tool
class_name StairRun
extends Node3D

## A flight of stairs you can actually walk down.
##
## Godot's CharacterBody3D does not step up geometry, so a stair built as boxes
## is a wall with a nice pattern on it. The steps here are visual; what the
## player walks on is one ramp collider through the nosings, which is the shape
## the eye reads anyway.
##
## Descends along +Z from the node's origin, which is the top nosing. Rotate the
## node to point it somewhere else.

## Set to a step number to leave it out. The gap is real -- you can see through
## it -- and the ramp still carries you over, which is the difference between a
## hazard and a wall. Act 1's stair tower is missing its third step, and there
## is a card about it.
@export_range(0, 40, 1) var missing_step: int = 0:
	set(value):
		missing_step = value
		_rebuild()

@export_range(2, 40, 1) var steps: int = 13:
	set(value):
		steps = value
		_rebuild()

@export_range(0.1, 0.4, 0.005) var rise: float = 0.3:
	set(value):
		rise = value
		_rebuild()

@export_range(0.15, 0.6, 0.005) var tread: float = 0.315:
	set(value):
		tread = value
		_rebuild()

@export_range(0.6, 4.0, 0.1) var width: float = 1.4:
	set(value):
		width = value
		_rebuild()

@export var material: Material:
	set(value):
		material = value
		_rebuild()

## Thickness of the invisible ramp under the nosings.
const RAMP_DEPTH := 0.4

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


## Where the bottom nosing lands, in local space. The room below has to meet it.
func foot() -> Vector3:
	return Vector3(0.0, -rise * float(steps), tread * float(steps))


func pitch_degrees() -> float:
	return rad_to_deg(atan2(rise, tread))


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.free()
	_build_ramp()
	for index in range(1, steps + 1):
		if index == missing_step:
			continue
		_build_step(index)


## One box through the nosings. The player walks on its top face, which passes
## exactly through the corner of every step, so the ramp is invisible and the
## footing matches what is drawn.
func _build_ramp() -> void:
	var drop := rise * float(steps)
	var run := tread * float(steps)
	var length := sqrt(drop * drop + run * run)
	var angle := atan2(drop, run)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, RAMP_DEPTH, length)
	shape.shape = box
	# Down the slope's own normal by half its depth, so the top face is the line
	# through the nosings rather than the centre of the slab.
	var normal := Vector3(0.0, cos(angle), sin(angle))
	shape.transform = Transform3D(
		Basis(Vector3.RIGHT, angle),
		Vector3(0.0, -drop * 0.5, run * 0.5) - normal * (RAMP_DEPTH * 0.5)
	)
	body.add_child(shape)
	add_child(body)


func _build_step(index: int) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, rise, tread)
	mesh.mesh = box
	if material != null:
		mesh.material_override = material
	mesh.position = Vector3(
		0.0,
		-rise * float(index) + rise * 0.5,
		tread * (float(index) - 0.5)
	)
	add_child(mesh)
