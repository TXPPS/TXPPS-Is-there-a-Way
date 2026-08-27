class_name AudioBuses
extends RefCounted

## Names the mix, so nothing else has to know a bus index.
##
## The buses exist and are wired now, while almost everything is still silent,
## because routing is the expensive part to retrofit: a sound authored straight
## onto the master bus has to be found again later to be moved off it.
##
## Volume and ducking are kept as separate numbers and combined on the way out.
## Adding and subtracting a duck from a live volume looks equivalent and is not:
## move a slider while ducked and the duck never comes back off.

const MASTER := &"Master"
const SFX := &"SFX"
const MUSIC := &"Music"
const VOICE := &"Voice"

## How far the game ducks under the pause menu.
const PAUSE_DUCK_DB := -18.0

## Below this a slider means off, and converting zero to decibels gives negative
## infinity, which Godot will store and never come back from.
const SILENCE := 0.0005

static var _linear: Dictionary[StringName, float] = {}
static var _ducked := false


static func set_volume(bus: StringName, linear: float) -> void:
	_linear[bus] = linear
	_apply(bus)


## Ducks everything under the master bus, so a menu sound -- when there is one --
## still carries over a paused world.
static func set_ducked(ducked: bool) -> void:
	_ducked = ducked
	for bus in [SFX, MUSIC, VOICE]:
		_apply(bus)


static func is_ducked() -> bool:
	return _ducked


static func volume_db(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_volume_db(index) if index >= 0 else 0.0


static func _apply(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var linear: float = _linear.get(bus, 1.0)
	AudioServer.set_bus_mute(index, linear <= SILENCE)
	var db := linear_to_db(maxf(linear, SILENCE))
	if _ducked and bus != MASTER:
		db += PAUSE_DUCK_DB
	AudioServer.set_bus_volume_db(index, db)
