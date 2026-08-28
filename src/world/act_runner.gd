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

## Everything the mounted act's saveable nodes read, keyed by `save_key`.
## `SaveService` provides it, because it already knows how to collect and apply
## exactly that -- this class knows *when*, not *how*.
var collect_act: Callable = func() -> Dictionary: return {}
var apply_act: Callable = func(_states: Dictionary) -> void: pass

@export var acts: Array[PackedScene] = []

## Where the act is added. Its own parent by default, so the act sits beside the
## player and the HUD rather than under a wrapper node that would show up in
## every node path in the game.
@export var mount: NodePath = NodePath("..")

var _index := 0
var _root: Node

## What each act was like when the player walked out of it. An act you leave and
## come back to should be as you left it: the breakers you threw are still
## thrown, the doors you opened are still open, the wrench is still gone.
##
## Without this, travel is one-way in practice -- Act 4's first two puzzles are
## in Act 1's gallery, and arriving to find every breaker back where it started
## would be the building undoing an hour of the player's work.
var _stashes: Dictionary[int, Dictionary] = {}


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
		# Take a copy of the act before it goes. This is the only moment it can
		# be done: after `free()` there is nothing left to ask.
		_stashes[_index] = collect_act.call() as Dictionary
		# Freed rather than queued: the next act is added in this same call, and
		# two acts in the tree at once is the thing this class exists to stop.
		host.remove_child(_root)
		_root.free()

	_index = index
	_root = acts[index].instantiate()
	host.add_child(_root)
	# `add_child` has run the act's `_ready`, so its nodes are in the tree and
	# can be told what they were doing when the player last saw them.
	if _stashes.has(index):
		apply_act.call(_stashes[index])
	act_changed.emit(_root)
	return _root


## Every act's remembered state, for the save. The mounted one is asked fresh:
## its stash is however it was when the player *left* it, which was some time
## ago and is not what they are looking at.
func stashes() -> Dictionary:
	var out := _stashes.duplicate(true)
	out[_index] = collect_act.call()
	return out


func restore_stashes(saved: Dictionary) -> void:
	_stashes.clear()
	for key in saved:
		_stashes[int(key)] = saved[key] as Dictionary


## A new game: forget every act and build one from its scene.
##
## `load_act` on the act already mounted is deliberately a no-op — walking
## through a door you are already behind should not rebuild the building — so
## there has to be a way to say "no, actually, from the start", and clearing the
## stashes is not enough on its own. Clear them and mount, in that order: the
## other order restores the stash on the way out and then saves it again.
func restart(index: int = 0) -> Node:
	_stashes.clear()
	var host := get_node_or_null(mount)
	if host != null and _root != null:
		host.remove_child(_root)
		_root.free()
		_root = null
	return load_act(index)


## Whatever act is already mounted, adopted at startup.
func _mounted_act() -> Node:
	var host := get_node_or_null(mount)
	if host == null:
		return null
	for child in host.get_children():
		if child.is_in_group(&"act"):
			return child
	return null
