class_name DeviceDoor
extends Node3D

## A door that is shut until something else says otherwise.
##
## The leaf carries its own collider, so a shut door is a wall and an open one
## is a hole -- there is no separate "can the player pass" flag to get out of
## step with what is drawn.
##
## It has no opinion about *why* it opens. Every door in Act 1 is opened by the
## thing that should open it: an interlock releasing a key, a dog coming free, a
## bell being answered. See docs/PUZZLES.md.

signal opened
signal closed

@export var save_key: StringName = &""

@export var open: bool = false:
	set(value):
		var was := open
		open = value
		_apply()
		if was == value:
			return
		if is_node_ready() and _sound != null:
			_sound.play()
		if open:
			opened.emit()
		else:
			closed.emit()

## Where the leaf goes when it opens, in local space. A bulkhead slides; a
## hinged door would rotate, and does not exist in Act 1.
@export var travel: Vector3 = Vector3(0.0, 2.3, 0.0)

@export_range(0.2, 12.0, 0.1) var seconds: float = 2.4

@onready var _leaf: Node3D = $Leaf
@onready var _body: StaticBody3D = $Leaf/Body
@onready var _sound: AudioStreamPlayer3D = $Sound

var _home := Vector3.ZERO
var _at := 0.0


func _ready() -> void:
	_home = _leaf.position
	_at = 1.0 if open else 0.0
	_apply()
	set_physics_process(true)


func save_state() -> Dictionary:
	return {"open": open}


func load_state(state: Dictionary) -> void:
	open = bool(state.get("open", open))
	_at = 1.0 if open else 0.0
	_apply()


func _physics_process(delta: float) -> void:
	var target := 1.0 if open else 0.0
	if is_equal_approx(_at, target):
		return
	_at = move_toward(_at, target, delta / maxf(seconds, 0.01))
	_apply()


func _apply() -> void:
	if _leaf == null:
		return
	_leaf.position = _home + travel * _at
	# Solid until it has actually moved. A door that stops blocking the moment
	# it is told to open is a door you can walk through while it is still shut.
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	for child in _body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = _at > 0.6
