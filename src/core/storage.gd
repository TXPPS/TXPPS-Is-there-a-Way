class_name Storage
extends RefCounted

## Key/value persistence that survives an iOS tab eviction.
##
## On the web this is the GDScript side of window.__itaw_store (web/boot.js):
## IndexedDB for durability with a synchronous localStorage mirror, because
## synchronous is the only kind of write that reliably lands when the browser
## discards a backgrounded tab mid-transaction. Off the web it is one JSON file
## under user://, which is all a desktop editor session needs.
##
## Values are strings. Anything structured is JSON, encoded by the caller.

const FILE_PATH := "user://store.json"


static func read(key: StringName) -> String:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"window.__itaw_store ? (window.__itaw_store.read(%s) || '') : ''" % _js(key), true
		)
		return raw as String if raw is String else ""
	return str(_file().get(String(key), ""))


static func write(key: StringName, value: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__itaw_store && window.__itaw_store.write(%s, %s)" % [_js(key), _js(value)],
			true
		)
		return
	var data := _file()
	data[String(key)] = value
	_save(data)


static func erase(key: StringName) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__itaw_store && window.__itaw_store.erase(%s)" % _js(key), true
		)
		return
	var data := _file()
	data.erase(String(key))
	_save(data)


## "ok", "idb-only", "local-only", "degraded", "none", or "file" off the web.
static func health() -> String:
	if not OS.has_feature("web"):
		return "file"
	var raw: Variant = JavaScriptBridge.eval(
		"window.__itaw_store ? window.__itaw_store.health() : 'none'", true
	)
	return raw as String if raw is String else "none"


## A JavaScript string literal. JSON is a subset of JavaScript literal syntax,
## so this is the escape, not a hand-rolled one.
static func _js(value: Variant) -> String:
	return JSON.stringify(str(value))


static func _file() -> Dictionary:
	if not FileAccess.file_exists(FILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH))
	return parsed if parsed is Dictionary else {}


static func _save(data: Dictionary) -> void:
	var handle := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if handle == null:
		push_error("Storage: cannot write %s" % FILE_PATH)
		return
	handle.store_string(JSON.stringify(data))
