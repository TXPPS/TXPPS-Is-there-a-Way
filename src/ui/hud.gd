class_name Hud
extends CanvasLayer

## Owns the on-screen controls. It translates touches into intent and hands that
## on; it knows nothing about the player, so the same HUD can drive a menu
## camera or a cutscene rig later.
##
## The build stamp is deliberately *not* here -- it lives in the HTML shell, so
## it is readable and copyable even when the engine has failed to boot, which is
## exactly when you most want to know which build you are looking at.

signal look_requested(pixels: Vector2)

@onready var _stick: VirtualStick = $SafeArea/Layout/VirtualStick
@onready var _look_pad: LookPad = $SafeArea/Layout/LookPad
@onready var _touch_watch: TouchWatch = $TouchWatch
@onready var _debug_overlay: DebugOverlay = $SafeArea/Layout/DebugOverlay


func _ready() -> void:
	_look_pad.looked.connect(_on_looked)
	_touch_watch.three_finger_tapped.connect(_debug_overlay.toggle)


## Locomotion intent this frame: x = strafe, y = forward, each -1..1.
## Continuous analogue state, so it is read rather than pushed through a signal.
func get_move_intent() -> Vector2:
	var intent := _stick.value
	# Keyboard is a development convenience; on the phone this is always zero.
	var keys := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return (intent + keys).limit_length(1.0)


func _on_looked(pixels: Vector2) -> void:
	look_requested.emit(pixels)
