class_name HudRects
extends Node

## The registry of screen area the touch controls own.
##
## A reserved rect is a promise: a thumb resting there is doing something, so
## nothing else may be drawn there and nothing in the world may be targeted
## through it. Interaction prompts, subtitles, toasts and update banners all
## have to ask before they place themselves, and the answer has to come from one
## list rather than from each of them guessing the same numbers.
##
## Providers are Callables returning a Rect2 in viewport units, called on every
## query, so a rect that moves with the safe area or a settings change is always
## current without anyone re-registering.
##
## Documented in docs/ARCHITECTURE.md, "Reserved HUD rects".

signal changed

var _order: Array[StringName] = []
var _providers: Dictionary[StringName, Callable] = {}


## Claims screen area under `id`. Registering the same id twice replaces it.
func reserve(id: StringName, provider: Callable) -> void:
	if not _providers.has(id):
		_order.append(id)
	_providers[id] = provider
	changed.emit()


func release(id: StringName) -> void:
	if not _providers.has(id):
		return
	_order.erase(id)
	_providers.erase(id)
	changed.emit()


## Every live reserved rect, in registration order, as `id -> Rect2`.
func rects() -> Dictionary:
	var out: Dictionary = {}
	for id in _order:
		var provider: Callable = _providers[id]
		if provider.is_valid():
			out[id] = provider.call() as Rect2
	return out


## Which reserved rects `area` runs into. Empty means it is safe to draw there.
func conflicts(area: Rect2, ignore: StringName = &"") -> PackedStringArray:
	var hits := PackedStringArray()
	for id in rects():
		if id == ignore:
			continue
		if (rects()[id] as Rect2).intersects(area):
			hits.append(String(id))
	return hits


func is_clear(area: Rect2, ignore: StringName = &"") -> bool:
	return conflicts(area, ignore).is_empty()


## True when a point on screen sits under a control. World-space targeting asks
## this so the player cannot pick up something their own thumb is covering.
func blocks_point(point: Vector2) -> bool:
	for id in rects():
		if (rects()[id] as Rect2).has_point(point):
			return true
	return false


## Reports an overlap as a runtime error rather than letting it ship looking
## fine on the one screen it was authored on. On the phone this surfaces as a
## toast; in CI it fails the startup check.
func require_clear(who: StringName, area: Rect2) -> bool:
	var hits := conflicts(area, who)
	if hits.is_empty():
		return true
	push_error("HUD element '%s' overlaps reserved rect(s): %s" % [who, ", ".join(hits)])
	return false


## Flattened for the debug overlay and the browser suite, which cannot read a
## Dictionary of Rect2 across the JavaScript bridge.
func describe() -> Array:
	var out: Array = []
	for id in rects():
		var r: Rect2 = rects()[id]
		out.append({
			"id": String(id),
			"x": roundi(r.position.x),
			"y": roundi(r.position.y),
			"w": roundi(r.size.x),
			"h": roundi(r.size.y),
		})
	return out
