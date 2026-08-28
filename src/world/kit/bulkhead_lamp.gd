@tool
class_name BulkheadLamp
extends Node3D

## A practical that can be off.
##
## This is the behaviour; the *scene* is the fitting. `bulkhead_lamp.tscn` is
## the sodium bulkhead of the dam and `fluorescent.tscn` is the annex tube, and
## they differ in mesh, hue, range and whether they flicker -- not in any of
## this. A third fitting is a third scene and no new code.
##
## Off is the interesting state. Act 1 starts with every lamp in the building
## dark and a flashlight in the player's hand, and the first puzzle is getting
## some of them back. A lamp that is off is not just an unlit light: the glass
## stops being emissive and the ballast stops making noise, and both of those
## are how the player can tell across a room whether a circuit is live.

## Which circuit it is on, matching the panel schedule card. `LT-6 STAIR TWR` is
## the faulted one and stays dark until its fuse is pulled.
@export var circuit: StringName = &"LT-1"

@export var lit: bool = true:
	set(value):
		lit = value
		_apply()

@export var energy: float = 4.2:
	set(value):
		energy = value
		_apply()

@export var glass_lit: Material
@export var glass_dark: Material

@export_group("Flicker")

## How much of the tube's output is unreliable, 0 for a fitting that is not.
## A sodium lamp does not flicker; a forty-year-old fluorescent on a magnetic
## ballast does, and it is most of what makes one read as a fluorescent.
@export_range(0.0, 1.0, 0.01) var flicker_depth: float = 0.0

## Roughly how often it stumbles, in stumbles per second.
@export_range(0.05, 8.0, 0.05) var flicker_rate: float = 0.8

## Different for every fitting in a room, or they all stutter in unison and the
## room reads as one lamp behind a wall.
@export var flicker_seed: int = 0

@onready var _light: OmniLight3D = $Light
@onready var _glass: MeshInstance3D = $Glass
@onready var _hum: AudioStreamPlayer3D = $Hum


var _stumble := 0.0
var _next := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"bulkhead_lamp")
	_rng.seed = flicker_seed
	set_process(flicker_depth > 0.0)
	_apply()


## A tired tube does not shimmer, it *stumbles*: it burns steadily and then
## fails to strike for a fraction of a second. Modelled as an occasional dip
## that recovers rather than as noise on the brightness, because noise reads as
## a bad shader and a dip reads as a bad tube.
func _process(delta: float) -> void:
	if not lit or _light == null:
		return
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(0.35, 2.0) / maxf(flicker_rate, 0.01)
		_stumble = _rng.randf_range(0.06, 0.22)
	if _stumble > 0.0:
		_stumble = maxf(0.0, _stumble - delta)
		var dip := 1.0 - flicker_depth * (0.35 + 0.65 * _rng.randf())
		_light.light_energy = energy * dip
	else:
		_light.light_energy = energy


func _apply() -> void:
	if _light == null:
		return
	_light.light_energy = energy if lit else 0.0
	_light.visible = lit
	if glass_lit != null and glass_dark != null:
		_glass.material_override = glass_lit if lit else glass_dark
	if lit:
		if not _hum.playing:
			_hum.play()
	else:
		_hum.stop()
