class_name GameSettings
extends Node

## Every player preference, and the only thing that reads or writes them.
##
## The menu is generated from `spec`, so adding a preference is one row in the
## resource plus one `match` arm wherever it applies. There is no screen to edit
## and therefore no way to ship a setting that saves but is never shown, or is
## shown but never saved.
##
## Writes persist immediately -- there is no Apply button and no save on exit,
## because a phone does not reliably get an exit. Every change also emits
## `changed`, and every consumer applies it live: nothing here needs a restart.

signal changed(key: StringName, value: float)

const STORE_KEY := &"settings.v1"

@export var spec: SettingsSpec

var _values: Dictionary[StringName, float] = {}


func _ready() -> void:
	assert(spec != null, "GameSettings needs a SettingsSpec assigned.")
	_load()


func value(key: StringName) -> float:
	return _values.get(key, _default(key))


func flag(key: StringName) -> bool:
	return value(key) >= 0.5


func choice(key: StringName) -> int:
	return int(round(value(key)))


## Clamps to the row's own rules, stores, announces, persists. Unknown keys are
## refused loudly rather than written to a file nothing will ever read back.
func set_value(key: StringName, raw: float) -> void:
	var row := spec.find(key)
	if row == null:
		push_error("GameSettings: no such setting '%s'" % key)
		return
	var next := row.clamp_value(raw)
	if is_equal_approx(_values.get(key, NAN), next):
		return
	_values[key] = next
	changed.emit(key, next)
	_save()


func reset(key: StringName) -> void:
	set_value(key, _default(key))


func reset_all() -> void:
	for row in spec.rows:
		if row != null:
			set_value(row.key, row.default_value)


## Re-announces every setting. Called once after wiring, so consumers apply the
## stored values through exactly the same path a live change takes.
func apply_all() -> void:
	for row in spec.rows:
		if row != null:
			changed.emit(row.key, value(row.key))


func _default(key: StringName) -> float:
	var row := spec.find(key)
	return row.default_value if row != null else 0.0


## Unknown keys in stored data are dropped, not migrated: a key that no longer
## exists in the spec is a setting that no longer exists.
##
## A first run writes the defaults straight back out, so the store always holds
## the whole set. That makes what the player is playing with inspectable, and it
## means a later change to a default cannot quietly move the ground under
## someone who has already dialled the game in around it.
func _load() -> void:
	var text := Storage.read(STORE_KEY)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var stored: Dictionary = parsed if parsed is Dictionary else {}
	for row in spec.rows:
		if row == null:
			continue
		var raw: Variant = stored.get(String(row.key), row.default_value)
		_values[row.key] = row.clamp_value(float(raw) if raw is float or raw is int else row.default_value)
	if stored.size() != _values.size():
		_save()


func _save() -> void:
	var out: Dictionary = {}
	for key in _values:
		out[String(key)] = _values[key]
	Storage.write(STORE_KEY, JSON.stringify(out))
