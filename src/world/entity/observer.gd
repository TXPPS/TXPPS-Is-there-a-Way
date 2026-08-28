class_name Observer
extends Node3D

## The entity, which is a procedure rather than a monster.
##
## Protocol 4.2: **the observer stands at the lamp.** That line is in a document
## the player can find, it is the whole of this class's behaviour, and every
## consequence in `STORY.md`'s rule table falls out of it without being coded
## separately:
##
## | The rule | Why it is true here |
## |---|---|
## | It occupies the space between a lit fixture and you | It is positioned on that line and nowhere else |
## | It can only approach along that axis | The axis is captured when the approach starts |
## | Stepping off the line breaks the approach | The captured axis stops matching the live one |
## | It cannot cross unlit space | With no lit practical there is no line to stand on |
## | Two fixtures leave no offset | Each lamp gives its own line; breaking one does not break the other |
##
## It is never shown. Its body is a near-black slab whose only job is to be
## between a lamp and the player, so what the player sees is the light going out
## for the width of a body and coming back. There is no face, no sound of its
## own, and no chase. See `ART_BIBLE.md`, "Never do this".

## How near it is, 0 when absent and 1 when it has arrived. Drives the fear
## state, which is the only thing it is allowed to do to the player.
signal approached(nearness: float)

## The player left the line and the approach has to start again.
signal broken

## It has come as close as it comes.
signal arrived

## Metres per second along the axis. Slow: this is dread, not a pursuit.
@export_range(0.05, 4.0, 0.05) var speed: float = 0.55

## How far the live lamp-to-player line may drift from the captured one before
## the approach breaks. Generous enough that breathing does not reset it, tight
## enough that one deliberate step does.
@export_range(2.0, 60.0, 0.5) var offset_tolerance_degrees: float = 20.0

## Where an approach begins, as a fraction of the lamp-to-player distance. It
## never starts at the lamp itself: the observer standing *in* the fixture would
## be a black rectangle over the light rather than a body in front of it.
@export_range(0.05, 0.95, 0.01) var start_fraction: float = 0.18

## It comes no nearer than this. Closer and the slab reads as an object.
@export_range(0.5, 8.0, 0.1) var closest: float = 2.2

## Width, height and depth of the interruption. A body, not a wall.
@export var body: Vector3 = Vector3(0.44, 1.95, 0.1)

@onready var _mesh: MeshInstance3D = $Body

var _player: Node3D
var _lamp: Node3D
var _axis := Vector3.ZERO
var _along := 0.0
var _reach := 0.0
var _arrived := false


func _ready() -> void:
	_shape()
	_hide()
	set_physics_process(false)


## Nothing here finds the player for itself: an entity that located its own
## target would behave differently in a test scene, and this is the one system
## in the game whose behaviour is the whole point.
func bind(player: Node3D) -> void:
	_player = player
	set_physics_process(_player != null)


## Whether it is on a line right now. Absent is the normal state.
func present() -> bool:
	return visible


## For the suite and the overlay.
func probe() -> Dictionary:
	return {
		"present": present(),
		"lamp": "" if _lamp == null else String(_lamp.name),
		"along": _along,
		"reach": _reach,
		"nearness": nearness(),
	}


## 0 when it has just started, 1 when it has arrived.
func nearness() -> float:
	if not visible or _reach <= 0.001:
		return 0.0
	return clampf(_along / _reach, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	var lamp := _choose_lamp()
	if lamp == null:
		if visible:
			_hide()
			broken.emit()
		return

	var to_player: Vector3 = _player.global_position - lamp.global_position
	var reach := to_player.length() - closest
	if reach <= 0.0:
		# The player is standing at the lamp. There is no room between.
		if visible:
			_hide()
			broken.emit()
		return

	var axis := to_player.normalized()
	if lamp != _lamp or not visible:
		_begin(lamp, axis, reach)
	elif _axis.angle_to(axis) > deg_to_rad(offset_tolerance_degrees):
		# **Step off the line.** The approach breaks -- and it breaks all the
		# way back, because a rule the player can half-cheat is not a rule.
		_hide()
		broken.emit()
		return
	else:
		_reach = reach

	_along = minf(_along + speed * delta, _reach)
	# `_reach` is already the lamp-to-player distance less `closest`, so walking
	# the full length of it lands exactly `closest` short. Adding `closest` here
	# as well walked it onto the player, which the suite caught as a distance of
	# zero and Godot caught as a look_at with nowhere to look.
	global_position = lamp.global_position + _axis * _along
	var toward: Vector3 = _player.global_position - global_position
	if toward.length_squared() > 0.0001:
		look_at(_player.global_position, Vector3.UP)
	approached.emit(nearness())

	if _along >= _reach and not _arrived:
		_arrived = true
		arrived.emit()


## The nearest lit practical that can actually see the player. A lamp with a
## wall in the way is not a lamp this can stand at: the line it would occupy is
## already interrupted by something that is not it.
func _choose_lamp() -> Node3D:
	if _player == null:
		return null
	var space := get_world_3d().direct_space_state
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"practical"):
		var light := node as Light3D
		if light == null or not light.visible or light.light_energy <= 0.01:
			continue
		# It can only be seen as an interruption, so it can only stand at a lamp
		# that casts. Standing at one that does not would put a black slab in a
		# lit room with nothing to explain it -- which is the one thing
		# `ART_BIBLE.md` says never to do with this creature.
		if not light.shadow_enabled:
			continue
		var distance := light.global_position.distance_to(_player.global_position)
		if distance >= best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			light.global_position, _player.global_position + Vector3.UP * 1.2, 1
		)
		if not space.intersect_ray(query).is_empty():
			continue
		best = light
		best_distance = distance
	return best


func _begin(lamp: Node3D, axis: Vector3, reach: float) -> void:
	_lamp = lamp
	_axis = axis
	_reach = reach
	_along = reach * start_fraction
	_arrived = false
	visible = true


func _hide() -> void:
	visible = false
	_lamp = null
	_along = 0.0
	_reach = 0.0
	_arrived = false


func _shape() -> void:
	var slab := BoxMesh.new()
	slab.size = body
	_mesh.mesh = slab

	# Unshaded and almost black. It is not lit because it is not seen: what the
	# player sees is the lamp behind it, not this.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.012, 0.012, 0.014)
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
