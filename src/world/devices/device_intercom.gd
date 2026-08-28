class_name DeviceIntercom
extends Node3D

## The observer intercom, C-3. Two channels, `TALK` and `MONITOR`.
##
## The subject-side handset, on the mess wall where a 1964 retrofit would have
## put it. The panel lamp lights when the bus comes up, which is the first thing
## in the act that says somebody is at the other end of it.
##
## It is not a puzzle and the player cannot answer on it: Protocol 4.3 says the
## observer shall not speak except on the schedule, and Emil has kept that line
## for thirty-four years. Pressing `TALK` opens the channel and gets the same
## thing every time, which is nothing.

signal spoke

@export var save_key: StringName = &"intercom"

## What is said, in order, one line at a time. Four sentences, none of them a
## question and none of them an answer.
@export var lines: Array[String] = []

@onready var _zone: Interactable = $Zone
@onready var _lamp: MeshInstance3D = $Lamp
@onready var _relay: AudioStreamPlayer3D = $Relay

@export var lamp_live: Material
@export var lamp_dead: Material

var _live := false
var _has_spoken := false
var _subtitles: Subtitles


func _ready() -> void:
	_zone.instant = true
	_zone.engaged.connect(_on_engaged)
	_subtitles = _find_subtitles()
	_apply()


## Whether there is anything at the other end. Driven by the act, not by this.
func set_live(live: bool) -> void:
	_live = live
	_apply()


func has_spoken() -> bool:
	return _has_spoken


func save_state() -> Dictionary:
	return {"spoken": _has_spoken}


func load_state(state: Dictionary) -> void:
	_has_spoken = bool(state.get("spoken", _has_spoken))


## The scheduled hour. Called by the act's clock, never by the player.
func speak() -> void:
	if _has_spoken or not _live:
		return
	_has_spoken = true
	_relay.play()
	if _subtitles != null:
		_subtitles.say(lines)
	spoke.emit()


## Pressing TALK. It opens the channel, and the channel is the only reply.
func _on_engaged() -> void:
	_relay.play()
	Haptics.tap()


func _apply() -> void:
	if _lamp != null and lamp_live != null and lamp_dead != null:
		_lamp.material_override = lamp_live if _live else lamp_dead
	if _zone != null:
		_zone.prompt = "Press TALK" if _live else "It has no power"


## The HUD owns the band the words go in. Found rather than exported so a page
## of this scene dropped into a test scene with no HUD still works.
func _find_subtitles() -> Subtitles:
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	return null if hud == null else hud.subtitles()
