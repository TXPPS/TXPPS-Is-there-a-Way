class_name DevicePush
extends Node3D

## A momentary push. A bell, a start button, a reset.
##
## Separate from DeviceToggle because a push has no state to read, and giving it
## one would mean drawing a handle that stays where it was put -- which is how a
## bell ends up looking like a switch somebody left on.

signal pushed

@export var label: String = ""
@export var prompt: String = "Press it"
## How far the button goes in, and for how long.
@export var travel: Vector3 = Vector3(0.0, 0.0, -0.02)
@export_range(0.05, 1.0, 0.01) var depress_seconds: float = 0.18

## What it sounds like when pressed. A bell is not a wrench.
@export var sound: AudioStream

@onready var _zone: Interactable = $Zone
@onready var _cap: Node3D = $Cap
@onready var _sound: AudioStreamPlayer3D = $Sound

var _home := Vector3.ZERO
var _held := 0.0


func _ready() -> void:
	if sound != null:
		_sound.stream = sound
	_home = _cap.position
	_zone.instant = true
	_zone.prompt = prompt if label.is_empty() else "%s  (%s)" % [prompt, label]
	_zone.engaged.connect(_on_engaged)
	set_process(false)


func _on_engaged() -> void:
	_cap.position = _home + travel
	_held = depress_seconds
	set_process(true)
	Haptics.tap()
	if _sound.stream != null:
		_sound.play()
	pushed.emit()


func _process(delta: float) -> void:
	_held -= delta
	if _held > 0.0:
		return
	_cap.position = _home
	set_process(false)
