class_name FearState
extends Node

## How frightened the game thinks the player is, as one number.
##
## One number on purpose (`DECISIONS.md` D15). The score, the grain and the post
## stack all read `value()`; none of them sees the parts. The parts exist and
## are named and separately weighted, so the mix can be tuned without touching a
## consumer, and so that a later split into a vector is additive rather than a
## rewrite.
##
##   exposure   how much of you is standing on a lamp's line
##   proximity  how near the nearest seam has been, decaying
##   dark_time  how long since you last stood in light
##
## Nothing drives exposure or proximity before Act 3, because nothing is
## following you before Act 3. `dark_time` runs from Act 1, which is what makes
## the response observable -- and testable -- long before there is an entity.
##
## That sentence was true for so long that it stopped being noticed: exposure is
## the *largest* of the three and was fed by nothing at all, through Act 3 being
## built and the entity being written and shipped. 45% of the number was
## permanently zero. `main.gd` feeds it from whether anything is standing on a
## line to the player, which is what the word was always supposed to mean.

signal changed(value: float)

@export_range(0.0, 1.0, 0.01) var exposure_weight: float = 0.45
@export_range(0.0, 1.0, 0.01) var proximity_weight: float = 0.40
@export_range(0.0, 1.0, 0.01) var dark_weight: float = 0.15

## Fraction of the proximity spike shed per second. A seam is frightening for a
## while after it has gone, which is the entire difference between dread and a
## jump scare.
@export_range(0.05, 2.0, 0.01) var proximity_decay: float = 0.35

## Seconds in the dark before `dark_time` reaches its ceiling.
@export_range(5.0, 300.0, 1.0) var dark_full_seconds: float = 45.0

## Seconds of standing in light to shed all of it. Faster than it accrues:
## relief is quicker than dread, or the game never lets up.
@export_range(1.0, 60.0, 0.5) var dark_recover_seconds: float = 12.0

var _exposure := 0.0
var _proximity := 0.0
var _dark := 0.0
var _in_light := true
var _last := -1.0


func value() -> float:
	return clampf(
		_exposure * exposure_weight + _proximity * proximity_weight + _dark * dark_weight,
		0.0,
		1.0
	)


## 0 when clear of every lamp line, 1 when squarely on one.
func set_exposure(amount: float) -> void:
	_exposure = clampf(amount, 0.0, 1.0)


## Called when a seam is seen. `nearness` is 1 at arm's length and 0 at the far
## end of a corridor. Spikes rather than sets, so two seams are worse than one.
func report_seam(nearness: float) -> void:
	_proximity = clampf(maxf(_proximity, clampf(nearness, 0.0, 1.0)), 0.0, 1.0)


func set_in_light(lit: bool) -> void:
	_in_light = lit


## The parts, for the debug overlay. Nothing in the game reads this.
func parts() -> Dictionary:
	return {"exposure": _exposure, "proximity": _proximity, "dark": _dark}


func _process(delta: float) -> void:
	_proximity = maxf(0.0, _proximity - proximity_decay * delta)
	var rate := -1.0 / maxf(dark_recover_seconds, 0.001) if _in_light \
		else 1.0 / maxf(dark_full_seconds, 0.001)
	_dark = clampf(_dark + rate * delta, 0.0, 1.0)
	var now := value()
	if is_equal_approx(now, _last):
		return
	_last = now
	changed.emit(now)
