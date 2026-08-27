class_name AudioDirector
extends Node

## The adaptive score.
##
## Ambience is not here. A room's tone belongs to the room, so each space carries
## its own; this owns only the four layers that follow the player everywhere.
##
## Four layers on the Music bus, all playing all the time, crossfaded by the one
## fear number (`src/core/fear_state.gd`). They are not stems of one piece: each
## is periodic by construction at the same loop length, so they stay in phase
## with each other forever without any sequencing, and any subset of them is a
## complete thing to listen to.
##
## The glide is deliberately slow. A score that follows the fear number closely
## is a score that narrates, and the player learns to read the music instead of
## the room.

const LAYER_PATH := "res://assets/audio/%s.wav"
const LAYERS: Array[StringName] = [&"score_bed", &"score_room", &"score_strain", &"score_edge"]
## Quietest a layer is allowed to be while still playing, in dB.
const FLOOR_DB := -60.0

@export var tuning: ScoreTuning

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _target: Dictionary[StringName, float] = {}
var _level: Dictionary[StringName, float] = {}
var _fear := 0.0


func _ready() -> void:
	assert(tuning != null, "AudioDirector needs a ScoreTuning resource assigned.")
	for layer in LAYERS:
		var player := AudioStreamPlayer.new()
		player.stream = load(LAYER_PATH % layer)
		player.bus = AudioBuses.MUSIC
		player.volume_db = FLOOR_DB
		add_child(player)
		player.play()
		_players[layer] = player
		_level[layer] = 0.0
		_target[layer] = 0.0
	_refresh_targets()
	for layer in LAYERS:
		_level[layer] = _target[layer]
	_apply()


func set_fear(value: float) -> void:
	_fear = clampf(value, 0.0, 1.0)
	_refresh_targets()


## What each layer is doing, for the debug overlay and the suite. A mix cannot
## be heard from a headless runner; it can be read.
func probe() -> Dictionary:
	var out: Dictionary = {"fear": _fear}
	for layer in LAYERS:
		out[String(layer)] = snappedf(_level[layer], 0.001)
	return out


## Where the mix is heading, as opposed to where it is. Worth having separately
## from `probe()`: a glide that is stuck and a glide that is slow look identical
## from the levels alone.
func targets() -> Dictionary:
	var out: Dictionary = {}
	for layer in LAYERS:
		out[String(layer)] = snappedf(_target[layer], 0.001)
	return out


func _refresh_targets() -> void:
	_target[&"score_bed"] = tuning.bed_level(_fear)
	_target[&"score_room"] = tuning.band_gain(tuning.room_band, tuning.room_gain, _fear)
	_target[&"score_strain"] = tuning.band_gain(tuning.strain_band, tuning.strain_gain, _fear)
	_target[&"score_edge"] = tuning.band_gain(tuning.edge_band, tuning.edge_gain, _fear)


func _process(delta: float) -> void:
	var step := delta / maxf(tuning.glide_seconds, 0.001)
	var moved := false
	for layer in LAYERS:
		var next: float = move_toward(_level[layer], _target[layer], step)
		if not is_equal_approx(next, _level[layer]):
			_level[layer] = next
			moved = true
	if moved:
		_apply()


func _apply() -> void:
	for layer in LAYERS:
		var player: AudioStreamPlayer = _players[layer]
		var level: float = _level[layer]
		if level <= tuning.silence_floor:
			player.volume_db = FLOOR_DB
			continue
		player.volume_db = linear_to_db(level)
