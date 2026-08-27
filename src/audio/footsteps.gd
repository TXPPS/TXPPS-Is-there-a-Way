class_name Footsteps
extends Node3D

## The player's own footsteps, and the first thing that will ever give them away.
##
## Distance-driven, not timer-driven: a stride happens when a stride's worth of
## ground has gone under you, so walking into a wall makes no sound and a slow
## approach is quiet without anything having to know it is an approach.
##
## What is underfoot comes from `SurfaceTag.of()` on whatever the down-ray hits,
## which is the hook `src/core/surface_type.gd` has been carrying since P1.
##
## `stepped` is emitted with the surface and the loudness it carries. Nothing
## listens yet -- P6's hearing model is what that signal is for -- but the event
## exists now so P6 adds a listener instead of rewriting this.

signal stepped(surface: SurfaceType, at: Vector3, loudness: float)

const SOUND_PATH := "res://assets/audio/%s_%d.wav"
## Two is enough: a stride cannot start before the last one has decayed.
const VOICES := 2

@export var default_surface: SurfaceType
## Metres of travel per footfall.
@export_range(0.3, 1.5, 0.01) var stride_metres: float = 0.74
## Random pitch spread, so three variants do not sound like three variants.
@export_range(0.0, 0.3, 0.01) var pitch_jitter: float = 0.06
@export_range(-40.0, 12.0, 0.5) var volume_db: float = -6.0
## How far down to look for something to be standing on.
@export_range(0.2, 4.0, 0.1) var probe_metres: float = 1.4
@export_flags_3d_physics var world_mask: int = 1

var _travelled := 0.0
var _voice := 0
var _players: Array[AudioStreamPlayer3D] = []
var _last := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_last = global_position
	for index in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.bus = AudioBuses.SFX
		player.unit_size = 2.2
		player.max_db = 0.0
		add_child(player)
		_players.append(player)


## Called by whatever is moving. Passing the travel in rather than measuring it
## keeps this working for anything that moves a body, including a cutscene.
func advance(delta_metres: float) -> void:
	if delta_metres <= 0.0:
		return
	var surface := _underfoot()
	var stride := stride_metres + (surface.stride_drag if surface != null else 0.0)
	_travelled += delta_metres
	if _travelled < stride:
		return
	_travelled = 0.0
	_play(surface)


func _physics_process(_delta: float) -> void:
	var now := global_position
	var moved := Vector2(now.x - _last.x, now.z - _last.z).length()
	_last = now
	advance(moved)


func _underfoot() -> SurfaceType:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.1,
		global_position + Vector3.DOWN * probe_metres,
		world_mask
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return default_surface
	var found := SurfaceTag.of(hit["collider"] as Node)
	return found if found != null else default_surface


func _play(surface: SurfaceType) -> void:
	if surface == null:
		return
	var index := _rng.randi_range(1, maxi(surface.variants, 1))
	var path := SOUND_PATH % [surface.sounds, index]
	if not ResourceLoader.exists(path):
		return
	var player := _players[_voice]
	_voice = (_voice + 1) % VOICES
	player.stream = load(path)
	player.bus = surface.bus
	player.pitch_scale = surface.pitch * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter))
	player.volume_db = volume_db + linear_to_db(maxf(surface.gain, 0.01))
	player.play()
	stepped.emit(surface, global_position, surface.loudness)
