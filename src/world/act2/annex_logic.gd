class_name AnnexLogic
extends Node

## Act 3's four gates. See `docs/PUZZLES.md`, Act 3.
##
## The annex is rooms in Act 2's scene rather than an act of its own (D28),
## because P3.3 sends the player back to the shelter's distribution panel to
## take a load off — and that only means anything if it is the same panel and a
## real walk. So this and `ShelterLogic` are two logics over one building, and
## they meet at exactly one place: the panel.
##
## Nothing here tells the player anything. The cam relationship is in Emil's
## notes, the interlock's plate says when it releases, the photometer's log says
## what a lamp should read at two metres, and the reel index says how the
## shelves are ordered.

signal chamber_opened
signal observation_concluded
signal tank_drained
signal reel_found(accession: String)
signal checkpoint_reached(id: String)

## The chamber the last run was in, and the only one that has anything in it.
const RUN_CHAMBER := &"B"

## The breaker on DP-2 that feeds all three chamber luminaires.
const CHAMBER_BREAKER := &"Chambers"

## Circuit name to chamber, for the lamps the timeclock drives.
const CHAMBER_CIRCUITS := {&"CHAM_A": &"A", &"CHAM_B": &"B", &"CHAM_C": &"C"}

## The reel P3.4 is looking for: day 40 of Run 9, the last of box C.
const RUN_9_LAST := "RF-0840"

## What the annex bank draws. Taking it off is what makes room for the sump,
## and `ShelterLoad` is what decides whether that is enough.
@export var save_key: StringName = &"act3"

@onready var _clock: Timeclock = $"../Timeclock"
@onready var _interlock: DeviceInterlock = $"../Interlock"
@onready var _observer: Observer = $"../Observer"
@onready var _tank_water: Node3D = $"../TankWater"
@onready var _library_door: DeviceDoor = $"../LibraryDoor"
@onready var _reels: Node3D = $"../Reels"
@onready var _end: ActEnd = $"../../ActEnd"
@onready var _drain: DeviceToggle = $"../TankDrain"
@onready var _shelter: ShelterLogic = $"../../Logic"

var _key_out := false
var _drained := false
var _reel := ""
var _reached: Dictionary[String, bool] = {}


func _ready() -> void:
	_clock.changed.connect(_on_clock_changed)
	_interlock.released.connect(_on_key_released)
	_interlock.ask_for(RUN_CHAMBER)
	# The interlock is told how to find out whether a circuit is live. It does
	# not go looking: an interlock that reasoned about lamps would be one with
	# an opinion about the puzzle.
	# What "energised" means for a chamber: the bus is up, the breaker that feeds
	# all three is in, *and* the clock has that chamber's cam in its window. All
	# three, which means opening the breaker at the panel is a second, honest
	# way through P3.1 -- and it costs the player every chamber lamp to do it.
	_interlock.watch(_chamber_energised)
	for node in _reels.get_children():
		(node as DevicePush).pushed.connect(_on_reel_taken.bind(node.get("label")))
	_drain.toggled.connect(_on_drain_worked)
	# Protocol 4.4, and Ending A: standing at the lamp and letting it close over
	# you *is* the final observation. The entity does not attack -- it arrives,
	# and arriving is the whole event.
	_observer.arrived.connect(_on_observation_finished)
	if _shelter != null:
		_shelter.bus_live.connect(_on_power_changed)
		_shelter.bus_tripped.connect(func(_why: String) -> void: _on_power_changed())
		for node in _shelter.get_parent().get_node("Panel/Breakers").get_children():
			(node as DeviceToggle).toggled.connect(func(_on: bool) -> void: _on_power_changed())
	_apply()


func probe() -> Dictionary:
	return {
		"hour": _clock.hour(),
		"cam_b": _clock.cam(RUN_CHAMBER),
		"lit_b": _clock.lit(RUN_CHAMBER),
		"key": _key_out,
		"drained": _drained,
		"reel": _reel,
		"observer": _observer.probe(),
	}


func key_out() -> bool:
	return _key_out


func drained() -> bool:
	return _drained


func save_state() -> Dictionary:
	return {"key": _key_out, "drained": _drained, "reel": _reel, "reached": _reached.keys()}


func load_state(state: Dictionary) -> void:
	_key_out = bool(state.get("key", false))
	_drained = bool(state.get("drained", false))
	_reel = String(state.get("reel", ""))
	_reached.clear()
	for id in state.get("reached", []):
		_reached[String(id)] = true
	_apply()


# --- P3.1 the timeclock -----------------------------------------------------

func _on_clock_changed() -> void:
	_apply()


## The bus came up or went down, so every chamber lamp's answer changed.
func _on_power_changed() -> void:
	_apply()


## The key comes out when chamber B's circuit is dead, which is the timeclock's
## business and not this one's. All that happens here is that the door it
## belongs to stops being shut.
func _on_key_released(channel: StringName) -> void:
	if channel != RUN_CHAMBER or _key_out:
		return
	_key_out = true
	_mark("chamber")
	chamber_opened.emit()
	_apply()


# --- P3.3 drain the tank room -----------------------------------------------

## Opening the drain valve calls for the sump. The annex does not own the sump,
## the panel or the arithmetic -- it owns the water, and it asks.
##
## What comes back is either drained water or a tripped set, and the trip is the
## same one the player met in Act 2. That is deliberate: they already know what
## it means and what to do about it, and P3.3 is not a new failure, it is the
## old one with a new price.
func _on_drain_worked(open: bool) -> void:
	if _drained or not open:
		return
	if _shelter == null or not _shelter.call_sump_for_tank():
		# It refused. The valve stays open; the player goes to the panel.
		return
	_drained = true
	_mark("tank")
	tank_drained.emit()
	_apply()


# --- P3.4 the reel index ----------------------------------------------------

func _on_reel_taken(accession: String) -> void:
	if not _reel.is_empty():
		return
	if accession != RUN_9_LAST:
		# Taking the wrong one costs nothing and teaches the shelf. The right
		# answer is a deduction from two documents, not a search.
		return
	_reel = accession
	_mark("reel")
	reel_found.emit(accession)
	_apply()
	# The end of what is built. Not a doorway: a reel in your hand.
	if _end != null:
		_end.trigger()


## The one place that decides whether a chamber's luminaire is alight.
func _chamber_energised(chamber: StringName) -> bool:
	if _shelter == null or not _shelter.live():
		return false
	if not _shelter.breaker_closed(CHAMBER_BREAKER):
		return false
	return _clock.lit(chamber)


func _apply_chamber_lamps() -> void:
	for node in get_tree().get_nodes_in_group(&"bulkhead_lamp"):
		var lamp := node as BulkheadLamp
		if lamp == null or not CHAMBER_CIRCUITS.has(lamp.circuit):
			continue
		lamp.lit = _chamber_energised(CHAMBER_CIRCUITS[lamp.circuit])


## The observer reached the player and neither of them moved. That is the run
## concluded, and it is the only thing in this act that outlives the act.
func _on_observation_finished() -> void:
	var run := get_tree().get_first_node_in_group(&"run_state") as RunState
	if run == null or run.run_concluded():
		return
	run.conclude()
	_mark("observed")
	observation_concluded.emit()


func _apply() -> void:
	_apply_chamber_lamps()
	if _tank_water != null:
		_tank_water.visible = not _drained
	# The door is the flood. The water itself is not solid, because the drain
	# valve is on the far wall and the player has to be able to wade to it.
	if _library_door != null:
		_library_door.open = _drained
	for node in _reels.get_children():
		var reel := node as DevicePush
		if reel != null:
			reel.visible = _reel.is_empty() or String(reel.get("label")) != _reel


func _mark(id: String) -> void:
	if _reached.has(id):
		return
	_reached[id] = true
	checkpoint_reached.emit(id)
