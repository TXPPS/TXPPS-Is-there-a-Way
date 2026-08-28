class_name ActRunner
extends Node

## Which act is mounted, and the only thing that swaps one for another.
##
## Acts are big: a few hundred nodes, their own lights, their own logic. Two of
## them in the tree at once is not a memory problem so much as a correctness
## one -- `PowerhouseLogic` finds its lamps through a group, and a second act's
## lamps in that group would answer to the wrong panel. So exactly one act is
## mounted, and this is what mounts it.
##
## The current act is part of the save, but *not* through the `saveable` group:
## a save from Act 2 restored while Act 1 is mounted would have every one of its
## keys ignored, because the nodes those keys name do not exist yet. The act has
## to be switched before the node states are applied, so it lives in the save's
## own header alongside the checkpoint. See `SaveGame` v2.

signal act_changed(root: Node)

@export var acts: Array[PackedScene] = []

## Where the act is added. Its own parent by default, so the act sits beside the
## player and the HUD rather than under a wrapper node that would show up in
## every node path in the game.
@export var mount: NodePath = NodePath("..")

var _index := 0
var _root: Node


func _ready() -> void:
	# The first act is already in the scene, placed by hand, so that opening the
	# editor shows a level rather than an empty root. Adopt it rather than
	# replacing it with an identical copy.
	_root = _mounted_act()


func current() -> int:
	return _index


func root() -> Node:
	return _root


## Which act a scene file belongs to, or -1 for one that is not in the list.
func index_of(scene: PackedScene) -> int:
	return acts.find(scene)


## Swaps the mounted act. Synchronous on purpose: `add_child` runs the new act's
## `_ready` before it returns, so by the time this comes back the new act's
## nodes are in the tree and in their groups, and a save can be applied over
## them in the same frame.
func load_act(index: int) -> Node:
	if index < 0 or index >= acts.size():
		push_error("No act %d; there are %d." % [index, acts.size()])
		return _root
	if index == _index and _root != null:
		return _root

	var host := get_node_or_null(mount)
	if host == null:
		push_error("ActRunner has nowhere to mount an act.")
		return _root

	if _root != null:
		# Freed rather than queued: the next act is added in this same call, and
		# two acts in the tree at once is the thing this class exists to stop.
		host.remove_child(_root)
		_root.free()

	_index = index
	_root = acts[index].instantiate()
	host.add_child(_root)
	act_changed.emit(_root)
	return _root


## Whatever act is already mounted, adopted at startup.
func _mounted_act() -> Node:
	var host := get_node_or_null(mount)
	if host == null:
		return null
	for child in host.get_children():
		if child.is_in_group(&"act"):
			return child
	return null
