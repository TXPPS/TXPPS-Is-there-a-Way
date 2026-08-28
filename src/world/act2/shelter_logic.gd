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

var _running := false
var _live := false
var _sump_has_run := false
var _cranking := -1.0
var _tripping := -1.0
var _float := -1.0
var _pumping := -1.0
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
	_live = bool(state.get("live", false))
	_sump_has_run = bool(state.get("sump", false))
	_reached.clear()
	for id in state.get("reached", []):
		_reached[String(id)] = true
	_cranking = -1.0
	_tripping = -1.0
	_float = -1.0
	_pumping = -1.0
	_apply()


func _physics_process(delta: float) -> void:
	_cranking = _advance(_cranking, delta, _on_crank_finished)
	_tripping = _advance(_tripping, delta, _on_trip_finished)
	_float = _advance(_float, delta, _on_float_called)
	_pumping = _advance(_pumping, delta, _on_pump_finished)


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


## It cranks either way. What the fuel decides is whether it catches -- which is
## the whole puzzle, and the difference has to be audible rather than a refusal.
func _on_crank_finished() -> void:
	if not _valve.open:
		return
	_running = true
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


# --- the way on -------------------------------------------------------------

func _stair_clear() -> bool:
	return _sump_has_run


## The annex door is not opened by the player. It is found already open, which
## is the act's last beat -- but only once the stair below is clear and there is
## light on the other side to walk into.
func _apply() -> void:
	if _stair_water != null:
		_stair_water.visible = not _stair_clear()
	var reachable := _stair_clear() and _live and _annex_light.on
	if reachable and not _annex_door.open:
		_annex_door.open = true
		_mark("annex")
		annex_found.emit()


func _mark(id: String) -> void:
	if _reached.has(id):
		return
	_reached[id] = true
	checkpoint_reached.emit(id)
