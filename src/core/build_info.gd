class_name BuildInfo
extends RefCounted

## Reads the per-build stamp that tools/ci/stamp_build.py writes just before
## export. Its only job is to let us confirm, on the phone, exactly which
## commit is live -- the single most useful thing to know when a deploy looks
## wrong. The stamp is absent during local editor runs; that is not an error.

const STAMP_PATH := "res://build_stamp.json"


static func describe() -> String:
	var stamp := _load()
	if stamp.is_empty():
		return "dev"
	var version := str(stamp.get("version", "?"))
	var commit := str(stamp.get("commit", "?")).substr(0, 7)
	return "v%s %s" % [version, commit]


static func built_at() -> String:
	return str(_load().get("built_at", ""))


static func _load() -> Dictionary:
	if not FileAccess.file_exists(STAMP_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAMP_PATH))
	if parsed is Dictionary:
		return parsed
	return {}
