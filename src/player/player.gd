class_name Player
extends CharacterBody3D

## First-person body. Owns locomotion and where the eyes point; owns no input
## devices of its own. Whoever is driving (touch HUD, keyboard, a cutscene)
## pushes intent in through set_move_intent() / set_look_intent() / add_look(),
## which keeps this script honest when the control scheme changes.
##
## Two look styles arrive here and both end at the same place. The right stick
## sends deflection and this integrates it into a turn rate; a drag sends travel
## and this applies it once. Neither knows about the other.

@export var tuning: PlayerTuning

## Stable across builds. Changing it orphans every existing save's player state.
@export var save_key: StringName = &"player"

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera

## Desired yaw (x) and pitch (y) in radians. The camera chases this, which is
## what gives touch look its weight.
var _look_target := Vector2.ZERO
var _look_smoothed := Vector2.ZERO
var _look_intent := Vector2.ZERO
var _move_intent := Vector2.ZERO
var _sensitivity := Vector2.ONE
var _invert := false
var _reduce_motion := false
var _bob_phase := 0.0
var _rest_eye_height := 0.0


func _ready() -> void:
	assert(tuning != null, "Player needs a PlayerTuning resource assigned.")
	_rest_eye_height = tuning.eye_height
	_head.position.y = _rest_eye_height
	_camera.fov = tuning.field_of_view
	_invert = tuning.invert_y
	_look_target = Vector2(rotation.y, _head.rotation.x)
	_look_smoothed = _look_target


## Locomotion intent in local space: x = strafe, y = forward. Length is clamped
## to 1, so an analogue stick at half deflection walks at half speed.
func set_move_intent(intent: Vector2) -> void:
	_move_intent = intent.limit_length(1.0)


## Points the eyes now, with no chase and no bob carried over. Spawn placement
## and scripted cameras need this; ordinary looking must not use it.
func face(yaw: float, pitch: float) -> void:
	var limit := deg_to_rad(tuning.pitch_limit_degrees)
	_look_target = Vector2(yaw, clampf(pitch, -limit, limit))
	_look_smoothed = _look_target
	rotation.y = _look_smoothed.x
	_head.rotation.x = _look_smoothed.y


## Look stick deflection: x = right, y = up, each -1..1. Held rather than
## consumed, because a stick is a rate and a rate applies every frame.
func set_look_intent(intent: Vector2) -> void:
	_look_intent = intent.limit_length(1.0)


## One-shot look request, in viewport units of thumb travel. Used by the drag
## look style, which has no notion of a rate.
func add_look(pixels: Vector2) -> void:
	_turn(
		pixels.x * tuning.drag_sensitivity * _sensitivity.x,
		-pixels.y * tuning.drag_sensitivity * _sensitivity.y
	)


## Where the body is and where the eyes point. Velocity is deliberately not
## saved: loading into a fall is not a state anyone wants restored.
func save_state() -> Dictionary:
	return {
		"at": [global_position.x, global_position.y, global_position.z],
		"aim": [_look_target.x, _look_target.y],
	}


func load_state(state: Dictionary) -> void:
	var at: Array = state.get("at", [])
	if at.size() == 3:
		global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	var aim: Array = state.get("aim", [])
	if aim.size() == 2:
		face(float(aim[0]), float(aim[1]))
	velocity = Vector3.ZERO
	_move_intent = Vector2.ZERO
	_look_intent = Vector2.ZERO


func on_setting(key: StringName, value: float) -> void:
	match key:
		&"look_sensitivity_x": _sensitivity.x = value
		&"look_sensitivity_y": _sensitivity.y = value
		&"invert_y": _invert = value >= 0.5
		&"field_of_view": _camera.fov = value
		&"reduce_motion": _reduce_motion = value >= 0.5


func _physics_process(delta: float) -> void:
	_apply_look_intent(delta)
	_apply_look(delta)
	_apply_movement(delta)
	_apply_head_bob(delta)


## Deflection becomes angular velocity. The ceiling is applied after
## sensitivity, so no combination of sliders can produce a spin.
func _apply_look_intent(delta: float) -> void:
	if _look_intent == Vector2.ZERO:
		return
	var limit := tuning.max_turn_rate
	var yaw := clampf(_look_intent.x * tuning.look_rate_x * _sensitivity.x, -limit, limit)
	var pitch := clampf(_look_intent.y * tuning.look_rate_y * _sensitivity.y, -limit, limit)
	_turn(yaw * delta, pitch * delta)


## Yaw right is negative rotation.y; pitch up is positive head rotation.x.
func _turn(yaw_degrees: float, pitch_degrees: float) -> void:
	_look_target.x -= deg_to_rad(yaw_degrees)
	var pitch_sign := -1.0 if _invert else 1.0
	_look_target.y += deg_to_rad(pitch_degrees) * pitch_sign
	var limit := deg_to_rad(tuning.pitch_limit_degrees)
	_look_target.y = clampf(_look_target.y, -limit, limit)


func _apply_look(delta: float) -> void:
	if _reduce_motion:
		_look_smoothed = _look_target
	else:
		# Exponential chase: frame-rate independent, and the only knob the
		# designer sees is a 0..1 "smoothing" dial.
		var rate := lerpf(30.0, 6.0, tuning.look_smoothing)
		_look_smoothed = _look_smoothed.lerp(_look_target, 1.0 - exp(-rate * delta))
	rotation.y = _look_smoothed.x
	_head.rotation.x = _look_smoothed.y


func _apply_movement(delta: float) -> void:
	var basis_flat := Basis(Vector3.UP, rotation.y)
	var wish := basis_flat * Vector3(_move_intent.x, 0.0, -_move_intent.y)
	var target := wish * tuning.walk_speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var time_constant := tuning.acceleration_time if wish.length_squared() > 0.0 else tuning.braking_time
	var t := 1.0 - exp(-delta / maxf(time_constant, 0.001))
	horizontal = horizontal.lerp(target, t)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta
	move_and_slide()


func _apply_head_bob(delta: float) -> void:
	if _reduce_motion:
		_head.position.y = _rest_eye_height
		return
	var speed_ratio := clampf(
		Vector2(velocity.x, velocity.z).length() / maxf(tuning.walk_speed, 0.001), 0.0, 1.0
	)
	if is_on_floor():
		_bob_phase = fmod(_bob_phase + delta * tuning.bob_frequency * TAU * speed_ratio, TAU)
	# Two lobes per stride: one per footfall.
	var offset := sin(_bob_phase * 2.0) * tuning.bob_amplitude * speed_ratio
	_head.position.y = _rest_eye_height + offset
