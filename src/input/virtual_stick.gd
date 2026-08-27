class_name VirtualStick
extends Control

## Floating locomotion stick. It has no fixed position: it materialises wherever
## the thumb lands inside this Control's rect, which is what makes a phone FPS
## playable without looking down at your hands.
##
## Reads `value` for the current deflection (-1..1 per axis, y positive = forward).
## Draws itself with primitives; there is no texture to load or licence.

@export var tuning: TouchTuning

var value := Vector2.ZERO

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _visibility := 0.0


func _ready() -> void:
	assert(tuning != null, "VirtualStick needs a TouchTuning resource assigned.")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var target := 1.0 if _touch_index != -1 else 0.0
	var step := delta / maxf(tuning.fade_out_time, 0.001)
	var next := move_toward(_visibility, target, step)
	if not is_equal_approx(next, _visibility):
		_visibility = next
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index != -1 or not get_global_rect().has_point(event.position):
			return
		_touch_index = event.index
		_origin = event.position
		_knob = event.position
		_update_value()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.index == _touch_index:
		_touch_index = -1
		value = Vector2.ZERO
		queue_redraw()
		get_viewport().set_input_as_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_knob = event.position
	_update_value()
	queue_redraw()
	get_viewport().set_input_as_handled()


func _update_value() -> void:
	var offset := (_knob - _origin) / tuning.stick_radius
	var magnitude := offset.length()
	if magnitude <= tuning.stick_deadzone:
		value = Vector2.ZERO
		return
	# Rescale past the deadzone so the first millimetre of real travel is not
	# a jump from 0 to 0.1.
	var scaled := (magnitude - tuning.stick_deadzone) / (1.0 - tuning.stick_deadzone)
	var direction := offset / magnitude
	# Screen y grows downward; forward is up.
	value = Vector2(direction.x, -direction.y) * minf(scaled, 1.0)


func _draw() -> void:
	if _visibility <= 0.001:
		return
	var alpha := tuning.opacity * _visibility
	var ring := Color(tuning.tint, alpha * 0.55)
	var knob := Color(tuning.tint, alpha)
	var local_origin := _origin - global_position
	var local_knob := local_origin + (_knob - _origin).limit_length(tuning.stick_radius)
	draw_arc(local_origin, tuning.stick_radius, 0.0, TAU, 48, ring, 2.0, true)
	draw_circle(local_knob, tuning.knob_radius, knob)
