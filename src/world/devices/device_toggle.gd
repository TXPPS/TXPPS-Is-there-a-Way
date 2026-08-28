class_name DeviceToggle
extends Node3D

## A two-state control you can see the state of from across the room.
##
## A breaker, a disconnect, a fuse in or out. The handle moves, so the state is
## legible without reading anything -- which matters in a building where the
## player will be looking at a wall of them by Act 2 and the panel schedule only
## tells you what each one is *for*.
##
## Instant: flipping it does not lock the HUD to it. Whether it does anything is
## somebody else's problem; this reports what it is and what was done to it.

signal toggled(on: bool)

## Stable across builds. Also the save key, because a breaker's position is
## exactly the kind of state that has to survive a reload.
@export var save_key: StringName = &""

## What is written beside it on the panel. Never a hint: `LT-6 STAIR TWR` is
## what a panel schedule says, and what it means is the player's problem.
@export var label: String = ""

@export var on: bool = true:
	set(value):
		on = value
		_apply()

@export var prompt_when_on: String = "Pull it out"
@export var prompt_when_off: String = "Push it in"

## How far the handle moves, in its own local space.
@export var travel: Vector3 = Vector3(0.0, -0.07, 0.0)

@onready var _zone: Interactable = $Zone
@onready var _handle: Node3D = $Handle

var _home := Vector3.ZERO


func _ready() -> void:
	_home = _handle.position
	_zone.instant = true
	_zone.engaged.connect(_on_engaged)
	_apply()


func save_state() -> Dictionary:
	return {"on": on}


func load_state(state: Dictionary) -> void:
	on = bool(state.get("on", on))


func _on_engaged() -> void:
	on = not on
	Haptics.tap()
	toggled.emit(on)


func _apply() -> void:
	if _handle == null:
		return
	_handle.position = _home if on else _home + travel
	if _zone != null:
		_zone.prompt = (prompt_when_on if on else prompt_when_off)
		if not label.is_empty():
			_zone.prompt += "  (%s)" % label
