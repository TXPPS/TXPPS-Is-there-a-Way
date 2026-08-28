class_name DeviceValve
extends Node3D

## A handwheel valve, which takes more than one gesture to open.
##
## Deliberately not a toggle. A gate valve is several turns from shut to open,
## and making the player turn it several times is not padding: it is the only
## way the act can say "this is a valve and not a switch" without a line of text
## saying so. It also gives the wheel somewhere to travel, so the state is
## legible from the wheel rather than from a prompt.
##
## Turning always moves toward whichever state it is not in, so a player who
## opens it and keeps turning closes it again -- which is what a handwheel does.

signal opened
signal closed

@export var save_key: StringName = &""

## What the tag on the body says. `DAY TANK ISOL` is a real valve tag; what it
## means is the player's problem, and the service card answers it.
@export var label: String = ""

## Turns from one end to the other. Three is enough to feel like a valve and
## few enough that nobody resents it.
@export var turns_to_open: int = 3

@export var open: bool = false:
	set(value):
		open = value
		_turned = turns_to_open if open else 0
		_apply()

## Radians of wheel per turn. Three-quarters, so successive turns land the
## spokes somewhere different and the wheel reads as moving.
@export var radians_per_turn: float = TAU * 0.75

@onready var _zone: Interactable = $Zone
@onready var _wheel: Node3D = $Wheel
@onready var _sound: AudioStreamPlayer3D = $Sound

## How far through the travel it is, in turns.
var _turned := 0


func _ready() -> void:
	_zone.instant = true
	_zone.engaged.connect(_on_engaged)
	_apply()


func save_state() -> Dictionary:
	return {"open": open, "turned": _turned}


func load_state(state: Dictionary) -> void:
	open = bool(state.get("open", open))
	_turned = int(state.get("turned", _turned))
	_apply()


## Turns worth of travel left before it reaches the other end. Zero means the
## next turn changes the state.
func remaining() -> int:
	return (turns_to_open - _turned) if not open else _turned


func _on_engaged() -> void:
	_turned += -1 if open else 1
	Haptics.tap()
	_sound.pitch_scale = randf_range(0.94, 1.06)
	_sound.play()

	if not open and _turned >= turns_to_open:
		open = true
		opened.emit()
	elif open and _turned <= 0:
		open = false
		closed.emit()
	else:
		_apply()


func _apply() -> void:
	if _wheel == null:
		return
	_wheel.rotation.z = float(_turned) * radians_per_turn
	if _zone == null:
		return
	_zone.prompt = "Turn the wheel"
	if not label.is_empty():
		_zone.prompt += "  (%s)" % label
