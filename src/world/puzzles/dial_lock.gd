class_name DialLock
extends Node3D

## Three numbered dials and a latch. A throwaway, and the first user of the
## focused-interaction framework.
##
## Its whole job is to be something to engage with: it proves the ray finds a
## target, that engaging hands the gestures over, that a drag on the right wheel
## turns the right wheel, and that letting go gives the camera back. P1 replaces
## it with a puzzle that means something.

signal solved

const DIAL_SCENE := preload("res://src/world/puzzles/dial.tscn")
const LOCKED := Color(0.62, 0.16, 0.13)
const OPEN := Color(0.30, 0.78, 0.42)

@export var combination: PackedInt32Array = PackedInt32Array([4, 1, 7])

## Metres between wheel centres.
@export_range(0.1, 0.5, 0.01) var spacing: float = 0.24

## Viewport units of vertical travel per click. Roughly a thumb's width, so a
## deliberate pull moves one number and a nudge moves none.
@export_range(10.0, 200.0, 1.0) var units_per_step: float = 46.0

@onready var _zone: Interactable = $Zone
@onready var _indicator: MeshInstance3D = $Indicator

var _dials: Array[Dial] = []
var _lamp: StandardMaterial3D
var _held := -1
var _travel := 0.0
var _open := false


func _ready() -> void:
	_lamp = _indicator.get_active_material(0).duplicate() as StandardMaterial3D
	_indicator.material_override = _lamp
	_build_dials()
	_light(LOCKED)
	_zone.engaged.connect(_on_engaged)
	_zone.disengaged.connect(_on_disengaged)
	_zone.pressed.connect(_on_pressed)
	_zone.dragged.connect(_on_dragged)
	_zone.lifted.connect(_on_lifted)


## The dials as they read, for the tests and the debug overlay.
func digits() -> PackedInt32Array:
	var out := PackedInt32Array()
	for dial in _dials:
		out.append(dial.digit)
	return out


func is_open() -> bool:
	return _open


## Where a wheel is in the world. Used by the suite to aim a drag at one.
func dial_position(index: int) -> Vector3:
	return _dials[index].global_position if index < _dials.size() else global_position


func _build_dials() -> void:
	var last := float(combination.size() - 1)
	for index in combination.size():
		var dial := DIAL_SCENE.instantiate() as Dial
		dial.position.x = (float(index) - last * 0.5) * spacing
		$Dials.add_child(dial)
		_dials.append(dial)


func _on_engaged() -> void:
	_light(OPEN if _open else LOCKED)


func _on_disengaged() -> void:
	_on_lifted()


## The wheel nearest the thumb, measured on screen rather than in the world: the
## player is pointing at what they can see, not at a position in metres.
func _on_pressed(screen: Vector2) -> void:
	_held = _nearest(screen)
	_travel = 0.0
	for index in _dials.size():
		_dials[index].highlight(index == _held)


func _on_dragged(_screen: Vector2, delta: Vector2) -> void:
	if _held < 0 or _open:
		return
	# Screen y grows downward; pulling up counts up.
	_travel -= delta.y
	while absf(_travel) >= units_per_step:
		var step := 1 if _travel > 0.0 else -1
		_travel -= float(step) * units_per_step
		_dials[_held].set_digit(_dials[_held].digit + step)
		Haptics.tap()
		_check()


func _on_lifted() -> void:
	_held = -1
	for dial in _dials:
		dial.highlight(false)


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


func _check() -> void:
	if _open or digits() != combination:
		return
	_open = true
	_zone.available = false
	_light(OPEN)
	solved.emit()


func _light(colour: Color) -> void:
	_lamp.albedo_color = colour
	_lamp.emission = colour
