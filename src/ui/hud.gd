class_name Hud
extends CanvasLayer

## Owns the on-screen controls and the screen area they occupy.
##
## It translates touches into intent and hands that on; it knows nothing about
## the player, so the same HUD can drive a menu camera or a cutscene rig later.
## Every touch goes through one TouchRouter, so the two sticks can never fight
## over a finger, and every control registers the rect it occupies with HudRects
## so nothing else is ever drawn under a thumb.
##
## The build stamp is deliberately *not* here -- it lives in the HTML shell, so
## it is readable and copyable even when the engine has failed to boot, which is
## exactly when you most want to know which build you are looking at.

signal look_requested(pixels: Vector2)
signal pause_requested
signal action_pressed
## Gestures while the player is engaged with something. Screen positions and
## deltas in viewport units; Main forwards them to whatever holds the focus.
signal puzzle_pressed(screen: Vector2)
signal puzzle_dragged(screen: Vector2, delta: Vector2)
signal puzzle_lifted

enum LookStyle { STICK, DRAG }

const MOVE := &"move_stick"
const LOOK := &"look_stick"
const PAUSE := &"pause"
const DRAG := &"drag_look"
const ACTION := &"action"
const PUZZLE := &"puzzle"
const ACTION_ARC := &"action_arc"
const PROMPT := &"prompt"
## Room reserved for the interact/flashlight/crouch buttons P1 puts on the arc.
const ACTION_SLOTS := 3
## How far below the safe-area top the debug overlay starts, in points. The HTML
## shell draws the build stamp in that corner and Godot cannot see it, so the
## clearance is measured in the shell's units and converted here.
const OVERLAY_TOP_POINTS := 56.0

@export var layout: HudLayout
@export var tuning: TouchTuning

@onready var _safe: SafeArea = $SafeArea
@onready var _router: TouchRouter = $TouchRouter
@onready var _watch: TouchWatch = $TouchRouter/TouchWatch
@onready var _rects: HudRects = $HudRects
@onready var _pad: LookPad = $LookPad
@onready var _move: VirtualStick = $Controls/MoveStick
@onready var _look: VirtualStick = $Controls/LookStick
@onready var _pause: TouchButton = $Controls/PauseButton
@onready var _action: TouchButton = $Controls/ActionButton
@onready var _prompt: Label = $Controls/Prompt
@onready var _overlay: DebugOverlay = $SafeArea/DebugOverlay

var _style: LookStyle = LookStyle.STICK
var _stick_offset := Vector2.ZERO
var _stick_scale := 1.0
var _focused := false


func _ready() -> void:
	# Runtime copies: the player's settings write to these every time a slider
	# moves, and the resources on disk stay the authored defaults.
	layout = layout.duplicate() as HudLayout
	tuning = tuning.duplicate() as TouchTuning
	_router.tuning = tuning
	for stick in [_move, _look]:
		stick.tuning = tuning
	_pause.tuning = tuning
	_action.tuning = tuning
	_action.glyph = TouchButton.Glyph.DOT
	_action.visible = false
	_prompt.visible = false
	_router.claimed.connect(_on_claimed)
	_router.moved.connect(_on_moved)
	_router.released.connect(_on_released)
	_pad.looked.connect(look_requested.emit)
	_pause.pressed.connect(_on_pause_pressed)
	_action.pressed.connect(_on_action_pressed)
	_watch.three_finger_tapped.connect(_overlay.toggle)
	_overlay.bind(_watch, self, _rects)
	_safe.changed.connect(_relayout)
	_relayout()


## Locomotion intent this frame: x = strafe, y = forward, each -1..1.
## Continuous analogue state, so it is read rather than pushed through a signal.
func get_move_intent() -> Vector2:
	var keys := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return (_move.value + keys).limit_length(1.0)


## Look stick deflection: x = right, y = up, each -1..1. Zero under the drag
## style, which reports travel through `look_requested` instead.
func get_look_intent() -> Vector2:
	return _look.value if _style == LookStyle.STICK else Vector2.ZERO


func look_style() -> LookStyle:
	return _style


## Offers the thing in front of the player, or nothing. The button and the
## prompt appear and disappear together; there is never one without the other.
func show_target(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty()
	_action.visible = _prompt.visible
	_action.label = text
	_action.queue_redraw()
	_register_regions()


## Locks the HUD to whatever the player engaged with: the sticks go away and
## every gesture that is not a button belongs to the puzzle.
func set_focused(on: bool) -> void:
	if _focused == on:
		return
	_focused = on
	_router.release_all()
	_relayout()


func is_focused() -> bool:
	return _focused


## Whether a point on screen is under a control. World-space targeting asks
## before offering something the player's own thumb is covering.
func blocks_world_point(screen: Vector2) -> bool:
	return _rects.blocks_point(screen)


## Lets go of every touch. Called before pausing so no stick is left deflected
## by a thumb whose release the paused tree will never hear about.
func release_touches() -> void:
	_router.release_all()


func set_input_enabled(enabled: bool) -> void:
	_router.set_enabled(enabled)


func on_setting(key: StringName, value: float) -> void:
	match key:
		&"look_style":
			_style = LookStyle.DRAG if int(value) == 1 else LookStyle.STICK
		&"stick_size":
			_stick_scale = value
		&"stick_opacity":
			tuning.rest_opacity = value
			tuning.active_opacity = minf(value * 2.0, 1.0)
		&"stick_offset_x":
			_stick_offset.x = value
		&"stick_offset_y":
			_stick_offset.y = value
		&"stick_deadzone":
			tuning.deadzone = value
		&"cue_mode":
			_look.marker = int(value) == 1
		&"haptics":
			Haptics.enabled = value >= 0.5
		_:
			return
	_relayout()


## What the debug overlay publishes on the HUD's behalf.
func probe() -> Dictionary:
	return {
		"style": "drag" if _style == LookStyle.DRAG else "stick",
		"claims": _router.claims(),
		"move": [_move.value.x, _move.value.y],
		"look": [_look.value.x, _look.value.y],
		"focused": _focused,
		"prompt": _prompt.text if _prompt.visible else "",
		"rects": _rects.describe(),
	}


func _relayout() -> void:
	var safe := _safe.rect()
	var scale := _safe.points_to_units()
	var radius := layout.stick_radius * _stick_scale
	_move.position = layout.move_stick_centre(safe, _stick_offset)
	_look.position = layout.look_stick_centre(safe, _stick_offset)
	_pause.position = layout.pause_centre(safe)
	_overlay.offset_top = OVERLAY_TOP_POINTS * scale
	_action.position = layout.action_centre(safe, _stick_offset, 0)
	_action.radius = maxf(layout.action_button_radius, layout.min_touch_points * scale * 0.5)
	_place_prompt(safe)
	_pause.radius = maxf(layout.pause_radius, layout.min_touch_points * scale * 0.5)
	for stick in [_move, _look]:
		stick.radius = radius
		stick.knob_radius = layout.knob_radius * _stick_scale
	_move.visible = not _focused
	_look.visible = _style == LookStyle.STICK and not _focused
	for node in [_move, _look, _pause, _action]:
		node.queue_redraw()
	_register_regions()
	_reserve_rects()


## Registration order is priority: the buttons first, then the sticks, then --
## under the drag style only -- a region covering everything else. A touch is
## tested against these in this order once, when it lands, and belongs to the
## winner until it lifts.
func _register_regions() -> void:
	for id in [PAUSE, ACTION, MOVE, LOOK, DRAG, PUZZLE]:
		_router.remove_region(id)
	_router.add_region(PAUSE, _pause_rect)
	if _action.visible:
		_router.add_region(ACTION, _action_rect.bind(0))
	if _focused:
		_router.add_region(PUZZLE, _screen_rect)
		return
	_router.add_region(MOVE, _stick_rect.bind(_move))
	if _style == LookStyle.STICK:
		_router.add_region(LOOK, _stick_rect.bind(_look))
		return
	_router.add_region(DRAG, _screen_rect)


func _reserve_rects() -> void:
	_rects.reserve(PAUSE, _pause_rect)
	_rects.reserve(MOVE, _stick_rect.bind(_move))
	for slot in ACTION_SLOTS:
		_rects.reserve(StringName("%s_%d" % [ACTION_ARC, slot]), _action_rect.bind(slot))
	if _style == LookStyle.STICK:
		_rects.reserve(LOOK, _stick_rect.bind(_look))
	else:
		_rects.release(LOOK)


## The prompt is a consumer of screen area, not an owner of it: it asks rather
## than reserves, and an overlap is reported instead of drawn.
func _place_prompt(safe: Rect2) -> void:
	var area := layout.prompt_rect(safe, _stick_offset)
	_prompt.position = area.position
	_prompt.size = area.size
	_rects.require_clear(PROMPT, area)


func _stick_rect(stick: VirtualStick) -> Rect2:
	var reach := stick.radius + layout.claim_padding
	return Rect2(stick.position - Vector2(reach, reach), Vector2(reach, reach) * 2.0)


func _pause_rect() -> Rect2:
	return layout.touch_rect(_pause.position, layout.pause_radius, _safe.points_to_units())


## One slot on the action arc, reserved before a single button exists on it, so
## nothing else settles into the space the interact button is going to need.
## Per slot rather than as one bounding box: the box around an arc is mostly
## empty, and reserving emptiness is how a HUD runs out of room.
func _action_rect(slot: int) -> Rect2:
	return layout.touch_rect(
		layout.action_centre(_safe.rect(), _stick_offset, slot),
		layout.action_button_radius,
		_safe.points_to_units()
	)


func _screen_rect() -> Rect2:
	return get_viewport().get_visible_rect()


func _on_claimed(id: StringName, index: int, position: Vector2) -> void:
	match id:
		MOVE: _move.press(index, position)
		LOOK: _look.press(index, position)
		PAUSE: _pause.press(index, position)
		ACTION: _action.press(index, position)
		DRAG: _pad.press(index, position)
		PUZZLE: puzzle_pressed.emit(position)


func _on_moved(id: StringName, index: int, position: Vector2, delta: Vector2) -> void:
	match id:
		MOVE: _move.drag(index, position)
		LOOK: _look.drag(index, position)
		PAUSE: _pause.drag(index, position)
		ACTION: _action.drag(index, position)
		DRAG: _pad.drag(index, delta)
		PUZZLE: puzzle_dragged.emit(position, delta)


func _on_released(id: StringName, index: int) -> void:
	match id:
		MOVE: _move.release(index)
		LOOK: _look.release(index)
		PAUSE: _pause.release(index)
		ACTION: _action.release(index)
		DRAG: _pad.release(index)
		PUZZLE: puzzle_lifted.emit()


func _on_pause_pressed() -> void:
	Haptics.tap()
	pause_requested.emit()


func _on_action_pressed() -> void:
	Haptics.tap()
	action_pressed.emit()
