class_name Dial
extends Node3D

## One numbered wheel. Shows a digit and turns to it.
##
## The barrel carries a notch so the rotation is legible on a wheel that is
## otherwise a circle, and the digit is a Label3D because the alternative is a
## texture, and this project makes no textures it did not generate.

const DIGITS := 10

var digit: int = 0

@onready var _barrel: Node3D = $Barrel
@onready var _label: Label3D = $Label


func _ready() -> void:
	set_digit(digit)


func set_digit(value: int) -> void:
	digit = wrapi(value, 0, DIGITS)
	_label.text = str(digit)
	_barrel.rotation.z = -TAU * float(digit) / float(DIGITS)


func highlight(on: bool) -> void:
	_label.modulate = Color(0.65, 0.95, 0.7) if on else Color(0.87, 0.89, 0.92)
