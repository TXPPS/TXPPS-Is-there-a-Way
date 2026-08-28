class_name DeviceGauge
extends Node3D

## A dial that reads a number somebody else supplies.
##
## The stage repeater on the 1954 relay panel: a selsyn receiver whose pointer
## follows a transmitter in the stilling well, and which therefore reads
## whatever the transmitter tells it. That is the entire point of P4.2 — the
## gauge is not broken and is not lying. It is repeating, faithfully, a number
## that is being fabricated somewhere else.
##
## So this reads from a Callable and has no opinion. Anything that decided for
## itself what the river was doing would be a gauge that could be *wrong*, and
## a gauge that can be wrong cannot carry a puzzle about a gauge that is right.

## What the pointer is repeating. Set by whatever owns the instrument.
##
## There is no `save_state` here and there should not be. A repeater has no
## state of its own -- it shows what it is shown, and whatever is doing the
## showing is somebody else's to save.
var source: Callable = func() -> float: return 0.0

## Written under the dial. `STAGE FT` is what a 1954 panel would say.
@export var units: String = ""

## What the pointer sweeps between, end to end.
@export var minimum: float = 0.0
@export var maximum: float = 40.0

## How far the needle swings across that range.
@export var sweep_degrees: float = 240.0

## Digits after the point. A float gauge reading `21` when the sequence latches
## at `30.0` is a gauge nobody can reason about.
@export_range(0, 3, 1) var decimals: int = 1

@onready var _needle: Node3D = $Needle
@onready var _face: Label3D = $Face
@onready var _zone: Interactable = $Zone

var _reading := 0.0


func _ready() -> void:
	_zone.instant = true
	set_physics_process(true)
	_apply()


func reading() -> float:
	return _reading


func text() -> String:
	return ("%.*f %s" % [decimals, _reading, units]).strip_edges()


func _physics_process(_delta: float) -> void:
	var now: float = source.call()
	if is_equal_approx(now, _reading):
		return
	_reading = now
	_apply()


func _apply() -> void:
	if _face != null:
		_face.text = text()
		_zone.prompt = "Read the gauge  (%s)" % text()
	if _needle == null:
		return
	var span := maxf(maximum - minimum, 0.001)
	var through := clampf((_reading - minimum) / span, 0.0, 1.0)
	_needle.rotation.z = deg_to_rad(sweep_degrees * (0.5 - through))
