class_name Timeclock
extends Node3D

## C-2, the programme's cam-driven 24-hour timeclock.
##
## This is what the throwaway dial lock was standing in for: the same grammar --
## numbered wheels turned with a thumb -- with a reason to exist. Cam timeclocks
## drove lighting schedules for fifty years, and a programme whose whole method
## was *a lamp on a schedule* could not have run without one.
##
## Three wheels. The hour drum says where in the day the clock thinks it is; the
## two cam wheels say which tooth each chamber's cam is cut to. A chamber's lamp
## is on when its cam has come round, and `D-16` -- Emil's cam-cutting notes
## from 1966, with the tooth counts and a worked example -- is the only place
## the relationship is written down.
##
## It decides nothing about doors or keys. It says which circuits are energised,
## and `AnnexLogic` cares about that; keeping the two apart is what stops this
## from becoming a lock with a clock painted on it.

signal changed

## The wheels: hour (24), then one cam position per chamber (12 teeth each).
const HOUR := 0
const TEETH := 12

@export var save_key: StringName = &"timeclock"

## Which chambers this clock drives, in cam-wheel order.
@export var chambers: Array[StringName] = [&"B", &"C"]

@onready var _zone: Interactable = $Zone
@onready var _bank: WheelBank = $Wheels
@onready var _detent: AudioStreamPlayer3D = get_node_or_null("Detent")


func _ready() -> void:
	var counts := PackedInt32Array([24])
	for chamber in chambers:
		counts.append(TEETH)
	_bank.wheels = counts
	_bank.turned.connect(_on_turned)
	_zone.engaged.connect(_bank.lift)
	_zone.disengaged.connect(_bank.lift)
	_zone.pressed.connect(_bank.press)
	_zone.dragged.connect(_on_dragged)
	_zone.lifted.connect(_bank.lift)


func hour() -> int:
	return _bank.digit(HOUR)


## Which tooth chamber `name`'s cam is set to, or -1 for a chamber this clock
## does not drive.
func cam(chamber: StringName) -> int:
	var index := chambers.find(chamber)
	return -1 if index < 0 else _bank.digit(index + 1)


## **The relationship, and the whole of P3.1.** A cam is cut with one tooth per
## two hours of the day, and the lamp is on for the window that tooth is in. So
## a chamber is lit when the drum's current hour falls in its cam's window --
## and it is dark when it does not, which is what the interlock is waiting for.
##
## `D-16` states it as Emil would have: *tooth n covers hours 2n and 2n+1*.
func lit(chamber: StringName) -> bool:
	var tooth := cam(chamber)
	if tooth < 0:
		return false
	return int(hour() / 2) == tooth


## Where a wheel is, for the suite to aim a drag at.
func wheel_position(index: int) -> Vector3:
	return _bank.wheel_position(index)


func digits() -> PackedInt32Array:
	return _bank.digits()


func save_state() -> Dictionary:
	return {"digits": Array(_bank.digits())}


func load_state(state: Dictionary) -> void:
	_bank.set_digits(state.get("digits", []))
	changed.emit()


func _on_dragged(_screen: Vector2, delta: Vector2) -> void:
	_bank.drag(delta)


## One tooth, and it is audible. A drum that turned silently would be a drum
## nobody could count by ear, and counting teeth is the puzzle.
func _on_turned(_index: int, _digit: int) -> void:
	if _detent != null:
		_detent.pitch_scale = randf_range(0.96, 1.05)
		_detent.play()
	changed.emit()
