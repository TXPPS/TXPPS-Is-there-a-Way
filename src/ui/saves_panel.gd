class_name SavesPanel
extends VBoxContainer

## The save controls in the pause menu.
##
## Two slots, an export code, and a delete behind a confirm. The code is not a
## power-user feature: Safari evicts storage for a site nobody installed after
## about a week idle, so on this platform a save the player can hold in a
## message to themselves is the only one that is really theirs.
##
## Text goes in and out through the HTML shell rather than a Godot LineEdit,
## because raising the iOS keyboard from a canvas needs an export option this
## project does not enable, and a prompt() the browser draws always works.

const TOUCH_MIN := 60.0
const COPY_CALL := "window.__itaw_copyText && window.__itaw_copyText(%s, %s)"
const PROMPT_CALL := "window.__itaw_promptText ? window.__itaw_promptText(%s, '') : ''"
const HINT_ALPHA := 0.62

var _saves: SaveService
var _status: Label
var _delete: Button
var _confirm: HBoxContainer


static func create(saves: SaveService) -> SavesPanel:
	var panel := SavesPanel.new()
	panel._saves = saves
	return panel


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
	add_child(_status)
	add_child(_row([
		["Save", _on_save], ["Load", _on_load],
	]))
	add_child(_row([
		["Export code", _on_export], ["Import code", _on_import],
	]))
	_delete = _button("Delete save", _on_delete_asked)
	add_child(_delete)
	_build_confirm()
	_saves.saved.connect(func(_slot: StringName) -> void: refresh())
	_saves.loaded.connect(func(_slot: StringName) -> void: refresh())
	refresh()


func refresh() -> void:
	var lines := PackedStringArray()
	lines.append("Autosave: %s" % ("kept" if _saves.has(SaveService.AUTO) else "none yet"))
	lines.append("Your save: %s" % ("kept" if _saves.has(SaveService.MANUAL) else "none"))
	if not Storage.is_durable():
		lines.append("This browser is not keeping anything. Export a code.")
	elif Storage.persistence() == "no":
		lines.append("Storage here is temporary. Add to Home Screen, or export a code.")
	_status.text = "  ·  ".join(lines)
	_delete.disabled = not _saves.has(SaveService.MANUAL)


func _row(pairs: Array) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	for pair in pairs:
		line.add_child(_button(pair[0] as String, pair[1] as Callable))
	return line


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = TOUCH_MIN
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		Haptics.tap()
		action.call()
	)
	return button


func _build_confirm() -> void:
	_confirm = HBoxContainer.new()
	_confirm.visible = false
	_confirm.add_theme_constant_override("separation", 10)
	var ask := Label.new()
	ask.text = "Delete your save? The autosave stays."
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.add_child(ask)
	_confirm.add_child(_button("Delete", _on_delete_confirmed))
	_confirm.add_child(_button("Keep", _on_delete_cancelled))
	add_child(_confirm)


func _on_save() -> void:
	if _saves.save_to(SaveService.MANUAL):
		Notify.say("Saved.")
	refresh()


func _on_load() -> void:
	if _saves.load_from(SaveService.MANUAL):
		Notify.say("Loaded.")


func _on_export() -> void:
	var code := _saves.export_code()
	if not OS.has_feature("web"):
		DisplayServer.clipboard_set(code)
		Notify.say("Save code copied.")
		return
	JavaScriptBridge.eval(
		COPY_CALL % [JSON.stringify(code), JSON.stringify("Save code copied.")], true
	)


func _on_import() -> void:
	var code := _read_code()
	if code.strip_edges().is_empty():
		return
	if _saves.import_code(code):
		Notify.say("Save code accepted.")
		refresh()


func _read_code() -> String:
	if not OS.has_feature("web"):
		return DisplayServer.clipboard_get()
	var raw: Variant = JavaScriptBridge.eval(
		PROMPT_CALL % JSON.stringify("Paste your save code."), true
	)
	return raw as String if raw is String else ""


func _on_delete_asked() -> void:
	_confirm.visible = true
	_delete.visible = false


func _on_delete_cancelled() -> void:
	_confirm.visible = false
	_delete.visible = true


func _on_delete_confirmed() -> void:
	_saves.erase(SaveService.MANUAL)
	_on_delete_cancelled()
	Notify.say("Save deleted.")
	refresh()
