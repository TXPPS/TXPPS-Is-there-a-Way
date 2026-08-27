class_name SafeAreaMargin
extends MarginContainer

## Keeps its children clear of the Dynamic Island and the home indicator.
##
## The 3D canvas stays full-bleed -- letterboxing a horror game to dodge a notch
## would be a poor trade -- so the insets are read from CSS by the HTML shell
## (which is the only thing that can see env(safe-area-inset-*)) and published
## as window.__itaw_safeArea(). Off the web this is a no-op.

const BRIDGE_CALL := "window.__itaw_safeArea ? window.__itaw_safeArea() : ''"

## Breathing room added on every edge on top of the device insets.
@export_range(0, 48, 1) var padding: int = 10

var _insets := Vector4.ZERO


func _ready() -> void:
	get_tree().root.size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_insets = _query_insets()
	add_theme_constant_override("margin_top", int(_insets.x) + padding)
	add_theme_constant_override("margin_right", int(_insets.y) + padding)
	add_theme_constant_override("margin_bottom", int(_insets.z) + padding)
	add_theme_constant_override("margin_left", int(_insets.w) + padding)


## Returns (top, right, bottom, left) in viewport pixels.
func _query_insets() -> Vector4:
	if not OS.has_feature("web"):
		return Vector4.ZERO
	var raw: Variant = JavaScriptBridge.eval(BRIDGE_CALL, true)
	if not (raw is String) or (raw as String).is_empty():
		return Vector4.ZERO
	var parts := (raw as String).split(",")
	if parts.size() != 4:
		return Vector4.ZERO
	return Vector4(
		float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])
	)
