class_name PauseMenu
extends CanvasLayer

## Pause, and everything that is only reachable from it.
##
## Pausing has to do four things or it is not a pause: stop the simulation, let
## go of every touch, duck the world, and give control back without the camera
## jumping. The first and the last are Godot's; the middle two are announced
## through `opened` / `closed`, which Main uses to tell the HUD to release its
## thumbs before the tree stops delivering input to it.
##
## The settings list builds itself from the SettingsSpec, so this script never
## learns the name of a preference.

signal opened
signal closed
signal return_to_title

## A phone has no quit. Returning to the title means going back to the tap gate,
## which on the web is a reload of a fully-cached page.
const TITLE_CALL := "window.__itaw_returnToTitle && window.__itaw_returnToTitle()"
const COPY_CALL := "window.__itaw_copyStamp && window.__itaw_copyStamp()"
## The menu is the safe point the HTML shell holds its update banner for, and
## the flag the browser suite reads to know the game really did pause.
const GATE_CALL := "window.__itaw_paused = %s;"\
	+ " window.__itaw_setUpdateGate && window.__itaw_setUpdateGate(%s);"\
	+ " window.__itaw_coverStamp && window.__itaw_coverStamp('menu', %s)"
## Published on open so the browser suite can prove the menu fits on the screen
## it is drawn on -- a panel taller than the viewport puts Resume out of reach,
## and a screenshot of a canvas cannot be asked where its buttons are.
const LAYOUT_CALL := "window.__itaw_menu = "
const SAMPLE_TEXT := "\"Sample subtitle: something moved in the wet room.\""
const SAMPLE_SIZES := [16, 20, 26, 34]
const GROUP_ALPHA := 0.55

const COLUMN := "Safe/Panel/Pad/Body/Scroll/Column"

@onready var _groups: VBoxContainer = get_node(COLUMN + "/Groups")
@onready var _diagram: ControlsDiagram = get_node(COLUMN + "/Diagram")
@onready var _resume: Button = $Safe/Panel/Pad/Body/Head/Resume
@onready var _title: Button = get_node(COLUMN + "/ReturnToTitle")
@onready var _confirm: HBoxContainer = get_node(COLUMN + "/Confirm")
@onready var _stamp: Button = get_node(COLUMN + "/Stamp")

var _settings: GameSettings
var _tuning: TouchTuning
var _saves: SaveService
var _saves_panel: SavesPanel
var _sample: Label
var _is_open := false


## Wired by Main rather than exported: the settings service is a node in the
## composition root, and a NodePath into it from here would be one more thing
## that silently breaks when the scene is rearranged.
func bind(settings: GameSettings, tuning: TouchTuning, saves: SaveService) -> void:
	_settings = settings
	_tuning = tuning
	_saves = saves
	_settings.changed.connect(_on_setting)
	_build()
	_refresh()


func _ready() -> void:
	visible = false
	set_process(false)
	_resume.pressed.connect(close)
	_title.pressed.connect(_ask_confirm)
	_stamp.pressed.connect(_copy_stamp)
	get_node(COLUMN + "/Confirm/Yes").pressed.connect(_confirm_title)
	get_node(COLUMN + "/Confirm/No").pressed.connect(_cancel_confirm)
	_stamp.text = BuildInfo.describe()
	_confirm.visible = false


## Escape opens and closes it. There is no keyboard on the phone; this exists so
## a desktop editor session and the browser suite can pause without hunting for
## a button drawn on a canvas.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_cancel_confirm()
	if _saves_panel != null:
		_saves_panel.refresh()
	_refresh()
	visible = true
	opened.emit()
	_announce(true)
	AudioBuses.set_ducked(true)
	get_tree().paused = true


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = false
	AudioBuses.set_ducked(false)
	_announce(false)
	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _build() -> void:
	for child in _groups.get_children():
		child.queue_free()
	_groups.add_child(_heading("Saves"))
	_saves_panel = SavesPanel.create(_saves)
	_groups.add_child(_saves_panel)
	for group in _settings.spec.groups():
		_groups.add_child(_heading(group))
		for row in _settings.spec.rows_in(group):
			_groups.add_child(SettingsRowControl.create(row, _settings))
		if group == "Accessibility":
			_sample = _subtitle_sample()
			_groups.add_child(_sample)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.modulate = Color(1.0, 1.0, 1.0, GROUP_ALPHA)
	return label


## Shows the chosen subtitle size on real text, immediately. Nothing else speaks
## yet, and a size setting you cannot see the effect of is a setting you cannot
## choose.
func _subtitle_sample() -> Label:
	var label := Label.new()
	label.text = SAMPLE_TEXT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _refresh() -> void:
	if _settings == null:
		return
	_diagram.show_style(_settings.choice(&"look_style") == 1, _tuning.tint, _tuning.accent)
	_apply_sample_size(_settings.choice(&"subtitle_size"))


func _apply_sample_size(index: int) -> void:
	if _sample == null:
		return
	var clamped := clampi(index, 0, SAMPLE_SIZES.size() - 1)
	_sample.add_theme_font_size_override("font_size", SAMPLE_SIZES[clamped])


func _on_setting(key: StringName, value: float) -> void:
	match key:
		&"look_style":
			_diagram.show_style(int(value) == 1, _tuning.tint, _tuning.accent)
		&"subtitle_size":
			_apply_sample_size(int(value))


func _ask_confirm() -> void:
	_confirm.visible = true
	_title.visible = false


func _cancel_confirm() -> void:
	_confirm.visible = false
	_title.visible = true


func _confirm_title() -> void:
	return_to_title.emit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(TITLE_CALL, true)
		return
	get_tree().quit()


func _announce(open: bool) -> void:
	if not OS.has_feature("web"):
		return
	var flag := "true" if open else "false"
	JavaScriptBridge.eval(GATE_CALL % [flag, flag, flag], true)
	set_process(open)


## Published a frame after opening, not on the open itself: containers are laid
## out at the end of the frame, so anything asked for its rect before then
## answers with where it used to be.
func _process(_delta: float) -> void:
	set_process(false)
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(LAYOUT_CALL + JSON.stringify({
		"view": _flat(get_viewport().get_visible_rect()),
		"panel": _flat($Safe/Panel.get_global_rect()),
		"resume": _flat(_resume.get_global_rect()),
	}), true)


static func _flat(r: Rect2) -> Array:
	return [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]


func _copy_stamp() -> void:
	Haptics.tap()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(COPY_CALL, true)
		return
	DisplayServer.clipboard_set(BuildInfo.describe())
