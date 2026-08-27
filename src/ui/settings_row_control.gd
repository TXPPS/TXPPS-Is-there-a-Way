class_name SettingsRowControl
extends VBoxContainer

## One line of the settings menu, built from one SettingsRow.
##
## There is deliberately no per-setting UI code anywhere else: a preference that
## exists in the spec gets a widget here, and a preference that does not exist
## in the spec cannot be shown. Choices are a row of buttons rather than a
## dropdown because a popup on a phone is a second thing that can go wrong.

## Apple's floor for a touch target, in viewport units at this project's design
## width. Everything the thumb has to hit in the menu is at least this tall.
const TOUCH_MIN := 60.0
const HINT_ALPHA := 0.62

var _row: SettingsRow
var _settings: GameSettings
var _readout: Label
var _slider: HSlider
var _toggle: CheckButton
var _choices: Array[Button] = []
var _echoing := false


static func create(row: SettingsRow, settings: GameSettings) -> SettingsRowControl:
	var control := SettingsRowControl.new()
	control._row = row
	control._settings = settings
	return control


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_build_header()
	match _row.kind:
		SettingsRow.Kind.TOGGLE: _build_toggle()
		SettingsRow.Kind.CHOICE: _build_choices()
		_: _build_slider()
	if not _row.hint.is_empty():
		_build_hint()
	_settings.changed.connect(_on_changed)
	_show(_settings.value(_row.key))


func _build_header() -> void:
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = _row.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_readout = Label.new()
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(label)
	line.add_child(_readout)
	add_child(line)


func _build_hint() -> void:
	var hint := Label.new()
	hint.text = _row.hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
	add_child(hint)


func _build_slider() -> void:
	_slider = HSlider.new()
	_slider.min_value = _row.minimum
	_slider.max_value = _row.maximum
	_slider.step = _row.step
	_slider.custom_minimum_size.y = TOUCH_MIN
	_slider.value_changed.connect(_on_widget_value)
	add_child(_slider)


func _build_toggle() -> void:
	_toggle = CheckButton.new()
	_toggle.text = ""
	_toggle.custom_minimum_size.y = TOUCH_MIN
	_toggle.toggled.connect(func(on: bool) -> void: _on_widget_value(1.0 if on else 0.0))
	add_child(_toggle)


func _build_choices() -> void:
	var line := HBoxContainer.new()
	for index in _row.choices.size():
		var button := Button.new()
		button.text = _row.choices[index]
		button.toggle_mode = true
		button.custom_minimum_size.y = TOUCH_MIN
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_widget_value.bind(float(index)))
		line.add_child(button)
		_choices.append(button)
	add_child(line)


func _on_widget_value(value: float) -> void:
	if _echoing:
		return
	Haptics.tap()
	_settings.set_value(_row.key, value)


func _on_changed(key: StringName, value: float) -> void:
	if key == _row.key:
		_show(value)


## Writes the widget without letting it write back: a slider being moved by the
## code that a slider moved is how a settings menu ends up oscillating.
func _show(value: float) -> void:
	_echoing = true
	_readout.text = _row.describe(value)
	if _slider != null:
		_slider.value = value
	if _toggle != null:
		_toggle.button_pressed = value >= 0.5
	for index in _choices.size():
		_choices[index].button_pressed = index == int(round(value))
	_echoing = false
