class_name LookPad
extends Node

## Drag-to-look, kept as a first-class control rather than a fallback.
##
## iOS has no pointer lock, so this style turns the camera by however far the
## thumb travelled this frame and stops dead when the thumb stops. It is the
## more precise of the two styles and is one setting away at all times; the
## default is the right stick because two fixed sticks are what a thumb can find
## without looking.
##
## Emits raw travel in viewport units. Sensitivity, inversion and clamping
## belong to whatever is being looked through.

signal looked(pixels: Vector2)

var _index := -1


func is_held() -> bool:
	return _index != -1


func press(index: int, _position: Vector2) -> void:
	_index = index


## `delta` is already first-move-guarded and clamped by TouchRouter.
func drag(index: int, delta: Vector2) -> void:
	if index != _index or delta == Vector2.ZERO:
		return
	looked.emit(delta)


func release(index: int) -> void:
	if index == _index:
		_index = -1
