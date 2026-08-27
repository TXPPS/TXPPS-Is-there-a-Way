@tool
class_name PlayerTuning
extends Resource

## Everything that governs how the player *feels*. These values are meant to be
## dialled in from the inspector on a desktop editor, months from now, without
## reading a line of player.gd. Nothing in player.gd may hard-code a number
## that belongs here.

@export_group("Movement")

## Metres per second on flat ground. An auditor with a clipboard walks; he does
## not jog. Anything above ~2.4 starts to read as a shooter.
@export_range(0.5, 6.0, 0.05) var walk_speed: float = 1.95

## Seconds to reach full speed from a standstill.
@export_range(0.01, 1.0, 0.01) var acceleration_time: float = 0.16

## Seconds to come to a full stop. Shorter than acceleration, so stopping feels
## deliberate rather than skidding.
@export_range(0.01, 1.0, 0.01) var braking_time: float = 0.10

## Downward acceleration, m/s². Deliberately not Earth-accurate; 14 keeps the
## player planted on stairs and grating instead of floating.
@export_range(0.0, 30.0, 0.1) var gravity: float = 14.0

@export_group("Look")

## Degrees per second of yaw at full deflection of the look stick. Rate, not
## position: the stick says how fast to turn, and lets go means stop.
@export_range(20.0, 400.0, 1.0) var look_rate_x: float = 155.0

## Degrees per second of pitch at full deflection.
@export_range(20.0, 400.0, 1.0) var look_rate_y: float = 110.0

## Hard ceiling on turn rate, whatever sensitivity the player dials in. Without
## it a mis-set slider becomes a bug report about the camera spinning.
@export_range(30.0, 720.0, 5.0) var max_turn_rate: float = 320.0

## Degrees of camera rotation per viewport unit of thumb travel, under the drag
## look style. At 0.16 a swipe across half an iPhone 16 Pro Max turns about 100°.
@export_range(0.02, 1.0, 0.005) var drag_sensitivity: float = 0.16

## 0 = raw and twitchy, 1 = heavy and cinematic. Some smoothing is essential on
## touch, where finger jitter is far coarser than a mouse.
@export_range(0.0, 1.0, 0.01) var look_smoothing: float = 0.35

@export var invert_y: bool = false

## How far the player may look up or down before the neck stops.
@export_range(30.0, 89.0, 1.0) var pitch_limit_degrees: float = 85.0

@export_group("Camera")

## Eye height in metres from the floor.
@export_range(0.5, 2.0, 0.01) var eye_height: float = 1.62

## Vertical FOV in degrees. Wide enough to read a gauge and the catwalk above
## it in one frame; narrow enough to hide what is behind you.
@export_range(50.0, 100.0, 1.0) var field_of_view: float = 72.0

@export_group("Head Bob")

## Metres of vertical head travel at full walking speed. Above ~0.03 this reads
## as seasickness on a small screen.
@export_range(0.0, 0.08, 0.001) var bob_amplitude: float = 0.021

## Full bob cycles per second at full walking speed.
@export_range(0.5, 4.0, 0.05) var bob_frequency: float = 1.85
