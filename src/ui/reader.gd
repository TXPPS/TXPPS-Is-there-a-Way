class_name Reader
extends CanvasLayer

## The full-screen page, for reading something on a phone in the dark.
##
## Shown while the player is engaged with a Readable, so it inherits the whole
## focused-interaction contract for free: the sticks go away, gestures come here
## instead of to the camera, and the action button says "Put it down".
##
## Body size follows the **Subtitle size** setting. That setting had nothing to
## read until now, and a document a player cannot read is a document that is not
## in the game.

const BODY_SIZES: Array[int] = [17, 21, 26, 33]
const TITLE_RATIO := 1.35
## Viewport units of drag per unit of scroll. One-to-one: a page should move
## with the thumb, not faster than it.
const SCROLL_RATE := 1.0
## The HTML shell draws the build stamp in the corner this page puts its title
## in. Reference-counted in the shell, because the pause menu wants it too.
const COVER_CALL := "window.__itaw_coverStamp && window.__itaw_coverStamp('page', %s)"

## Emitted when a page is put down. Distinct from `close()` being called for any
## other reason, so something that showed a page can know the player is done
## with it rather than that the game moved on.
signal closed_by_player

@onready var _panel: PanelContainer = $Safe/Panel
@onready var _title: Label = $Safe/Panel/Pad/Body/Title
@onready var _byline: Label = $Safe/Panel/Pad/Body/Byline
@onready var _scroll: ScrollContainer = $Safe/Panel/Pad/Body/Scroll
@onready var _text: Label = $Safe/Panel/Pad/Body/Scroll/Text

var _size_index := 1
var _open := false


func _ready() -> void:
	visible = false


func show_document(document: Document) -> void:
	if document == null:
		return
	_title.text = document.title
	_byline.text = document.byline
	_byline.visible = not document.byline.is_empty()
	_text.text = "\n".join(document.lines())
	_apply_hand(document.hand)
	_apply_size()
	_scroll.scroll_vertical = 0
	_open = true
	visible = true
	_cover_stamp(true)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_cover_stamp(false)
	closed_by_player.emit()


func is_open() -> bool:
	return _open


func _cover_stamp(on: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(COVER_CALL % ("true" if on else "false"), true)


## The page moves with the thumb. Not a flick, not momentum: a sheet of paper
## held in one hand does not have inertia.
func scroll_by(delta: Vector2) -> void:
	if not _open:
		return
	_scroll.scroll_vertical += int(-delta.y * SCROLL_RATE)


func on_setting(key: StringName, value: float) -> void:
	if key != &"subtitle_size":
		return
	_size_index = clampi(int(round(value)), 0, BODY_SIZES.size() - 1)
	_apply_size()


func _apply_size() -> void:
	var body: int = BODY_SIZES[_size_index]
	_text.add_theme_font_size_override("font_size", body)
	_title.add_theme_font_size_override("font_size", int(body * TITLE_RATIO))
	_byline.add_theme_font_size_override("font_size", maxi(12, int(body * 0.7)))


## Four hands, four looks. A player should know who wrote a page before they
## have read a word of it.
func _apply_hand(hand: Document.Hand) -> void:
	match hand:
		Document.Hand.PENCIL:
			_text.add_theme_color_override("font_color", Color(0.72, 0.71, 0.68))
			_text.add_theme_constant_override("line_spacing", 8)
		Document.Hand.STENCIL:
			_text.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
			_text.add_theme_constant_override("line_spacing", 10)
		Document.Hand.PRINTED:
			_text.add_theme_color_override("font_color", Color(0.84, 0.84, 0.82))
			_text.add_theme_constant_override("line_spacing", 4)
		_:
			_text.add_theme_color_override("font_color", Color(0.78, 0.77, 0.74))
			_text.add_theme_constant_override("line_spacing", 6)
