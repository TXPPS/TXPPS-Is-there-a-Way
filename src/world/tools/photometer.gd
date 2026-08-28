class_name Photometer
extends Node

## C-6, the portable photometer, certified quarterly.
##
## The game's only instrument, and its one moment of instrumented proof. Held
## up, it reads illuminance where the player is standing. Pointed at a certified
## luminaire it reads what `D-18` says it should. Pointed at a **seam** it reads
## a drop — and the drop is not noise. It is a number, and it is the same number
## every time.
##
## That falls straight out of the entity's own rule rather than being special-
## cased for it: a reading is the sum over every lit practical that can *see*
## the meter, and the entity's whole existence is standing between the player
## and a lamp. When it does, that lamp stops counting, and the reading falls by
## exactly what that lamp was worth. Nothing here knows the entity exists.
##
## Deliberately the same idea as the debug overlay: on a device with no console,
## a number you can read beats a feeling you cannot.

## Engine light energy is not lux, and nothing in Godot says what it is. This is
## the constant that turns one into the other for this game's fittings, chosen
## so a sodium bulkhead at two metres reads about 120 lx — which is what a
## forty-year-old 70 W fitting in a wet corridor actually gives.
##
## It is a certificate, not a physical constant. A photometer is only as good as
## the last time somebody checked it, which is why `D-18` has forty-four
## quarterly entries in it.
@export var calibration: float = 114.0

## Below this it reads its own floor rather than a number, because a meter that
## reads 0.3 lx in a dark room is claiming a precision it does not have.
@export var floor_lux: float = 1.0

## Where the number is drawn. A Label3D on the instrument's own face rather than
## anything on the HUD: the reading belongs to the object, and a player holding
## it up to a wall should be looking at the meter, not at the corner of the
## screen.
@export var display: NodePath

## How often it settles on a new reading. A real meter integrates; one that
## updated every frame would flicker its last digit forever and read as noise.
@export_range(0.05, 2.0, 0.05) var settle_seconds: float = 0.25

var _lux := 0.0
var _since := 0.0


func _ready() -> void:
	set_physics_process(true)


## What the face says. Whole lux: the last digit of a forty-year-old meter is a
## guess, and printing it would be the instrument lying about itself.
func read() -> String:
	return "%d lx" % roundi(_lux)


func lux() -> float:
	return _lux


## Illuminance at a point, from every lit practical with a clear line to it.
## Static so the suite can ask the question without a tool, a player or a frame.
static func measure(space: PhysicsDirectSpaceState3D, lights: Array, at: Vector3,
		calibration_factor: float, ignore: Array[RID] = []) -> float:
	var total := 0.0
	for node in lights:
		var light := node as Light3D
		if light == null or not light.visible or light.light_energy <= 0.001:
			continue
		var offset: Vector3 = at - light.global_position
		var distance := maxf(offset.length(), 0.25)
		if light is OmniLight3D and distance > (light as OmniLight3D).omni_range:
			continue
		var query := PhysicsRayQueryParameters3D.create(light.global_position, at, 1)
		query.exclude = ignore
		if not space.intersect_ray(query).is_empty():
			continue
		total += light.light_energy * calibration_factor / (distance * distance)
	return total


func _physics_process(delta: float) -> void:
	_since += delta
	if _since < settle_seconds:
		return
	_since = 0.0
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	_lux = maxf(
		floor_lux,
		measure(
			owner_node.get_world_3d().direct_space_state,
			get_tree().get_nodes_in_group(&"practical"),
			owner_node.global_position,
			calibration
		)
	)
	var label := get_node_or_null(display) as Label3D
	if label != null:
		label.text = read()
