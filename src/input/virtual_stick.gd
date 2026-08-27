class_name VirtualStick
extends Control

## A fixed on-screen stick. The base never moves.
##
## The Control's own position *is* the centre of the stick, placed by Hud from
## HudLayout, and nothing in here ever writes it. That is the whole fix for the
## base that used to travel with the thumb: the previous stick was a floating
## one that planted its origin at whatever position a touch-down reported, so
## any touch-down -- including one iOS re-issues after cancelling a gesture
## mid-drag -- re-planted the base under the moving thumb.
##
## Touches arrive from TouchRouter, which owns them. This never listens to input
## directly, so it cannot see a touch that belongs to the other stick.

signal value_changed(value: Vector2)

## Shaped deflection. x = right, y = up (screen y is flipped here so callers
## never have to remember that). Length 0..1.
var value := Vector2.ZERO

var tuning: TouchTuning
var radius := 96.0
var knob_radius := 34.0
## Draws a cross through the knob, so the two sticks are told apart by shape and
## not only by which corner they sit in. Driven by the colourblind cue setting.
var marker := false

var _index := -1
## Knob offset from the centre, in viewport units, already clamped to `radius`.
var _knob := Vector2.ZERO
var _glow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func is_held() -> bool:
	return _index != -1


## Where the knob sits relative to the fixed centre, in viewport units. Read by
## the tests that assert the base does not travel and the knob does not escape.
func knob_offset() -> Vector2:
	return _knob


## Called by Hud when a claim on this stick begins.
func press(index: int, position: Vector2) -> void:
	_index = index
	_move_knob(position)
	set_process(true)


func drag(index: int, position: Vector2) -> void:
	if index != _index:
		return
	_move_knob(position)


## Recentres instantly. A stick that eases back to zero is a stick that keeps
## turning the camera after the thumb has gone.
func release(index: int) -> void:
	if index != _index:
		return
	_index = -1
	_knob = Vector2.ZERO
	_set_value(Vector2.ZERO)
	queue_redraw()


func _move_knob(position: Vector2) -> void:
	_knob = (position - global_position).limit_length(radius)
	var raw := _knob / maxf(radius, 0.001)
	_set_value(tuning.shape(Vector2(raw.x, -raw.y)))
	queue_redraw()


func _set_value(next: Vector2) -> void:
	if next.is_equal_approx(value):
		return
	value = next
	value_changed.emit(value)


func _process(delta: float) -> void:
	var target := 1.0 if is_held() else 0.0
	var step := delta / maxf(tuning.fade_time, 0.001)
	var next := move_toward(_glow, target, step)
	if is_equal_approx(next, _glow):
		if not is_held():
			set_process(false)
		return
	_glow = next
	queue_redraw()


func _draw() -> void:
	var alpha := lerpf(tuning.rest_opacity, tuning.active_opacity, _glow)
	var ring := Color(tuning.tint, alpha * 0.6)
	var knob := Color(tuning.tint, alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, ring, 2.0, true)
	draw_arc(Vector2.ZERO, knob_radius * 0.34, 0.0, TAU, 24, ring, 1.0, true)
	draw_circle(_knob, knob_radius, knob)
	if marker:
		_draw_marker(knob)


func _draw_marker(colour: Color) -> void:
	var arm := knob_radius * 0.5
	var ink := Color(0.03, 0.04, 0.05, colour.a)
	draw_line(_knob - Vector2(arm, 0.0), _knob + Vector2(arm, 0.0), ink, 2.0)
	draw_line(_knob - Vector2(0.0, arm), _knob + Vector2(0.0, arm), ink, 2.0)
