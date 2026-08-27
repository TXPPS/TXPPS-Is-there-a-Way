class_name SaveService
extends Node

## Collects the world into a Dictionary, writes it, and puts it back.
##
## Two slots and no more: `auto`, which the game writes without being asked, and
## `manual`, which the player writes. A phone loses tabs without warning, so the
## autosave is the one that matters and the manual one is for "let me try
## something stupid".
##
## Everything that has state worth keeping joins the `saveable` group and
## implements three things:
##
##     var save_key: StringName        # stable; changing one orphans that state
##     func save_state() -> Dictionary
##     func load_state(state: Dictionary) -> void
##
## Duck-typed rather than an interface, so a puzzle does not have to inherit
## from anything to be saveable.

signal saved(slot: StringName)
signal loaded(slot: StringName)
signal failed(reason: String)

const GROUP := &"saveable"
const AUTO := &"auto"
const MANUAL := &"manual"
const KEY := "save."

## Registered with the HTML shell, which calls it on freeze, pagehide and the
## moment the tab goes hidden. iOS discards a backgrounded tab without running
## another frame, so this is the last chance to write anything.
const SUSPEND_HOOK := "__itaw_onSuspend"

var _play_seconds := 0.0
var _checkpoint := "start"
var _suspend_callback: JavaScriptObject


func _ready() -> void:
	_install_suspend_hook()


func _process(delta: float) -> void:
	_play_seconds += delta


func has(slot: StringName) -> bool:
	return not Storage.read(_key(slot)).is_empty()


func erase(slot: StringName) -> void:
	Storage.erase(_key(slot))


## Marks a point worth returning to and writes the autosave. Called by whatever
## decides a moment is a checkpoint -- a door closing behind you, a puzzle
## solved -- never on a timer, because a timer autosaves mid-fall.
func checkpoint(id: String) -> void:
	_checkpoint = id
	save_to(AUTO)


func checkpoint_id() -> String:
	return _checkpoint


func play_seconds() -> float:
	return _play_seconds


## The whole world as a Dictionary. Every member of the group contributes under
## its own key; a member with no key, or a duplicate one, is a programming error
## and says so rather than silently overwriting its neighbour.
func collect() -> Dictionary:
	var data := SaveGame.fresh()
	data["saved_at"] = Time.get_datetime_string_from_system(true)
	data["play_seconds"] = _play_seconds
	data["checkpoint"] = _checkpoint
	var nodes: Dictionary = data["nodes"]
	for node in get_tree().get_nodes_in_group(GROUP):
		var key := _key_of(node)
		if key == &"":
			continue
		if nodes.has(String(key)):
			push_error("Two saveable nodes share the key '%s'." % key)
			continue
		nodes[String(key)] = node.call("save_state")
	return data


## Puts a save back. Unknown keys are ignored rather than refused: a save from a
## build with a puzzle this one does not have is still a save.
func apply(data: Dictionary) -> bool:
	var migrated := SaveGame.migrate(data)
	if migrated.is_empty():
		_fail("That save is from a build this one does not understand.")
		return false
	var nodes: Dictionary = migrated.get("nodes", {})
	for node in get_tree().get_nodes_in_group(GROUP):
		var key := _key_of(node)
		if key != &"" and nodes.has(String(key)):
			node.call("load_state", nodes[String(key)])
	_play_seconds = float(migrated.get("play_seconds", 0.0))
	_checkpoint = str(migrated.get("checkpoint", "start"))
	return true


## Writes, then reads back. A write that cannot be read back did not happen,
## whatever the browser said at the time.
func save_to(slot: StringName) -> bool:
	var data := collect()
	var text := JSON.stringify(data)
	Storage.write(_key(slot), text)
	if Storage.read(_key(slot)) != text:
		_fail("This browser will not keep a save. Use Export code to keep one by hand.")
		return false
	saved.emit(slot)
	return true


func load_from(slot: StringName) -> bool:
	var text := Storage.read(_key(slot))
	if text.is_empty():
		_fail("There is nothing in that slot.")
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not SaveGame.is_shaped_like_a_save(parsed):
		_fail("That slot holds something that is not a save.")
		return false
	if not apply(parsed as Dictionary):
		return false
	loaded.emit(slot)
	return true


## The current world as a code the player can paste somewhere safe.
func export_code() -> String:
	return SaveGame.to_code(collect())


func import_code(code: String) -> bool:
	var data := SaveGame.from_code(code)
	if data.is_empty():
		_fail("That code is not complete. Copy the whole of it, including ITAW.")
		return false
	if not SaveGame.is_shaped_like_a_save(data):
		_fail("That code is well-formed but is not a save.")
		return false
	if not apply(data):
		return false
	save_to(MANUAL)
	loaded.emit(MANUAL)
	return true


func _fail(reason: String) -> void:
	failed.emit(reason)
	push_warning("Save: %s" % reason)


func _key(slot: StringName) -> StringName:
	return StringName(KEY + String(slot))


func _key_of(node: Node) -> StringName:
	var key: Variant = node.get("save_key")
	if key is StringName and key != &"":
		return key
	push_error("Node '%s' is in the saveable group with no save_key." % node.name)
	return &""


## The callback has to be held: a JavaScriptObject that nothing references is
## collected, and the shell then calls a hole.
func _install_suspend_hook() -> void:
	if not OS.has_feature("web"):
		return
	_suspend_callback = JavaScriptBridge.create_callback(_on_suspend)
	var window := JavaScriptBridge.get_interface("window")
	window.set(SUSPEND_HOOK, _suspend_callback)


func _on_suspend(_args: Array) -> void:
	save_to(AUTO)
