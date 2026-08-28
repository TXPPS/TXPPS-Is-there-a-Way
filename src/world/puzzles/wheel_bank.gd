class_name WheelBank
extends Node3D

## A row of numbered wheels the player turns with a thumb.
##
## The grammar, on its own. Two things in this game are a row of wheels — the
## throwaway dial lock that proved the focused-interaction framework, and the
## programme's cam timeclock that replaces it (`PUZZLES.md` P3.1) — and they
## differ entirely in what the numbers *mean*. So the numbers are here and the
## meaning is not: this reports what the wheels read and emits when they change,
## and whatever owns it decides whether that is a combination, a schedule, or
## nothing at all.
##
## It does not own the `Interactable`. Its owner does, and hands the gestures
## down, because a bank of wheels is a part of a device rather than a device.

signal turned(index: int, digit: int)

const DIAL_SCENE := preload("res://src/world/puzzles/dial.tscn")

## How many wheels, and what each one counts to. One entry per wheel.
##
## Setting it rebuilds, and it has to: a child's `_ready` runs before its
## parent's, so a `Timeclock` that assigns this in its own `_ready` is assigning
## it *after* the bank would otherwise have built. That shipped as an hour drum
## that counted to ten, which reads perfectly plausibly right up to 09:00.
@export var wheels: PackedInt32Array = PackedInt32Array([10, 10, 10]):
	set(value):
		wheels = value
		if _built:
			_build()

## Metres between wheel centres.
@export_range(0.1, 0.5, 0.01) var spacing: float = 0.24

## Viewport units of vertical travel per click. Roughly a thumb's width, so a
## deliberate pull moves one number and a nudge moves none.
@export_range(10.0, 200.0, 1.0) var units_per_step: float = 46.0

## While false the wheels can be pointed at but not moved -- a solved lock, or a
## clock somebody has already set and sealed.
@export var turnable: bool = true

var _dials: Array[Dial] = []
var _held := -1
var _travel := 0.0
var _built := false


func _ready() -> void:
	_built = true
	_build()


func count() -> int:
	return _dials.size()


func digits() -> PackedInt32Array:
	var out := PackedInt32Array()
	for dial in _dials:
		out.append(dial.digit)
	return out


func digit(index: int) -> int:
	return _dials[index].digit if index >= 0 and index < _dials.size() else 0


func set_digits(values: Array) -> void:
	for index in mini(values.size(), _dials.size()):
		_dials[index].set_digit(int(values[index]))


## Where a wheel is in the world. Used by the suite to aim a drag at one.
func wheel_position(index: int) -> Vector3:
	return _dials[index].global_position if index < _dials.size() else global_position


# --- gestures, handed down by whatever owns the Interactable ----------------

## The wheel nearest the thumb, measured on screen rather than in the world: the
## player is pointing at what they can see, not at a position in metres.
func press(screen: Vector2) -> void:
	_held = _nearest(screen)
	_travel = 0.0
	for index in _dials.size():
		_dials[index].highlight(index == _held)


func drag(delta: Vector2) -> void:
	if _held < 0 or not turnable:
		return
	# Screen y grows downward; pulling up counts up.
	_travel -= delta.y
	while absf(_travel) >= units_per_step:
		var step := 1 if _travel > 0.0 else -1
		_travel -= float(step) * units_per_step
		_dials[_held].set_digit(_dials[_held].digit + step)
		Haptics.tap()
		turned.emit(_held, _dials[_held].digit)


func lift() -> void:
	_held = -1
	for dial in _dials:
		dial.highlight(false)


func _build() -> void:
	for dial in _dials:
		dial.free()
	_dials.clear()
	_held = -1
	var last := float(wheels.size() - 1)
	for index in wheels.size():
		var dial := DIAL_SCENE.instantiate() as Dial
		dial.position.x = (float(index) - last * 0.5) * spacing
		dial.modulus = wheels[index]
		add_child(dial)
		_dials.append(dial)


func _nearest(screen: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1
	var best := -1
	var closest := INF
	for index in _dials.size():
		if camera.is_position_behind(_dials[index].global_position):
			continue
		var at := camera.unproject_position(_dials[index].global_position)
		var distance := absf(at.x - screen.x)
		if distance < closest:
			closest = distance
			best = index
	return best
