class_name CarriedTool
extends Node3D

## Something the player picks up and takes with them.
##
## Everything else in this game is used where it stands: a breaker is thrown, a
## document is held up and put down again, and the world does not change shape.
## A tool is the first thing that moves through the building with the player,
## and P3.2 needs one — the photometer is the game's only instrument, and it is
## worthless in the room it was found in.
##
## The carry behaviour is here and the tool's *job* is a child node with a
## `read()` on it, so a second instrument is a second child rather than a second
## class. See `Photometer`.

signal taken
signal dropped

## Stable across builds, and the save key. A tool is saved by *who is holding
## it* rather than by where it is, which is why `Hands` saves the name and this
## saves only its position for the case where nobody is.
@export var save_key: StringName = &""

## On the label beside it, and in the prompt.
@export var tool_name: String = "tool"

## Where it sits relative to the camera while carried: down and to the right,
## far enough forward not to clip the near plane, angled so its face is
## readable without being in the middle of the screen.
@export var hold_offset: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(-24.0), deg_to_rad(14.0), 0.0)),
	Vector3(0.24, -0.20, -0.42)
)

## The child that does the measuring, if this tool measures anything.
@export var instrument: NodePath

@onready var _zone: Interactable = $Zone

var _held := false
var _home: Transform3D


func _ready() -> void:
	_home = global_transform
	_zone.instant = true
	_zone.engaged.connect(_on_engaged)
	_zone.prompt = "Take the %s" % tool_name


func held() -> bool:
	return _held


## What its face says right now, or "" for a tool with nothing to say.
func readout() -> String:
	var node := get_node_or_null(instrument)
	if node == null or not node.has_method("read"):
		return ""
	return String(node.call("read"))


## Called by `Hands`, never by the player directly: a tool does not decide it is
## being carried, because two tools deciding that at once is a bug with no
## obvious symptom.
func set_held(held: bool) -> void:
	_held = held
	_zone.available = not held
	visible = true


func save_state() -> Dictionary:
	return {
		"at": [global_position.x, global_position.y, global_position.z],
		"held": _held,
	}


func load_state(state: Dictionary) -> void:
	var at: Array = state.get("at", [])
	if at.size() == 3 and not bool(state.get("held", false)):
		global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))


func _on_engaged() -> void:
	if _held:
		return
	taken.emit()


## Where it goes back to if it is ever put down with nowhere to put it.
func home() -> Transform3D:
	return _home


func announce_dropped() -> void:
	dropped.emit()
