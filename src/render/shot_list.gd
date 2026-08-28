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

## Shots from this index on are taken with every lamp in the building lit.
## Act 1 starts dark and its first puzzle is the lighting, so both states are
## worth photographing and neither is "the game".
@export_range(0, 40, 1) var lit_from: int = 99

## Shots from this index on are taken in Act 2, which is mounted when the run
## reaches it. Two acts cannot be photographed at once for the same reason they
## cannot be played at once: only one is ever in the tree.
@export_range(0, 40, 1) var act2_from: int = 99

## And back again for Act 4, which is rooms in Act 1's building (D29).
@export_range(0, 40, 1) var act1_again_from: int = 99

## name, position, yaw degrees, pitch degrees.
## name, position (y is floor level; the eye is 1.62 above it), yaw and pitch in
## degrees, and optionally a Document to hold up. Computed from the room's own
## geometry rather than eyeballed: forward(yaw) is (-sin yaw, 0, -cos yaw),
## which is not the sign anyone guesses the first time.
##
## The document column is there because a page is art too, and a page nobody has
## looked at is a page whose line breaks are wrong.
const SHOTS: Array = [
	# What the player is actually looking at when the game starts.
	["00-first-frame", Vector3(-6.00, 0.00, -2.50), 0.0, 0.0],
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
	["11-lit-hall", Vector3(6.00, 0.00, 0.00), 80.7, 2.4],
	["12-lit-panel", Vector3(-6.00, 0.00, -3.00), 0.0, -12.0],
	["13-lit-switchgear", Vector3(-9.60, 0.00, -2.00), 90.0, -4.0],
	# Act 2. Everything from here is in the shelter, lit, because the shelter's
	# lighting is a load the player chose to keep -- the dark version of these
	# rooms is a decision, not a starting state.
	["14-shelter-corridor", Vector3(0.00, 0.00, 8.00), 0.0, -2.0],
	["15-plant-room", Vector3(-5.00, 0.00, -2.20), 19.3, -8.0],
	["16-panel-dp2", Vector3(-0.30, 0.00, -6.50), -90.0, -6.0],
	["17-mess", Vector3(-3.20, 0.00, 6.80), 27.4, -9.0],
	["18-bunks", Vector3(2.40, 0.00, 5.00), -90.0, -6.0],
	["19-store", Vector3(2.20, 0.00, -1.70), 0.0, -12.0],
	["20-stair-head", Vector3(0.00, 0.00, -9.00), 0.0, -22.0],
	["21-page-service-card", Vector3(-5.00, 0.00, -2.20), 19.3, 0.0,
		"res://assets/documents/d09_generator_card.tres"],
	# The annex. Same building, and it should not look like it.
	["22-annex-corridor", Vector3(-7.00, 0.00, -16.05), -90.0, -2.0],
	["23-observer-station", Vector3(0.00, 0.00, -15.30), 0.0, -4.0],
	["24-chamber-b", Vector3(0.00, 0.00, -18.30), 0.0, -6.0],
	["25-tank-room", Vector3(-10.10, 0.00, -14.30), 118.0, -9.0],
	["26-recorder-bay", Vector3(10.10, 0.00, -16.60), -20.0, -12.0],
	["27-tape-library", Vector3(-11.90, 0.00, -19.60), -180.0, -6.0],
	["28-page-protocol", Vector3(0.00, 0.00, -15.30), 0.0, 0.0,
		"res://assets/documents/d13_protocol_4.tres"],
	# Act 4, back in Act 1's building and up the pier stair.
	["29-relay-panel", Vector3(9.20, -3.90, 13.60), -90.0, -6.0],
	["30-bench-unit", Vector3(9.40, -3.90, 15.00), -78.0, -8.0],
	["31-pier-stair", Vector3(13.30, -3.90, 15.60), 0.0, 22.0],
	["32-gate-pier", Vector3(16.70, 0.60, 13.60), 0.0, -4.0],
	["33-control-house", Vector3(16.70, 0.60, 18.40), 180.0, -3.0],
	["34-page-tape", Vector3(16.70, 0.60, 18.40), 180.0, 0.0,
		"res://assets/documents/d24_reel_9c.tres"],
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
	_mount_for(_index)
	_player.global_position = shot[1]
	_player.velocity = Vector3.ZERO
	_player.face(deg_to_rad(shot[2]), deg_to_rad(shot[3]))
	for node in get_tree().get_nodes_in_group(&"bulkhead_lamp"):
		(node as BulkheadLamp).lit = _index >= lit_from
	if shot.size() > 4 and _reader != null:
		_reader.show_document(load(String(shot[4])) as Document)
	elif _reader != null:
		_reader.close()
	_settle = SETTLE_FRAMES
	_publish(false)


## Swaps to the act this shot belongs to, if it is not already up. Called on
## every shot rather than once at the boundary so that a run started part-way
## through -- which is what a re-capture of one shot is -- still lands in the
## right building.
func _mount_for(index: int) -> void:
	var runner := get_tree().get_first_node_in_group(&"act_runner") as ActRunner
	if runner == null:
		return
	var want := 0
	if index >= act2_from:
		want = 1
	if index >= act1_again_from:
		want = 0
	if runner.current() != want:
		runner.load_act(want)


func _publish(ready: bool) -> void:
	var name := "" if _index < 0 or _index >= SHOTS.size() else String(SHOTS[_index][0])
	JavaScriptBridge.eval(PUBLISH_CALL + JSON.stringify({
		"index": _index,
		"name": name,
		"ready": ready,
		"done": _index >= SHOTS.size(),
		"total": SHOTS.size(),
		# What this frame cost. The shot run already stands in every space in
		# the game, so it is the only thing that visits all of them with a real
		# renderer behind it -- and `docs/BUDGETS.md`'s draw-call cap was being
		# asserted in exactly one room of four acts until it reported these.
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}), true)
