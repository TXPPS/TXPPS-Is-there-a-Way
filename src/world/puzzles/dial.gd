class_name Dial
extends Node3D

## One numbered wheel. Shows a digit and turns to it.
##
## The barrel carries a notch so the rotation is legible on a wheel that is
## otherwise a circle, and the digit is a Label3D because the alternative is a
## texture, and this project makes no textures it did not generate.

## How many positions before it comes round again. Ten for a combination wheel,
## twenty-four for the hour drum on the programme's timeclock. A property rather
## than a constant because the two live in the same bank of wheels and turn the
## same way; only the counting differs.
var modulus: int = 10:
	set(value):
		modulus = maxi(2, value)
		set_digit(digit)

var digit: int = 0

@onready var _barrel: Node3D = $Barrel
@onready var _label: Label3D = $Label


func _ready() -> void:
	set_digit(digit)


func set_digit(value: int) -> void:
	digit = wrapi(value, 0, modulus)
	if _label == null:
		return
	# Two digits on a twenty-four hour drum, one on a combination wheel: a clock
	# face that reads "7" where it should read "07" is a clock face nobody
	# trusts, and the leading zero is what makes it read as a time.
	_label.text = ("%02d" % digit) if modulus > 10 else str(digit)
	_barrel.rotation.z = -TAU * float(digit) / float(modulus)


func highlight(on: bool) -> void:
	_label.modulate = Color(0.65, 0.95, 0.7) if on else Color(0.87, 0.89, 0.92)
