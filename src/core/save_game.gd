class_name SaveGame
extends RefCounted

## The shape of a save, and the only thing that knows how to change that shape.
##
## Versioned from the first commit that had anything to save, because the
## alternative -- adding a version field later -- means the first migration has
## to guess what it is looking at. `migrate()` and its table exist now and are
## exercised by the suite, so the day a field moves there is a place to put the
## step and a test that already runs it.
##
## A save is small (hundreds of bytes), so it is stored as plain JSON and can be
## exported as a text code. Safari evicts storage for a site nobody has added to
## their home screen after about a week idle; a code the player can paste back
## is the only real answer to that.

## Bump this and add a step to MIGRATIONS in the same commit. Never one alone.
const VERSION := 3

const CODE_PREFIX := "ITAW"
const CODE_PARTS := 4
const CHECKSUM_LENGTH := 8

## Every version this build can migrate *from*. Version 0 means "no version
## field at all", which is what a hand-written or hand-edited code looks like
## and is reachable through import. Add the new number here and its arm to
## `_step()` in the same commit that bumps VERSION.
const MIGRATABLE_FROM: Array[int] = [0, 1, 2]


static func fresh() -> Dictionary:
	return {
		"version": VERSION,
		"saved_at": "",
		"build": BuildInfo.describe(),
		"play_seconds": 0.0,
		"checkpoint": "start",
		"act": 0,
		"acts": {},
		"nodes": {},
	}


## Anything that is a Dictionary carrying a `nodes` Dictionary is a candidate;
## whether it is *this* version is `migrate()`'s problem.
static func is_shaped_like_a_save(data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).get("nodes") is Dictionary


## Brings `data` up to VERSION, or returns an empty Dictionary if it cannot.
##
## A save from a *newer* build is refused rather than loaded: this build cannot
## know what a field it has never heard of means, and guessing corrupts the only
## copy the player has.
static func migrate(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var version := int(out.get("version", 0))
	if version > VERSION:
		push_warning("Save is from a newer build (v%d > v%d); refusing it." % [version, VERSION])
		return {}
	while version < VERSION:
		if not MIGRATABLE_FROM.has(version):
			push_warning("No migration from save version %d." % version)
			return {}
		out = _step(version, out)
		version = int(out.get("version", version + 1))
	return out


## One version forward. One arm per entry in MIGRATABLE_FROM, and no arm may
## reach for a field a later version introduced.
static func _step(version: int, data: Dictionary) -> Dictionary:
	match version:
		0:
			return _from_0(data)
		1:
			return _from_1(data)
		2:
			return _from_2(data)
	return data


## v0 -> v1. Pre-versioning data: nothing to move, everything to fill in.
static func _from_0(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	out["version"] = 1
	for key in ["saved_at", "build", "checkpoint"]:
		if not out.has(key):
			out[key] = ""
	if not out.has("play_seconds"):
		out["play_seconds"] = 0.0
	if not (out.get("nodes") is Dictionary):
		out["nodes"] = {}
	return out


## v1 -> v2. Acts arrived, and which one is mounted has to be known before any
## node state is applied -- so it sits in the header rather than in `nodes`.
## Every v1 save was made in the only act that existed.
static func _from_1(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	out["version"] = 2
	out["act"] = 0
	return out


## v2 -> v3. Acts became somewhere you can go *back* to, so a save carries what
## every act was like when the player last left it, not only the one they are
## standing in. A v2 save has been in exactly one act and its `nodes` already
## describe it, so there is nothing to move -- only somewhere to put it next
## time.
static func _from_2(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	out["version"] = 3
	out["acts"] = {}
	return out


## `ITAW.<raw size>.<sha8>.<base64 deflate>`.
##
## The size is there because Godot's decompressor needs it. The checksum is over
## the *base64*, not over what it decodes to, and deliberately so: a save code
## is going to be pasted out of a message app that wrapped it, and checking the
## payload before decompressing means damage is reported rather than handed to a
## decompressor that logs an engine error on its way to failing.
static func to_code(data: Dictionary) -> String:
	var raw := JSON.stringify(data).to_utf8_buffer()
	var payload := Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return ".".join([CODE_PREFIX, str(raw.size()), _checksum(payload), payload])


## The Dictionary a code carries, or empty if the code is not one.
static func from_code(code: String) -> Dictionary:
	var parts := code.strip_edges().split(".")
	if parts.size() != CODE_PARTS or parts[0] != CODE_PREFIX:
		return {}
	var size := int(parts[1])
	if size <= 0 or _checksum(parts[3]) != parts[2]:
		return {}
	var packed := Marshalls.base64_to_raw(parts[3])
	if packed.is_empty():
		return {}
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size:
		return {}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


static func _checksum(text: String) -> String:
	return text.sha256_text().substr(0, CHECKSUM_LENGTH)
