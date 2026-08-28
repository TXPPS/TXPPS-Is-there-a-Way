class_name ShotList
extends Node

## Reference photography, for a project with no desktop editor session.
##
## Art cannot be reviewed from a test that walks the player around: two runs
## point the camera at different walls and the two screenshots are not
## comparable, so nothing can be said about a change. This walks a fixed list of
## poses and holds each one still until it is photographed, which is what makes
## `docs/shots/` a gallery rather than a pile.
##
## It exists only when the page is opened with `?shots=1`, and frees itself
## otherwise, so it costs the shipped game one branch at startup. Driven by
## `tools/web/capture_shots.js`.
##
## The poses live here rather than in a Resource on purpose: they are a tool's
## working set, not gameplay feel, and a reviewer wants to read the list and the
## code that walks it in one place.

const FLAG_CALL := "location.search.indexOf('shots=1') >= 0"
const PUBLISH_CALL := "window.__itaw_shot = "
const ADVANCE_HOOK := "__itaw_shotNext"
## Frames to let a pose settle before it is called ready. Lighting and the
## post stack are stable within a couple; this is generous on purpose.
const SETTLE_FRAMES := 8

## name, position, yaw degrees, pitch degrees.
## name, position (y is floor level; the eye is 1.62 above it), yaw and pitch in
## degrees, and optionally a Document to hold up. Computed from the room's own
## geometry rather than eyeballed: forward(yaw) is (-sin yaw, 0, -cos yaw),
## which is not the sign anyone guesses the first time.
##
## The document column is there because a page is art too, and a page nobody has
## looked at is a page whose line breaks are wrong.
const SHOTS: Array = [
	["01-hall-west", Vector3(6.00, 0.00, 0.00), 80.7, 2.4],
	["02-lamp-close", Vector3(-5.40, 0.00, -2.50), 90.0, 34.1],
	["03-across-the-dark", Vector3(-6.00, 0.00, 4.00), -59.3, -1.5],
	["04-generator-set", Vector3(0.00, 0.00, 2.60), -30.8, -6.7],
	["05-switchgear-door", Vector3(-5.60, 0.00, -2.00), 90.0, -11.3],
	["06-office-desk", Vector3(-9.60, 0.00, 3.20), 68.2, -17.3],
	["07-stair-head", Vector3(9.90, 0.00, 0.60), -180.0, -38.1],
	["08-gallery", Vector3(9.90, -3.90, 12.00), -180.0, -1.2],
	["09-page-typed", Vector3(-6.60, 0.00, -4.00), 90.0, 0.0,
		"res://assets/documents/d04_sequence_card.tres"],
	["10-page-pencil", Vector3(-6.60, 0.00, -4.00), 90.0, 0.0,
		"res://assets/documents/d03_emil_log.tres"],
]

var _player: Player
var _hud: CanvasLayer
var _reader: Reader
var _index := -1
var _settle := 0
var _advance: JavaScriptObject


func bind(player: Player, hud: CanvasLayer, reader: Reader) -> void:
	_player = player
	_hud = hud
	_reader = reader


func _ready() -> void:
	if not _wanted():
		queue_free()
		return
	_advance = JavaScriptBridge.create_callback(_on_advance)
	JavaScriptBridge.get_interface("window").set(ADVANCE_HOOK, _advance)
	set_process(true)


func _wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	var raw: Variant = JavaScriptBridge.eval(FLAG_CALL, true)
	return bool(raw)


func _process(_delta: float) -> void:
	if _player == null:
		return
	if _index < 0:
		_hud.visible = false
		_next()
		return
	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_publish(true)


func _on_advance(_args: Array) -> void:
	_next()


func _next() -> void:
	_index += 1
	if _index >= SHOTS.size():
		_publish(false)
		set_process(false)
		return
	var shot: Array = SHOTS[_index]
	_player.global_position = shot[1]
	_player.velocity = Vector3.ZERO
	_player.face(deg_to_rad(shot[2]), deg_to_rad(shot[3]))
	if shot.size() > 4 and _reader != null:
		_reader.show_document(load(String(shot[4])) as Document)
	elif _reader != null:
		_reader.close()
	_settle = SETTLE_FRAMES
	_publish(false)


func _publish(ready: bool) -> void:
	var name := "" if _index < 0 or _index >= SHOTS.size() else String(SHOTS[_index][0])
	JavaScriptBridge.eval(PUBLISH_CALL + JSON.stringify({
		"index": _index,
		"name": name,
		"ready": ready,
		"done": _index >= SHOTS.size(),
		"total": SHOTS.size(),
	}), true)
