class_name DeviceSelector
extends Node3D

## A rotary selector with named positions, like the transfer switch on a
## standby set: `NORMAL / TEST / EMERGENCY`.
##
## The positions are exported as text because the plate beside the switch is the
## only place the player learns what they mean, and the plate and the switch
## should not be able to disagree. Whether a position does anything is somebody
## else's problem -- this reports where the handle is.
##
## It wraps. A three-position switch that stops dead at each end would be more
## faithful to the hardware and would strand a player who overshot, so it does
## not: the handle goes round.

signal moved(position_name: StringName)

@export var save_key: StringName = &""

## What is engraved on the plate, in order, clockwise.
@export var positions: Array[StringName] = [&"NORMAL", &"TEST", &"EMERGENCY"]

@export var index: int = 0:
	set(value):
		index = 0 if positions.is_empty() else posmod(value, positions.size())
		_apply()

## How far the handle swings between adjacent positions.
@export var radians_per_step: float = TAU / 8.0

@onready var _zone: Interactable = $Zone
@onready var _handle: Node3D = $Handle
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	_zone.instant = true
	_zone.engaged.connect(_on_engaged)
	_apply()


func save_state() -> Dictionary:
	return {"index": index}


func load_state(state: Dictionary) -> void:
	index = int(state.get("index", index))


## Where the handle is, by name. The empty name for a selector with no plate,
## which is a scene-authoring mistake rather than a state worth handling.
func selected() -> StringName:
	if positions.is_empty():
		return &""
	return positions[index]


func at(position_name: StringName) -> bool:
	return selected() == position_name


## Puts the handle on a named position without a gesture, for a save coming back
## or a test setting up. Returns false if the plate has no such position.
func select(position_name: StringName) -> bool:
	var found := positions.find(position_name)
	if found < 0:
		return false
	index = found
	return true


func _on_engaged() -> void:
	index += 1
	Haptics.tap()
	_sound.pitch_scale = 1.18
	_sound.play()
	moved.emit(selected())


func _apply() -> void:
	if _handle != null:
		_handle.rotation.z = -float(index) * radians_per_step
	if _zone != null:
		_zone.prompt = "Turn the switch  (%s)" % selected()
