class_name ReverbZone
extends Area3D

## The size of the room, as the ear hears it.
##
## One reverb on the SFX bus, driven by whichever zone the listener is standing
## in. Not one reverb per space: a phone has a frame budget and four reverbs to
## crossfade between is three more than a game with this few rooms needs.
##
## The score is deliberately not sent here. It is written as four rooms the
## space can be in; putting a room on top of it smears the one thing in the mix
## that is meant to be placeless.

## Larger is longer. A powerhouse is 0.72; a stair tower is small and bright.
@export_range(0.0, 1.0, 0.01) var room_size: float = 0.72
## Higher eats the top end faster. Wet concrete damps less than you expect.
@export_range(0.0, 1.0, 0.01) var damping: float = 0.42
@export_range(0.0, 1.0, 0.01) var wet: float = 0.24
@export_range(0.0, 500.0, 1.0) var predelay_msec: float = 34.0
## Seconds to move to this zone's settings when the listener walks in.
@export_range(0.05, 5.0, 0.05) var glide_seconds: float = 0.8

static var _active: ReverbZone
static var _current := Vector4.ZERO


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_entered)


func _process(delta: float) -> void:
	if _active != self:
		set_process(false)
		return
	var effect := AudioBuses.reverb()
	if effect == null:
		return
	var target := Vector4(room_size, damping, wet, predelay_msec)
	_current = _current.lerp(target, minf(1.0, delta / maxf(glide_seconds, 0.001)))
	effect.room_size = _current.x
	effect.damping = _current.y
	effect.wet = _current.z
	effect.predelay_msec = _current.w


func _on_entered(body: Node3D) -> void:
	if not body.is_in_group(&"listener"):
		return
	if _active == null:
		_current = Vector4(room_size, damping, wet, predelay_msec)
	_active = self
	set_process(true)
