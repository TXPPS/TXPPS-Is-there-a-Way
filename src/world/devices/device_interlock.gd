class_name DeviceInterlock
extends Node3D

## C-7, the door interlock cabinet. Three channels, key-released.
##
## Protocol 4.4 made physical: *a run is not concluded until the observer leaves
## the lamp*, and a run must not be broken by somebody opening a door. So the
## cabinet holds a captive key for each chamber, and it will not let go of one
## while that chamber's luminaire circuit is energised.
##
## That is real hardware and it is ordinary: captive-key interlocks are how you
## stop a switch room being opened onto a live bus, and the same idea stops a
## chamber being opened onto a lit run. The player is not fighting the building.
## They are following its procedure, correctly, which is Act 4's whole problem
## stated early in a room where it is only inconvenient.

signal released(channel: StringName)
signal refused(channel: StringName)

@export var save_key: StringName = &"interlock"

## One per channel, matching the chambers the timeclock drives.
@export var channels: Array[StringName] = [&"B", &"C"]

@onready var _zone: Interactable = $Zone
@onready var _sound: AudioStreamPlayer3D = $Sound

## Which channel the player is asking about. A cabinet with three keys in it
## needs a way to say which one, and the cheapest honest one is that the door
## you are standing at is the door you are asking about.
var _asking: StringName = &""

## Set by the act: is this channel's circuit energised right now?
var _energised: Callable = func(_channel: StringName) -> bool: return true

var _taken: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_zone.instant = true
	_zone.engaged.connect(_on_engaged)
	_apply()


## The act tells it how to find out whether a circuit is live. It does not go
## looking: an interlock that reasoned about lamps would be an interlock with an
## opinion about the puzzle, and this one only has an opinion about voltage.
func watch(energised: Callable) -> void:
	_energised = energised
	_apply()


## Which channel this cabinet is currently offering.
func asking() -> StringName:
	return _asking


func ask_for(channel: StringName) -> void:
	_asking = channel if channels.has(channel) else &""
	_apply()


func has_key(channel: StringName) -> bool:
	return _taken.get(channel, false)


func save_state() -> Dictionary:
	return {"keys": _taken.keys()}


func load_state(state: Dictionary) -> void:
	_taken.clear()
	for key in state.get("keys", []):
		_taken[StringName(key)] = true
	_apply()


## Pulling on a key. It comes out or it does not, and which one is the puzzle.
func _on_engaged() -> void:
	if _asking == &"" or has_key(_asking):
		return
	if _energised.call(_asking):
		_sound.pitch_scale = 0.7
		_sound.play()
		refused.emit(_asking)
		return
	_taken[_asking] = true
	_sound.pitch_scale = 1.25
	_sound.play()
	Haptics.tap()
	released.emit(_asking)
	_apply()


func _apply() -> void:
	if _zone == null:
		return
	if _asking == &"":
		_zone.prompt = "Chamber keys, captive"
		return
	if has_key(_asking):
		_zone.prompt = "Key %s is out" % _asking
		return
	# The plate says when it releases, not what to go and do about it. That is
	# the difference between a machine and a hint.
	_zone.prompt = "Pull key %s  (releases with the circuit dead)" % _asking
