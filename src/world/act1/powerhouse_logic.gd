class_name PowerhouseLogic
extends Node

## Act 1's five gates, wired in one place.
##
## The devices are dumb -- a breaker knows it is a breaker and nothing else --
## and the rules live here, next to each other, where they can be read as a
## sequence. See `docs/PUZZLES.md`, Act 1.
##
## Nothing in here tells the player anything. Every fact needed to get out of
## this act is written on the equipment: the panel schedule names the circuits,
## the interlock's plate says when it releases its key, the door's plate says to
## undog in opposite pairs, and the sign by the bell says what the bell is for.

signal lighting_restored
signal switchgear_opened
signal gallery_opened
signal shelter_answered
signal checkpoint_reached(id: String)

## The circuit that is faulted. Closing the main with this one in trips it, and
## the panel schedule is the only thing that says which one it is.
const FAULTED := &"LT-6"

## How long the main sits open after a trip. Long enough to be a refusal rather
## than a flicker, short enough not to be a punishment.
const TRIP_SECONDS := 1.2

## Protocol says eleven seconds. It is the longest eleven seconds in the act.
@export_range(1.0, 60.0, 0.5) var admit_delay: float = 11.0

## What the act itself remembers, as opposed to what its devices do. The
## breakers and the doors save their own positions; this saves the two things
## that are not a position: whether the wrench is in a pocket and which
## checkpoints have gone by.
@export var save_key: StringName = &"act1"

@onready var _fuses: Node3D = $"../Panel/Fuses"
@onready var _main: DeviceToggle = $"../Panel/Main"
@onready var _bus: DeviceToggle = $"../Panel/BusMain"
@onready var _switchgear_door: DeviceDoor = $"../SwitchgearDoor"
@onready var _gallery_door: DeviceDoor = $"../GalleryDoor"
@onready var _shelter_door: DeviceDoor = $"../ShelterDoor"
@onready var _wrench: DevicePush = $"../Wrench"
@onready var _dog: DevicePush = $"../SeizedDog"
@onready var _bell: DevicePush = $"../AdmitBell"

var _has_wrench := false
var _tripping := 0.0
var _admitting := -1.0
var _reached: Dictionary[String, bool] = {}


func _ready() -> void:
	for fuse in _fuses.get_children():
		(fuse as DeviceToggle).toggled.connect(_on_fuse_changed)
	_main.toggled.connect(_on_main_changed)
	_bus.toggled.connect(_on_bus_changed)
	_wrench.pushed.connect(_on_wrench_taken)
	_dog.pushed.connect(_on_dog_worked)
	_bell.pushed.connect(_on_bell_pushed)
	_apply_lighting()
	_apply_interlock()


## For the debug overlay and the suite: what the act thinks is true.
func probe() -> Dictionary:
	return {
		"main": _main.on,
		"bus": _bus.on,
		"lit": _lighting_live(),
		"wrench": _has_wrench,
		"switchgear": _switchgear_door.open,
		"gallery": _gallery_door.open,
		"shelter": _shelter_door.open,
	}


func has_wrench() -> bool:
	return _has_wrench


func save_state() -> Dictionary:
	return {"wrench": _has_wrench, "reached": _reached.keys()}


func load_state(state: Dictionary) -> void:
	_has_wrench = bool(state.get("wrench", false))
	_reached.clear()
	for id in state.get("reached", []):
		_reached[String(id)] = true
	_wrench.visible = not _has_wrench
	_apply_lighting()
	_apply_interlock()


func _physics_process(delta: float) -> void:
	if _tripping > 0.0:
		_tripping -= delta
		if _tripping <= 0.0:
			_main.on = false
			_main.play(0.72)
			_apply_lighting()
	if _admitting >= 0.0:
		_admitting -= delta
		if _admitting < 0.0:
			_shelter_door.open = true
			shelter_answered.emit()
			_mark("shelter-answered")


# --- P1.1 emergency lighting ------------------------------------------------

func _on_fuse_changed(_on: bool) -> void:
	_apply_lighting()


## Closing the main with the faulted circuit still in trips it, audibly, and
## nothing is lost. The first lesson in the game is that trying the wrong thing
## is safe.
func _on_main_changed(on: bool) -> void:
	if on and _fuse_in(FAULTED):
		_tripping = TRIP_SECONDS
		_main.play(0.72)
		_apply_lighting()
		return
	_apply_lighting()
	if on:
		_mark("lighting")
		lighting_restored.emit()


func _fuse_in(circuit: StringName) -> bool:
	for node in _fuses.get_children():
		var fuse := node as DeviceToggle
		if fuse != null and fuse.save_key == circuit:
			return fuse.on
	return false


func _lighting_live() -> bool:
	return _main.on and _tripping <= 0.0


func _apply_lighting() -> void:
	var live := _lighting_live()
	for node in get_tree().get_nodes_in_group(&"bulkhead_lamp"):
		var lamp := node as BulkheadLamp
		if lamp != null:
			lamp.lit = live and _fuse_in(lamp.circuit)


# --- P1.2 the switchgear interlock -----------------------------------------

## The interlock releases its key when the bus cannot be live. That is a safety
## feature and an obstacle at the same time, which is the most honest kind of
## door a plant can offer.
func _on_bus_changed(_on: bool) -> void:
	_apply_interlock()
	if not _bus.on:
		_mark("switchgear")
		switchgear_opened.emit()


func _apply_interlock() -> void:
	_switchgear_door.open = not _bus.on


# --- P1.4 the gallery door --------------------------------------------------

func _on_wrench_taken() -> void:
	_has_wrench = true
	_wrench.visible = false
	Notify.say("Dog wrench.")


func _on_dog_worked() -> void:
	if not _has_wrench:
		Notify.say("The last dog is seized. It will not move by hand.")
		return
	_gallery_door.open = true
	_mark("gallery")
	gallery_opened.emit()


# --- P1.5 the admit call ----------------------------------------------------

func _on_bell_pushed() -> void:
	if _shelter_door.open or _admitting >= 0.0:
		return
	_admitting = admit_delay


func _mark(id: String) -> void:
	if _reached.has(id):
		return
	_reached[id] = true
	checkpoint_reached.emit(id)
