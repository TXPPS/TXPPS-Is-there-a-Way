@tool
class_name ScoreTuning
extends Resource

## Where each score layer comes in, and how loud it gets.
##
## The score is four layers that are each complete on their own -- it is not a
## build-up, it is four rooms the same space can be in. What the fear number
## does is decide which room you are in, and the overlap is where the game gets
## its unease from.
##
## Every band is (enters, full): below `enters` the layer is silent, at `full`
## it is at `gain`, and in between it is a smoothstep so nothing ever switches
## on. Bands overlap on purpose.

@export_group("Bed")
## Always audible. The floor of the mix, and the only layer with no entry point.
@export_range(0.0, 1.0, 0.01) var bed_quiet: float = 0.55
@export_range(0.0, 1.0, 0.01) var bed_loud: float = 1.0

@export_group("Room")
@export var room_band: Vector2 = Vector2(0.10, 0.36)
@export_range(0.0, 1.0, 0.01) var room_gain: float = 0.85

@export_group("Strain")
@export var strain_band: Vector2 = Vector2(0.40, 0.68)
@export_range(0.0, 1.0, 0.01) var strain_gain: float = 0.8

@export_group("Edge")
@export var edge_band: Vector2 = Vector2(0.70, 0.95)
@export_range(0.0, 1.0, 0.01) var edge_gain: float = 0.55

@export_group("Response")
## Seconds for a layer to reach a new level. Slow, because a score that tracks
## the fear number exactly is a score that tells the player what to feel.
@export_range(0.1, 10.0, 0.1) var glide_seconds: float = 2.4

## Below this a layer is stopped rather than played silently, which saves a
## voice and, on this target, a decode.
@export_range(0.0, 0.1, 0.001) var silence_floor: float = 0.004


## Linear gain for a band at a given fear.
func band_gain(band: Vector2, gain: float, fear: float) -> float:
	return gain * smoothstep(band.x, band.y, fear)


func bed_level(fear: float) -> float:
	return lerpf(bed_quiet, bed_loud, clampf(fear, 0.0, 1.0))
