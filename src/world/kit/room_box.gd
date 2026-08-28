@tool
class_name RoomBox
extends Node3D

## A concrete box with holes in it, built from its dimensions.
##
## The modular kit `ART_BIBLE.md` asks for, in the form that is actually useful
## before there is a desktop editor session: a room is six numbers and a list of
## openings, not forty hand-placed nodes. Everything lands on the 0.5 m grid, so
## the hand-authored kit that replaces this in P7 drops into the same footprints.
##
## Built at load rather than baked into the scene file, which keeps the level's
## .tscn readable -- a room you can edit by changing one number is a room that
## gets edited.
##
## Draw calls: one mesh per segment, so a room with two doorways is about a
## dozen. `docs/BUDGETS.md` caps visible draw calls at 120 and the browser suite
## asserts it; if a level ever gets close, the answer is merging the static
## geometry per room, not fewer rooms.

## Interior clear dimensions, in metres. Every value should be a multiple of 0.5.
@export var interior: Vector3 = Vector3(6.0, 3.0, 6.0):
	set(value):
		interior = value
		_rebuild()

@export_range(0.1, 1.0, 0.05) var thickness: float = 0.4:
	set(value):
		thickness = value
		_rebuild()

## Holes in the walls. See `Opening`; the sill is what makes a doorway partway
## up a stair shaft's wall expressible, and therefore what makes a level with
## more than one floor possible.
@export var openings: Array[Opening] = []:
	set(value):
		openings = value
		_rebuild()

@export var wall_material: Material:
	set(value):
		wall_material = value
		_rebuild()

@export var floor_material: Material:
	set(value):
		floor_material = value
		_rebuild()

## Leave the ceiling off where another box sits on top.
@export var roofed: bool = true:
	set(value):
		roofed = value
		_rebuild()

## Leave the floor off where this box sits on top of another, or over a shaft.
@export var floored: bool = true:
	set(value):
		floored = value
		_rebuild()

## Faces to leave out. Two rooms that share a wall must not both build it: the
## surfaces would be coplanar and fight, and the level would carry twice the
## geometry for the privilege. The room whose doorway it is keeps it.
@export var omit_walls: Array[Opening.Wall] = []:
	set(value):
		omit_walls = value
		_rebuild()

const GROUP := &"room_geometry"

var _mesh := BoxMesh.new()
var _body: StaticBody3D
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
	var body := StaticBody3D.new()
	_body = body
	body.name = "Shell"
	body.add_to_group(BUILT)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = self

	var outer := Vector2(interior.x + thickness * 2.0, interior.z + thickness * 2.0)
	if floored:
		_slab(body, Vector3(outer.x, thickness, outer.y),
			Vector3(0.0, -thickness * 0.5, 0.0), floor_material)
	if roofed:
		_slab(body, Vector3(outer.x, thickness, outer.y),
			Vector3(0.0, interior.y + thickness * 0.5, 0.0), floor_material)
	for wall in [Opening.Wall.NORTH, Opening.Wall.SOUTH, Opening.Wall.WEST, Opening.Wall.EAST]:
		if not omit_walls.has(wall):
			_wall(body, wall)


## One wall, minus its openings. Each opening leaves a left piece, a right piece
## and a header; the pieces are emitted in order along the wall so two openings
## in one wall work without any special case.
func _wall(body: StaticBody3D, wall: Opening.Wall) -> void:
	var along_x := wall == Opening.Wall.NORTH or wall == Opening.Wall.SOUTH
	var length := (interior.x + thickness * 2.0) if along_x else interior.z
	var depth := thickness
	var centre := _wall_centre(wall)

	var cuts: Array[Opening] = []
	for opening in openings:
		if opening != null and opening.wall == wall:
			cuts.append(opening)
	cuts.sort_custom(func(a: Opening, b: Opening) -> bool: return a.offset < b.offset)

	var edge := -length * 0.5
	for cut in cuts:
		var start := cut.offset - cut.width * 0.5
		var end := cut.offset + cut.width * 0.5
		if start > edge:
			_segment(along_x, edge, start, 0.0, interior.y, depth, centre)
		# Under the sill, and over the head. Either can be nothing.
		if cut.sill > 0.0:
			_segment(along_x, start, end, 0.0, cut.sill, depth, centre)
		var head := cut.sill + cut.height
		if head < interior.y:
			_segment(along_x, start, end, head, interior.y - head, depth, centre)
		edge = end
	if edge < length * 0.5:
		_segment(along_x, edge, length * 0.5, 0.0, interior.y, depth, centre)


func _wall_centre(wall: Opening.Wall) -> Vector3:
	var half := Vector3(interior.x, interior.y, interior.z) * 0.5
	var offset := half.z + thickness * 0.5
	match wall:
		Opening.Wall.NORTH: return Vector3(0.0, 0.0, -offset)
		Opening.Wall.SOUTH: return Vector3(0.0, 0.0, offset)
		Opening.Wall.WEST: return Vector3(-(half.x + thickness * 0.5), 0.0, 0.0)
		_: return Vector3(half.x + thickness * 0.5, 0.0, 0.0)


func _segment(
	along_x: bool, from: float, to: float,
	bottom: float, height: float, depth: float, centre: Vector3
) -> void:
	var span := to - from
	if span <= 0.001 or height <= 0.001:
		return
	var middle := (from + to) * 0.5
	var size := Vector3(span, height, depth) if along_x else Vector3(depth, height, span)
	var at := centre + (
		Vector3(middle, bottom + height * 0.5, 0.0) if along_x
		else Vector3(0.0, bottom + height * 0.5, middle)
	)
	_slab(_body, size, at, wall_material)


func _slab(body: StaticBody3D, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _mesh
	mesh.transform = Transform3D(Basis().scaled(size), at)
	if material != null:
		mesh.material_override = material
	mesh.add_to_group(GROUP)
	mesh.add_to_group(BUILT)
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	if Engine.is_editor_hint():
		mesh.owner = self
		shape.owner = self
