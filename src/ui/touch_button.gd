class_name TouchButton
extends Control

## A round button drawn with primitives, driven by TouchRouter rather than by
## Godot's GUI input.
##
## Everything on this HUD has to agree about who owns a touch, and a Control
## that grabs its own would be outside that agreement -- which is how a thumb
## sliding off the pause button ends up also turning the camera. The Control's
## position is its centre; Hud places it from HudLayout.

signal pressed

## Shown inside the button. One or two glyphs, drawn as geometry by `_draw`.
enum Glyph { PAUSE, DOT }

const LABEL_SIZE := 15

var tuning: TouchTuning
var radius := 34.0
var glyph: Glyph = Glyph.PAUSE
## Drawn under the ring. Empty for the pause button, which is a glyph.
var label := ""

var _index := -1
var _inside := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func press(index: int, position: Vector2) -> void:
	_index = index
	_inside = _contains(position)
	queue_redraw()


func drag(index: int, position: Vector2) -> void:
	if index != _index:
		return
	var inside := _contains(position)
	if inside == _inside:
		return
	_inside = inside
	queue_redraw()


## Fires only if the thumb is still on the button. Sliding off is how a phone
## says "I did not mean that".
func release(index: int) -> void:
	if index != _index:
		return
	_index = -1
	var fire := _inside
	_inside = false
	queue_redraw()
	if fire:
		pressed.emit()


func _contains(position: Vector2) -> bool:
	return position.distance_to(global_position) <= radius


func _draw() -> void:
	var alpha := tuning.active_opacity if (_index != -1 and _inside) else tuning.rest_opacity
	var ink := Color(tuning.tint, alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, ink, 2.0, true)
	match glyph:
		Glyph.PAUSE:
			var bar := Vector2(radius * 0.16, radius * 0.46)
			var gap := radius * 0.20
			draw_rect(Rect2(Vector2(-gap - bar.x, -bar.y), bar), ink)
			draw_rect(Rect2(Vector2(gap, -bar.y), bar), ink)
		Glyph.DOT:
			draw_circle(Vector2.ZERO, radius * 0.30, ink)
	if not label.is_empty():
		_draw_label(ink)


func _draw_label(ink: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(
		font, Vector2(-width * 0.5, radius + LABEL_SIZE + 4.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ink
	)
