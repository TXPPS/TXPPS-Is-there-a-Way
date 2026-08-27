class_name ControlsDiagram
extends Control

## A picture of the control scheme currently in force.
##
## A settings menu that describes its own controls in prose is a settings menu
## nobody reads. This draws the screen and points at the things on it, and
## redraws the moment Look style changes, so the answer to "what does the right
## thumb do now" is always on screen next to the switch that changed it.

const SCREEN_MARGIN := 10.0
const LABEL_SIZE := 15
const CAPTION_SIZE := 14
const CORNER := 10.0

var _drag_style := false
var _tint := Color(0.86, 0.88, 0.92)
var _accent := Color(0.62, 0.79, 0.94)


func show_style(drag_style: bool, tint: Color, accent: Color) -> void:
	_drag_style = drag_style
	_tint = tint
	_accent = accent
	queue_redraw()


func _draw() -> void:
	var screen := Rect2(Vector2(SCREEN_MARGIN, SCREEN_MARGIN), size - Vector2(SCREEN_MARGIN, SCREEN_MARGIN) * 2.0)
	if screen.size.x <= 0.0 or screen.size.y <= 0.0:
		return
	draw_rect(screen, Color(_tint, 0.06), true)
	_draw_frame(screen)
	_draw_move(screen)
	if _drag_style:
		_draw_drag(screen)
	else:
		_draw_look(screen)
	_draw_pause(screen)


func _draw_frame(screen: Rect2) -> void:
	draw_rect(screen, Color(_tint, 0.30), false, 1.5)
	_caption(
		Vector2(screen.position.x, screen.end.y + CAPTION_SIZE + 2.0),
		"Drag to look" if _drag_style else "Fixed twin sticks"
	)


func _draw_move(screen: Rect2) -> void:
	var centre := Vector2(screen.position.x + screen.size.x * 0.13, screen.end.y - screen.size.y * 0.28)
	_ring(centre, screen.size.y * 0.17, _accent)
	_label(centre, "Move")


func _draw_look(screen: Rect2) -> void:
	var centre := Vector2(screen.end.x - screen.size.x * 0.13, screen.end.y - screen.size.y * 0.28)
	_ring(centre, screen.size.y * 0.17, _accent)
	_label(centre, "Look")


## The whole area a drag may start in, minus the corner the move stick holds.
func _draw_drag(screen: Rect2) -> void:
	var area := Rect2(
		Vector2(screen.position.x + screen.size.x * 0.30, screen.position.y + screen.size.y * 0.12),
		Vector2(screen.size.x * 0.62, screen.size.y * 0.76)
	)
	draw_rect(area, Color(_accent, 0.12), true)
	draw_rect(area, Color(_accent, 0.55), false, 1.5)
	_label(area.get_center(), "Drag")


func _draw_pause(screen: Rect2) -> void:
	var centre := Vector2(screen.end.x - screen.size.x * 0.06, screen.position.y + screen.size.y * 0.16)
	var r := screen.size.y * 0.075
	_ring(centre, r, _tint)
	var bar := Vector2(r * 0.16, r * 0.46)
	draw_rect(Rect2(Vector2(centre.x - r * 0.20 - bar.x, centre.y - bar.y), bar), Color(_tint, 0.8))
	draw_rect(Rect2(Vector2(centre.x + r * 0.20, centre.y - bar.y), bar), Color(_tint, 0.8))
	_caption(Vector2(centre.x - r * 3.4, centre.y - r - 4.0), "Pause")


func _ring(centre: Vector2, radius: float, colour: Color) -> void:
	draw_arc(centre, radius, 0.0, TAU, 32, Color(colour, 0.75), 1.5, true)
	draw_circle(centre, radius * 0.34, Color(colour, 0.55))


func _label(centre: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(
		font, centre + Vector2(-width * 0.5, LABEL_SIZE * 2.2), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(_tint, 0.9)
	)


func _caption(at: Vector2, text: String) -> void:
	draw_string(
		ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		CAPTION_SIZE, Color(_tint, 0.7)
	)
