@tool
class_name BulkheadLamp
extends Node3D

## A sodium bulkhead fitting that can be off.
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

@onready var _light: OmniLight3D = $Light
@onready var _glass: MeshInstance3D = $Glass
@onready var _hum: AudioStreamPlayer3D = $Hum


func _ready() -> void:
	add_to_group(&"bulkhead_lamp")
	_apply()


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
