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

## Makes every write fail, so the "this browser will not keep a save" path can
## be exercised rather than reasoned about. Nothing in the game sets it; the
## suite does, and a real browser that refuses storage produces the same
## behaviour without it.
static var simulate_unavailable := false


static func read(key: StringName) -> String:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"window.__itaw_store ? (window.__itaw_store.read(%s) || '') : ''" % _js(key), true
		)
		return raw as String if raw is String else ""
	return str(_file().get(String(key), ""))


static func write(key: StringName, value: String) -> void:
	if simulate_unavailable:
		return
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


## Every key currently held, so a save browser does not have to guess.
static func keys() -> PackedStringArray:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"window.__itaw_store ? window.__itaw_store.keys() : ''", true
		)
		var text := raw as String if raw is String else ""
		return PackedStringArray() if text.is_empty() else text.split(",")
	var out := PackedStringArray()
	for key in _file():
		out.append(str(key))
	return out


## Whether the browser has promised not to evict this origin: "yes", "no",
## "unsupported" or "unknown". Safari grants it to installed sites and to sites
## visited often, and evicts everything else after about a week idle -- which is
## why a save can be exported as text.
static func persistence() -> String:
	if not OS.has_feature("web"):
		return "yes"
	var raw: Variant = JavaScriptBridge.eval(
		"window.__itaw_store ? window.__itaw_store.persisted() : 'unknown'", true
	)
	return raw as String if raw is String else "unknown"


## True when a write has somewhere durable to land. False means the session is
## running out of memory only: playable, but nothing will survive a reload.
static func is_durable() -> bool:
	return health() in ["ok", "idb-only", "local-only", "file"]


## "ok", "idb-only", "local-only", "degraded", "none", or "file" off the web.
static func health() -> String:
	if simulate_unavailable:
		return "none"
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
