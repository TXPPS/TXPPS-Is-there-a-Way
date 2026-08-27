class_name LookPad
extends Control

## Drag-to-look region. iOS has no pointer lock, so looking is a drag gesture:
## the camera turns by however far the thumb travelled this frame, and stops
## dead when the thumb stops. Emits raw pixel deltas; sensitivity, smoothing
## and invert all belong to the thing being looked through (PlayerTuning).

signal looked(pixels: Vector2)

var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		looked.emit(event.relative)
		get_viewport().set_input_as_handled()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index != -1 or not get_global_rect().has_point(event.position):
			return
		_touch_index = event.index
		get_viewport().set_input_as_handled()
	elif event.index == _touch_index:
		_touch_index = -1
		get_viewport().set_input_as_handled()
