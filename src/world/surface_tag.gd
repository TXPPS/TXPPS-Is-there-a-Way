class_name SurfaceTag
extends Node

## Marks the body it is a child of as being made of something.
##
## A component rather than a property on the body, so any CollisionObject3D can
## carry one without inheriting from a special class, and so a body can be
## retagged in the editor without touching a script.

@export var surface: SurfaceType


## The surface of whatever `body` is, or null. Walks up the tree so a tag on a
## room's root applies to every collider inside it unless one overrides it.
static func of(body: Node) -> SurfaceType:
	var node := body
	while node != null:
		for child in node.get_children():
			if child is SurfaceTag:
				var tag := child as SurfaceTag
				if tag.surface != null:
					return tag.surface
		node = node.get_parent()
	return null
