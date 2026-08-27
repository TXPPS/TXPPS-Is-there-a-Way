class_name SafeArea
extends Control

## The rectangle it is safe to draw controls in.
##
## The 3D canvas stays full-bleed -- letterboxing a horror game to dodge a notch
## would be a poor trade -- so only the HUD is inset. The insets are read from
## CSS by the HTML shell (the only thing that can see env(safe-area-inset-*))
## and published as window.__itaw_safeArea(). Off the web this is a no-op.
##
## The shell reports CSS points; this Control lives in viewport units, and on a
## phone the two differ -- the viewport is stretched to a fixed design width.
## Converting is not optional: unconverted, the inset that clears the home
## indicator falls about a third short of it.

signal changed

const BRIDGE_CALL := "window.__itaw_safeArea ? window.__itaw_safeArea() : ''"

## Breathing room added on every edge on top of the device insets, in points.
@export_range(0, 48, 1) var padding: float = 10.0

var _insets := Vector4.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.size_changed.connect(refresh)
	refresh()


## Viewport units per CSS point. 1.0 anywhere the viewport is not stretched.
func points_to_units() -> float:
	var window_width := float(get_window().size.x)
	if window_width <= 0.0:
		return 1.0
	return get_viewport().get_visible_rect().size.x / window_width


func rect() -> Rect2:
	return get_global_rect()


func refresh() -> void:
	_insets = _query_insets()
	var scale := points_to_units()
	offset_top = (_insets.x + padding) * scale
	offset_right = -(_insets.y + padding) * scale
	offset_bottom = -(_insets.z + padding) * scale
	offset_left = (_insets.w + padding) * scale
	changed.emit()


## Device insets in CSS points, as (top, right, bottom, left).
func _query_insets() -> Vector4:
	if not OS.has_feature("web"):
		return Vector4.ZERO
	var raw: Variant = JavaScriptBridge.eval(BRIDGE_CALL, true)
	if not (raw is String) or (raw as String).is_empty():
		return Vector4.ZERO
	var parts := (raw as String).split(",")
	if parts.size() != 4:
		return Vector4.ZERO
	return Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
