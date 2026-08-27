class_name Hud
extends CanvasLayer

## Owns the on-screen controls and the build stamp. It translates touches into
## intent and hands that on; it knows nothing about the player, so the same HUD
## can drive a menu camera or a cutscene rig later.

signal look_requested(pixels: Vector2)

@onready var _stick: VirtualStick = $SafeArea/Layout/VirtualStick
@onready var _look_pad: LookPad = $SafeArea/Layout/LookPad
@onready var _build_stamp: Label = $SafeArea/Layout/BuildStamp


func _ready() -> void:
	_look_pad.looked.connect(_on_looked)
	_build_stamp.text = BuildInfo.describe()


## Locomotion intent this frame: x = strafe, y = forward, each -1..1.
## Continuous analogue state, so it is read rather than pushed through a signal.
func get_move_intent() -> Vector2:
	var intent := _stick.value
	# Keyboard is a development convenience; on the phone this is always zero.
	var keys := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return (intent + keys).limit_length(1.0)


func _on_looked(pixels: Vector2) -> void:
	look_requested.emit(pixels)
