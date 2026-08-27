class_name AudioOccluder
extends Node

## Makes a sound behave like it is behind a wall, because it is.
##
## Godot's 3D players attenuate with distance and can filter, but they do not
## know what is between them and the ear. In a building made of bulkheads that
## is most of what the mix is: the same ballast hum heard through an open door
## and through 400 mm of concrete is two different sounds, and the difference is
## how a player works out where they are.
##
## One ray, four times a second. Cheaper than it sounds and far cheaper than
## being wrong about a lamp two rooms away.

## Cutoff with nothing in the way. Godot treats 20500 as "off".
@export_range(500.0, 20500.0, 10.0) var open_hz: float = 20500.0
## Cutoff through a wall. Concrete passes the bottom two octaves and little else.
@export_range(100.0, 8000.0, 10.0) var blocked_hz: float = 560.0
## Level lost through the wall, on top of the filtering.
@export_range(-24.0, 0.0, 0.5) var blocked_db: float = -8.0
## Seconds to travel between the two states. Fast enough to follow a door
## opening, slow enough that a ray clipping a pillar is not a click.
@export_range(0.02, 2.0, 0.01) var glide_seconds: float = 0.22
@export_range(1, 20, 1) var checks_per_second: int = 4
@export_flags_3d_physics var world_mask: int = 1

var _source: AudioStreamPlayer3D
var _base_db := 0.0
var _blocked := 0.0
## Held across frames. Recomputing it as "wherever we already are" on the frames
## between checks means the glide only ever advances on a check frame, which
## makes it four times slower than the glide time says and leaves a door opening
## sounding like a fade rather than a door.
var _target := 0.0
var _since_check := 0.0


func _ready() -> void:
	_source = get_parent() as AudioStreamPlayer3D
	if _source == null:
		push_error("AudioOccluder must be a child of an AudioStreamPlayer3D.")
		set_physics_process(false)
		return
	_base_db = _source.volume_db
	_since_check = 1.0


## 0 when the path is clear, 1 when it is fully blocked. Read by the suite,
## which cannot hear a filter but can read one.
func blockage() -> float:
	return _blocked


func _physics_process(delta: float) -> void:
	_since_check += delta
	if _since_check >= 1.0 / float(maxi(checks_per_second, 1)):
		_since_check = 0.0
		_target = 1.0 if _is_blocked() else 0.0
	_blocked = move_toward(_blocked, _target, delta / maxf(glide_seconds, 0.001))
	_source.attenuation_filter_cutoff_hz = lerpf(open_hz, blocked_hz, _blocked)
	_source.volume_db = _base_db + blocked_db * _blocked


func _is_blocked() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var space := _source.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		_source.global_position, camera.global_position, world_mask
	)
	return not space.intersect_ray(query).is_empty()
