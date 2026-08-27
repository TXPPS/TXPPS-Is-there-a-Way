class_name TouchRouter
extends Node

## The single owner of every screen touch the HUD cares about.
##
## Two rules, and every multi-touch bug this project has had came from not
## having them written down in one place:
##
## 1. A touch is claimed by whichever registered region it *begins* in, and that
##    claim holds until the touch is released -- even if the thumb drags far
##    outside the region. Nothing else may act on a claimed touch.
## 2. Movement is computed here, from this touch's own previous position, keyed
##    by touch index. `InputEventScreenDrag.relative` is never read.
##
## Rule 2 is not fastidiousness. Godot 4.6's web display server keys its
## previous-position table by the touch's slot in the DOM event's changedTouches
## list rather than by the touch identifier it puts on the event
## (platform/web/display_server_web.cpp, `Point2 &prev = ds->touches[i];`). With
## two thumbs down, the right thumb's `relative` is measured from wherever the
## *left* thumb last was -- hundreds of pixels, every move event. That is the
## camera spinning. Deriving the delta from position, per index, is immune.

signal claimed(owner_id: StringName, index: int, position: Vector2)
signal moved(owner_id: StringName, index: int, position: Vector2, delta: Vector2)
signal released(owner_id: StringName, index: int)

@export var tuning: TouchTuning
## Optional. Sees every touch, claimed or not, for the debug overlay and the
## three-finger gesture. Fed from here so nothing else has to listen.
@export var watch: TouchWatch

var _regions: Array[StringName] = []
var _providers: Dictionary[StringName, Callable] = {}
var _owner: Dictionary[int, StringName] = {}
var _last: Dictionary[int, Vector2] = {}
var _settled: Dictionary[int, bool] = {}
var _enabled := true


func _ready() -> void:
	assert(tuning != null, "TouchRouter needs a TouchTuning resource assigned.")


## Registers a claimable region. `provider` returns its Rect2 in viewport
## coordinates and is called at touch-down, so a region may move or resize
## freely between touches. Earlier registrations win an overlap.
func add_region(owner_id: StringName, provider: Callable) -> void:
	if not _providers.has(owner_id):
		_regions.append(owner_id)
	_providers[owner_id] = provider


func remove_region(owner_id: StringName) -> void:
	_regions.erase(owner_id)
	_providers.erase(owner_id)


## Stops claiming new touches, and lets go of the ones it holds. Every owner
## hears `released`, so nothing is left holding a stick that no thumb is on.
## This is what makes a pause resumable.
func set_enabled(value: bool) -> void:
	if _enabled == value:
		return
	_enabled = value
	if not _enabled:
		release_all()


func is_enabled() -> bool:
	return _enabled


func release_all() -> void:
	for index in _owner.keys():
		released.emit(_owner[index], index)
	_owner.clear()
	_last.clear()
	_settled.clear()


## Which control, if any, holds this touch. Empty when the touch is unclaimed.
func owner_of(index: int) -> StringName:
	return _owner.get(index, &"")


## Live claims as `owner -> index`, for the debug overlay and the test suite.
func claims() -> Dictionary:
	var out: Dictionary = {}
	for index in _owner:
		out[String(_owner[index])] = index
	return out


func _input(event: InputEvent) -> void:
	if watch != null:
		watch.observe(event)
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_begin(event.index, event.position)
		return
	_end(event.index)


func _begin(index: int, position: Vector2) -> void:
	if not _enabled or _owner.has(index):
		return
	var owner_id := _region_at(position)
	if owner_id == &"":
		return
	_owner[index] = owner_id
	_last[index] = position
	_settled[index] = false
	claimed.emit(owner_id, index, position)
	_consume()


func _end(index: int) -> void:
	if not _owner.has(index):
		return
	var owner_id: StringName = _owner[index]
	_owner.erase(index)
	_last.erase(index)
	_settled.erase(index)
	released.emit(owner_id, index)
	_consume()


## The first move of a claim reports zero travel on purpose.
##
## Whatever the platform thought the previous position was, we did not measure
## it, so the honest delta for that frame is nothing. It costs one frame of lag
## at the start of a gesture and removes an entire class of first-frame jump.
func _on_drag(event: InputEventScreenDrag) -> void:
	if not _owner.has(event.index):
		return
	var index := event.index
	var previous: Vector2 = _last[index]
	_last[index] = event.position
	var delta := Vector2.ZERO
	if _settled.get(index, false):
		delta = (event.position - previous).limit_length(tuning.max_touch_delta)
	else:
		_settled[index] = true
	moved.emit(_owner[index], index, event.position, delta)
	_consume()


func _region_at(position: Vector2) -> StringName:
	for owner_id in _regions:
		var provider: Callable = _providers[owner_id]
		if not provider.is_valid():
			continue
		var rect: Rect2 = provider.call()
		if rect.has_point(position):
			return owner_id
	return &""


func _consume() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
