class_name Player
extends CharacterBody3D

## First-person body. Owns locomotion and where the eyes point; owns no input
## devices of its own. Whoever is driving (touch HUD, keyboard, a cutscene)
## pushes intent in through set_move_intent() / add_look(), which keeps this
## script honest when the control scheme changes.

@export var tuning: PlayerTuning

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera

## Desired yaw (x) and pitch (y) in radians. The camera chases this, which is
## what gives touch look its weight.
var _look_target := Vector2.ZERO
var _look_smoothed := Vector2.ZERO
var _move_intent := Vector2.ZERO
var _bob_phase := 0.0
var _rest_eye_height := 0.0


func _ready() -> void:
	assert(tuning != null, "Player needs a PlayerTuning resource assigned.")
	_rest_eye_height = tuning.eye_height
	_head.position.y = _rest_eye_height
	_camera.fov = tuning.field_of_view
	_look_target = Vector2(rotation.y, _head.rotation.x)
	_look_smoothed = _look_target


## Locomotion intent in local space: x = strafe, y = forward. Length is clamped
## to 1, so an analogue stick at half deflection walks at half speed.
func set_move_intent(intent: Vector2) -> void:
	_move_intent = intent.limit_length(1.0)


## Additive look request, in pixels of screen travel.
func add_look(pixels: Vector2) -> void:
	var radians_per_pixel := deg_to_rad(tuning.look_sensitivity)
	_look_target.x -= pixels.x * radians_per_pixel
	var pitch_sign := 1.0 if tuning.invert_y else -1.0
	_look_target.y += pixels.y * radians_per_pixel * pitch_sign
	var limit := deg_to_rad(tuning.pitch_limit_degrees)
	_look_target.y = clampf(_look_target.y, -limit, limit)


func _physics_process(delta: float) -> void:
	_apply_look(delta)
	_apply_movement(delta)
	_apply_head_bob(delta)


func _apply_look(delta: float) -> void:
	# Exponential chase: frame-rate independent, and the only knob the designer
	# sees is a 0..1 "smoothing" dial.
	var rate := lerpf(30.0, 6.0, tuning.look_smoothing)
	var t := 1.0 - exp(-rate * delta)
	_look_smoothed = _look_smoothed.lerp(_look_target, t)
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
	var speed_ratio := clampf(
		Vector2(velocity.x, velocity.z).length() / maxf(tuning.walk_speed, 0.001), 0.0, 1.0
	)
	if is_on_floor():
		_bob_phase = fmod(_bob_phase + delta * tuning.bob_frequency * TAU * speed_ratio, TAU)
	# Two lobes per stride: one per footfall.
	var offset := sin(_bob_phase * 2.0) * tuning.bob_amplitude * speed_ratio
	_head.position.y = _rest_eye_height + offset
