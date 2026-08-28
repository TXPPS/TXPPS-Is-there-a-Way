class_name GateLogic
extends Node

## Act 4's three gates and the two endings. See `docs/PUZZLES.md`, Act 4.
##
## Act 4 is rooms added to Act 1 rather than an act of its own, because P4.1 and
## P4.2 are in Act 1's gallery and that is where they belong -- the relay panel
## is the 1954 flood-response panel, and the box feeding it is on a shelf beside
## it. Getting here means walking back down through the shelter, which is a walk
## the player has earned and which is the point of `ActRunner` remembering what
## they left behind.
##
## Nothing here tells the player anything. The sequence card has said
## `SEQ HOLDS WHILE STAGE > 30.0 FT` since minute four, the gauge repeats
## whatever it is fed, and the box that is feeding it wears a label in a hand
## the player last saw on a card about a broken step.

signal stage_told_the_truth(feet: float)
signal sequence_reset
signal ending_reached(which: StringName)
signal checkpoint_reached(id: String)

## What the box is set to. Its own label says 30.5, and the sequence latches
## above 30.0, which is the whole of why it was set there.
const FABRICATED_FEET := 30.5

## What the river is actually doing, and has been since 1994. A pool held by a
## closed dam does not move.
const TRUE_FEET := 21.4

## Above this the flood-response sequence holds. `D-04`, laminated, at the panel.
const LATCH_FEET := 30.0

@export var save_key: StringName = &"act4"

@onready var _gauge: DeviceGauge = $"../Gallery/StageGauge"
@onready var _held_lamp: DeviceToggle = $"../Gallery/SeqHeld"
@onready var _bench: DeviceToggle = $"../Gallery/BenchLead"
@onready var _interlock: DeviceInterlock = $"../House/Interlock"
@onready var _reset: DevicePush = $"../House/LatchReset"
@onready var _permissive: DeviceToggle = $"../Pier/HandPump"
@onready var _gate_sound: AudioStreamPlayer3D = $"../Pier/GateRelease"
@onready var _cards := {
	&"conclude": $"../EndingA" as ActEnd,
	&"open": $"../EndingB" as ActEnd,
}

var _latched := true
var _ending: StringName = &""
var _reached: Dictionary[String, bool] = {}


func _ready() -> void:
	# The gauge repeats what it is given and has no opinion. That is the puzzle:
	# it is not broken and it is not lying.
	_gauge.source = func() -> float: return FABRICATED_FEET if _bench.on else TRUE_FEET
	_bench.toggled.connect(_on_bench_changed)
	_reset.pushed.connect(_on_reset_pushed)
	_permissive.toggled.connect(_on_permissive_changed)
	_interlock.ask_for(&"RUN")
	_interlock.watch(_run_in_progress)
	_interlock.released.connect(_on_key_released)
	_apply()


func probe() -> Dictionary:
	return {
		"stage": _gauge.reading(),
		"fed": _bench.on,
		"latched": _latched,
		"key": _interlock.has_key(&"RUN"),
		"ending": String(_ending),
	}


func latched() -> bool:
	return _latched


func ending() -> StringName:
	return _ending


func save_state() -> Dictionary:
	return {"latched": _latched, "ending": String(_ending), "reached": _reached.keys()}


func load_state(state: Dictionary) -> void:
	_latched = bool(state.get("latched", true))
	_ending = StringName(state.get("ending", ""))
	_reached.clear()
	for id in state.get("reached", []):
		_reached[String(id)] = true
	_apply()


# --- P4.2 the selsyn bench unit ---------------------------------------------

## Pulling the lead does not open anything. The sequence stops being *fed* a
## reason to hold, and a latch that has stopped being fed is still latched --
## which is what a latch is. Latches are reset deliberately, at the desk.
func _on_bench_changed(_on: bool) -> void:
	_apply()
	if not _bench.on:
		_mark("stage")
		stage_told_the_truth.emit(TRUE_FEET)


# --- P4.3 the control house -------------------------------------------------

## Protocol 4.4: a run is not concluded until the observer leaves the lamp. The
## cabinet is asking about the run, and the run is Emil's, and he has not left.
##
## Which of the two endings the player takes decides the answer, and both are
## things they do with equipment rather than options on a menu.
func _run_in_progress(_channel: StringName) -> bool:
	return _ending != &"conclude"


func _on_key_released(_channel: StringName) -> void:
	_apply()


func _on_reset_pushed() -> void:
	if not _latched:
		return
	if _bench.on:
		# Still being fed 30.5 ft. Resetting a sequence whose input still says
		# flood re-latches it before the button is back up.
		return
	if not _interlock.has_key(&"RUN"):
		return
	_latched = false
	_mark("reset")
	sequence_reset.emit()
	_finish(&"conclude")


# --- Ending B ---------------------------------------------------------------

## Refuse. The tainter gate is designed to be operable when the control house is
## dead, because a 1954 dam had to be. An engineer can take it off its
## permissive by hand, and the pool comes through the structure.
func _on_permissive_changed(_on: bool) -> void:
	if _permissive.on or _ending != &"":
		return
	_finish(&"open")


func _finish(which: StringName) -> void:
	if _ending != &"":
		return
	_ending = which
	_mark(String(which))
	_apply()
	if which == &"open" and _gate_sound != null:
		_gate_sound.play()
	ending_reached.emit(which)
	var card: ActEnd = _cards.get(which)
	if card != null:
		card.trigger()


func _apply() -> void:
	if _held_lamp != null:
		_held_lamp.on = _latched
	if _reset != null:
		var ready := not _bench.on and _interlock.has_key(&"RUN")
		_reset.get_node("Zone").prompt = (
			"Reset the sequence" if ready else "Reset the sequence  (key captive)"
		)


func _mark(id: String) -> void:
	if _reached.has(id):
		return
	_reached[id] = true
	checkpoint_reached.emit(id)
