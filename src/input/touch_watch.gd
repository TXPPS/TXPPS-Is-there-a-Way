class_name TouchWatch
extends Node

## Watches every screen touch, claimed or not, and consumes none.
##
## Two things need to know about touches in general rather than about their own
## touch: the gesture that summons the debug overlay, and the overlay's readout
## of which touch IDs are live. Neither belongs inside a control, so both are
## served from here.
##
## Events arrive via `observe()` from TouchRouter rather than from an `_input()`
## of its own: the router consumes the touches it claims, so a second listener
## would see an arbitrary subset depending on node order.

signal three_finger_tapped

## Fingers required. Three is deliberate: two happen constantly in normal play.
@export_range(2, 5, 1) var finger_count: int = 3
## A tap, not a hold. Fingers must start leaving within this many seconds.
@export_range(0.1, 2.0, 0.05) var tap_window: float = 0.8
## A tap, not a drag. No finger may travel further than this, in viewport units.
@export_range(4.0, 200.0, 1.0) var travel_limit: float = 48.0

var _positions: Dictionary[int, Vector2] = {}
var _travel: Dictionary[int, float] = {}
var _armed_at := -1.0


## Live touch indices, ascending. The overlay shows these so a dropped or
## swapped finger is visible rather than inferred.
func active_indices() -> Array[int]:
	var ids: Array[int] = []
	for index in _positions:
		ids.append(index)
	ids.sort()
	return ids


func observe(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_press(event.index, event.position)
		return
	_release(event.index)


## Travel is measured from this finger's own last position rather than from the
## event's `relative`, for the reason spelled out in TouchRouter.
func _on_drag(event: InputEventScreenDrag) -> void:
	if not _positions.has(event.index):
		return
	_travel[event.index] += (event.position - _positions[event.index]).length()
	_positions[event.index] = event.position


func _press(index: int, position: Vector2) -> void:
	_positions[index] = position
	_travel[index] = 0.0
	if _positions.size() == finger_count and _armed_at < 0.0:
		_armed_at = _seconds()


func _release(index: int) -> void:
	var qualified := _is_tap()
	_positions.erase(index)
	_travel.erase(index)
	if qualified:
		_armed_at = -1.0
		three_finger_tapped.emit()
	elif _positions.is_empty():
		_armed_at = -1.0


func _is_tap() -> bool:
	if _armed_at < 0.0:
		return false
	if _seconds() - _armed_at > tap_window:
		return false
	for index in _travel:
		if _travel[index] > travel_limit:
			return false
	return true


func _seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
