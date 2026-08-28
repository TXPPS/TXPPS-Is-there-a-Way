class_name BoxMeshBuilder
extends RefCounted

## Many boxes, one mesh.
##
## Shared by `RoomBox` and `SlabGroup`, which had the same problem for the same
## reason: a level built out of arithmetic emits a great many axis-aligned
## boxes, and one `MeshInstance3D` each is one draw call each. Twenty rooms of
## walls plus a hundred props of dressing is several hundred draws before a
## single lamp is lit.
##
## Safe here in a way it would not be in a hand-built level, because every
## surface material in this game is triplanar and takes its coordinates from
## world position. Baking boxes into one mesh would ruin a UV-mapped material
## and does nothing at all to these.


## Six quads, wound so the outside faces out. Normals are the axis directions,
## because these are axis-aligned boxes and nothing here rotates.
static func append_box(surface: SurfaceTool, size: Vector3, at: Vector3) -> void:
	var half := size * 0.5
	for axis in 3:
		for direction in [1.0, -1.0]:
			var normal := Vector3.ZERO
			normal[axis] = direction
			var u := Vector3.ZERO
			var v := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3] * direction
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var middle := at + normal * half[axis]
			var corners := [
				middle - u - v, middle + u - v, middle + u + v, middle - u + v,
			]
			surface.set_normal(normal)
			for index in [0, 1, 2, 0, 2, 3]:
				surface.set_uv(Vector2.ZERO)
				surface.add_vertex(corners[index])


## `boxes` is an Array of [size, position] pairs. Returns null for none.
static func build(boxes: Array) -> ArrayMesh:
	if boxes.is_empty():
		return null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in boxes:
		append_box(surface, entry[0] as Vector3, entry[1] as Vector3)
	return surface.commit()
