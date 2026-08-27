extends RefCounted

## Synthetic touches, pushed straight at the viewport.
##
## Positions are viewport coordinates and are pushed as local, so the tests read
## the same numbers HudLayout placed the controls at.
##
## `relative` is settable and the tests set it wrong on purpose. Godot 4.6's web
## display server computes that field against the wrong finger whenever more
## than one is down (see TouchRouter); nothing downstream of the router may read
## it, and the way to prove that is to lie in it and assert nothing moves.

var _root: Window


func _init(root: Window) -> void:
	_root = root


func press(index: int, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = true
	_root.push_input(event, true)


func lift(index: int, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = false
	_root.push_input(event, true)


func drag(index: int, position: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	_root.push_input(event, true)
