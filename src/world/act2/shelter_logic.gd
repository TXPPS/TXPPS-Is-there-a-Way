class_name ShelterLogic
extends Node

## Act 2's gates, wired in one place. See `docs/PUZZLES.md`, Act 2.
##
## Three gates that are one system: get the shelter's own plant carrying load.
## The set will not fire because the day tank is isolated, it will not connect
## because the transfer switch is in TEST, and it will not hold because 30 kW
## does not carry everything. Every one of those is the correct end state of the
## last thing Emil did, which is the act's real subject.
##
## Nothing here tells the player anything. The service card says `DAY TANK ISOL`
## forty-seven times, the switch plate says NORMAL / TEST / EMERGENCY, and every
## load on the panel wears its own nameplate.

signal set_running
signal bus_live
## Why the bus dropped, in the words the panel would use.
signal bus_tripped(reason: String)
signal sump_started
signal stair_cleared
signal annex_found
signal checkpoint_reached(id: String)

## Cranking without fuel. Long enough to hear it give up.
const CRANK_SECONDS := 2.4

## How long an overload takes to open the set's main. The design says the bus
## picks up and trips within four seconds, every time.
const TRIP_SECONDS := 4.0

## How long after the bus comes up before the sump's float calls for it. Long
## enough that the player believes they have won.
const FLOAT_SECONDS := 9.0

## How long the sump runs before the stair is clear.
const PUMP_SECONDS := 6.0

## The scheduled hour, counted from the bus coming up. Emil speaks once, and
## not because the player did anything -- which is the point of him.
const SCHEDULE_SECONDS := 24.0

## Which breaker feeds which lighting circuit. The lamps carry the circuit name
## from the panel schedule and nothing else; this is the only place that knows
## a circuit is a breaker. The chamber luminaires are not here -- they are on a
## timeclock as well as a breaker, and `AnnexLogic` owns that.
const CIRCUITS := {
	&"SHLT": &"ShelterLighting",
	&"ANNEX": &"AnnexLighting",
}

@export var save_key: StringName = &"act2"

@onready var _valve: DeviceValve = $"../Plant/DayTankValve"
@onready var _starter: DevicePush = $"../Plant/Starter"
@onready var _transfer: DeviceSelector = $"../Plant/TransferSwitch"
@onready var _set_main: DeviceToggle = $"../Plant/SetMain"
@onready var _breakers: Node3D = $"../Panel/Breakers"
@onready var _sump: DeviceToggle = $"../Panel/Breakers/Sump"
@onready var _annex_light: DeviceToggle = $"../Panel/Breakers/AnnexLighting"
@onready var _annex_door: DeviceDoor = $"../AnnexDoor"
@onready var _stair_water: Node3D = $"../StairWater"
@onready var _seam: LightSeam = $"../Seam"
@onready var _crank: AudioStreamPlayer3D = $"../Plant/Crank"
@onready var _catch: AudioStreamPlayer3D = $"../Plant/Catch"
@onready var _diesel: AudioStreamPlayer3D = $"../Plant/Diesel"
@onready var _intercom: DeviceIntercom = $"../Intercom"

var _running := false
var _live := false
var _sump_has_run := false
var _cranking := -1.0
var _tripping := -1.0
var _float := -1.0
var _pumping := -1.0
var _scheduled := -1.0
var _reached: Dictionary[String, bool] = {}


func _ready() -> void:
	_starter.pushed.connect(_on_starter_pushed)
	_transfer.moved.connect(_on_transfer_moved)
	_set_main.toggled.connect(_on_set_main_changed)
	for node in _breakers.get_children():
		var breaker := node as DeviceToggle
		if breaker != null:
			breaker.toggled.connect(_on_breaker_changed)
	_apply()


## What the act thinks is true, for the overlay and the suite.
func probe() -> Dictionary:
	return {
		"fuel": _valve.open,
		"running": _running,
		"live": _live,
		"transfer": String(_transfer.selected()),
		"load_kw": ShelterLoad.running(_breakers.get_children()),
		"over_kw": ShelterLoad.overload_kw(_breakers.get_children()),
		"inrush_kw": ShelterLoad.inrush(_breakers.get_children(), _sump),
		"sump": _sump_has_run,
		"stair": _stair_clear(),
		"annex": _annex_door.open,
	}


func running() -> bool:
	return _running


func live() -> bool:
	return _live


func save_state() -> Dictionary:
	return {
		"running": _running,
		"live": _live,
		"sump": _sump_has_run,
		"reached": _reached.keys(),
	}


func load_state(state: Dictionary) -> void:
	_running = bool(state.get("running", false))
	# A save made with the set running comes back with it running, so the loop
	# has to be started here as well as when it fires. Nothing else restarts it.
	if _diesel != null:
		if _running and not _diesel.playing:
			_diesel.play()
		elif not _running:
			_diesel.stop()
	_live = bool(state.get("live", false))
	_sump_has_run = bool(state.get("sump", false))
	_reached.clear()
	for id in state.get("reached", []):
		_reached[String(id)] = true
	_cranking = -1.0
	_tripping = -1.0
	_float = -1.0
	_pumping = -1.0
	_scheduled = -1.0
	_apply()


func _physics_process(delta: float) -> void:
	_cranking = _advance(_cranking, delta, _on_crank_finished)
	_tripping = _advance(_tripping, delta, _on_trip_finished)
	_float = _advance(_float, delta, _on_float_called)
	_pumping = _advance(_pumping, delta, _on_pump_finished)
	_scheduled = _advance(_scheduled, delta, _on_scheduled_hour)


## One countdown, run down and fired once. Four of these in a row is four
## chances to write the same off-by-one, so it is written once.
func _advance(timer: float, delta: float, done: Callable) -> float:
	if timer < 0.0:
		return timer
	var left := timer - delta
	if left > 0.0:
		return left
	done.call()
	return -1.0


# --- P2.1 start the generator ----------------------------------------------

func _on_starter_pushed() -> void:
	if _running or _cranking >= 0.0:
		return
	_cranking = CRANK_SECONDS
	# Which sound plays is decided now, at the press, because the fuel cannot
	# change while the starter is turning -- and a sound that started as a
	# failure and ended as a start would need crossfading to hide the join.
	if _valve.open:
		_catch.play()
	else:
		_crank.play()


## It cranks either way. What the fuel decides is whether it catches -- which is
## the whole puzzle, and the difference has to be audible rather than a refusal.
func _on_crank_finished() -> void:
	if not _valve.open:
		return
	_running = true
	_diesel.play()
	_mark("generator")
	set_running.emit()
	_apply()


# --- P2.2 the transfer switch ----------------------------------------------

func _on_transfer_moved(_position: StringName) -> void:
	_reassess("the transfer switch")


func _on_set_main_changed(_on: bool) -> void:
	_reassess("the set main")


func _on_breaker_changed(_on: bool) -> void:
	# Shedding while the bus is live is allowed and is how the puzzle is meant
	# to be solved -- but taking load off does not un-trip anything, and adding
	# load past the rating trips it again.
	_reassess("a breaker")


# --- P2.3 shed the load -----------------------------------------------------

## The one place that decides whether the bus is live, called from everything
## that could change the answer.
func _reassess(_cause: String) -> void:
	var connected := _running and _transfer.at(&"EMERGENCY") and _set_main.on
	if not connected:
		if _live:
			_drop()
		_apply()
		return

	if not _live:
		_live = true
		_float = FLOAT_SECONDS
		if not _intercom.has_spoken():
			_scheduled = SCHEDULE_SECONDS
		_mark("bus")
		bus_live.emit()

	if not ShelterLoad.carries(_breakers.get_children()):
		if _tripping < 0.0:
			_tripping = TRIP_SECONDS
	else:
		_tripping = -1.0
	_apply()


func _on_trip_finished() -> void:
	var over := ShelterLoad.overload_kw(_breakers.get_children())
	_set_main.on = false
	_set_main.play(0.72)
	_drop()
	bus_tripped.emit("%.1f kW over the set's rating" % over)
	_apply()


func _drop() -> void:
	_live = false
	_float = -1.0
	_pumping = -1.0
	# The schedule is not a countdown the player can lose by tripping the bus.
	# It waits for the power to come back and resumes where it was.
	_intercom.set_live(false)


# --- P2.4 the intercom, which is a scene and not a gate ---------------------

func _on_scheduled_hour() -> void:
	if not _live:
		_scheduled = 4.0   # ask again once there is power to ask with
		return
	_intercom.speak()


## The sump is on a float switch, so the player does not choose when it starts.
## They choose whether their allocation survives it -- which is the difference
## between an allocation that boots and one that holds.
func _on_float_called() -> void:
	if not _live:
		return
	if not _sump.on:
		_float = FLOAT_SECONDS  # the water is still rising; it will ask again
		return
	if not ShelterLoad.survives_start(_breakers.get_children(), _sump):
		var peak := ShelterLoad.inrush(_breakers.get_children(), _sump)
		_set_main.on = false
		_set_main.play(0.72)
		_drop()
		bus_tripped.emit("%.1f kW as the sump started" % peak)
		_apply()
		return
	_pumping = PUMP_SECONDS
	sump_started.emit()


func _on_pump_finished() -> void:
	if not _live:
		return
	_sump_has_run = true
	_mark("sump")
	stair_cleared.emit()
	_apply()


## A second call on the sump, made from the annex when the tank room's drain
## valve is opened. It is the same sump and the same panel -- which is the whole
## point of P3.3 -- but against the tank's head, so it needs more of the set's
## transient than the stair did.
##
## Returns true if it ran. If it did not, the set main opens exactly as it does
## for any other overload: the player already knows what that means and what to
## do about it, which is why the failure is this one and not a new one.
func call_sump_for_tank() -> bool:
	if not _live:
		return false
	if not _sump.on:
		return false
	if not ShelterLoad.survives_tank_start(_breakers.get_children(), _sump):
		var peak := ShelterLoad.inrush(_breakers.get_children(), _sump)
		_set_main.on = false
		_set_main.play(0.72)
		_drop()
		bus_tripped.emit("%.1f kW starting the sump against the tank" % peak)
		_apply()
		return false
	return true


# --- the way on -------------------------------------------------------------

func _stair_clear() -> bool:
	return _sump_has_run


## A lamp is lit when the bus is live and its own breaker is closed. Both, and
## in that order: a breaker closed onto a dead bus lights nothing, which is the
## whole of P2.2 and the reason the panel is not the puzzle on its own.
func _apply_lighting() -> void:
	for node in get_tree().get_nodes_in_group(&"bulkhead_lamp"):
		var lamp := node as BulkheadLamp
		if lamp == null or not CIRCUITS.has(lamp.circuit):
			continue
		lamp.lit = _live and _breaker_closed(CIRCUITS[lamp.circuit])


## Whether a named breaker on DP-2 is in. Public because `AnnexLogic` needs the
## same answer for the chamber luminaires and there should be one way to get it.
func breaker_closed(name: StringName) -> bool:
	return _breaker_closed(name)


func _breaker_closed(name: StringName) -> bool:
	var breaker := _breakers.get_node_or_null(String(name)) as DeviceToggle
	return breaker != null and breaker.on


## The annex door is not opened by the player. It is found already open, which
## is the act's last beat -- but only once the stair below is clear and there is
## light on the other side to walk into.
func _apply() -> void:
	if _stair_water != null:
		_stair_water.visible = not _stair_clear()
	if _intercom != null:
		_intercom.set_live(_live)
	_apply_lighting()
	var reachable := _stair_clear() and _live and _annex_light.on
	if reachable and not _annex_door.open:
		_annex_door.open = true
		_mark("annex")
		annex_found.emit()
		# The act's last beat, in a corridor the player has already walked.
		# Once, and never explained. See LightSeam.
		if _seam != null:
			_seam.show_once()


func _mark(id: String) -> void:
	if _reached.has(id):
		return
	_reached[id] = true
	checkpoint_reached.emit(id)
