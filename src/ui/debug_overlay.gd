class_name DebugOverlay
extends PanelContainer

## The only instrumentation that exists on a phone: no console, no devtools, no
## remote profiler. Summoned by a three-finger tap so it cannot open by accident,
## and closed the same way.
##
## Half the numbers come from Godot's Performance monitors and half from the HTML
## shell (window.__itaw_env in web/boot.js), because DPR, safe-area insets and
## storage health are things only the page can see. Off the web the shell half
## is blank, which is correct rather than broken.
##
## While it is open it also publishes the same sample to window.__itaw_probe, so
## the headless suite can assert the frame budget and prove that audio is being
## mixed -- neither of which is legible from a screenshot.

const ENV_CALL := "window.__itaw_env ? window.__itaw_env() : ''"
const PUBLISH_CALL := "window.__itaw_probe = "
## Cheap values, refreshed often enough to watch a spike happen.
const SAMPLE_INTERVAL := 0.25
## Values that cross the JavaScript bridge, refreshed rarely because they cost.
const ENV_INTERVAL := 2.0
const MS_PER_S := 1000.0
## Godot's floor for an idle bus. On the web build the peak monitor never leaves
## it, so showing "-200 dB" on a phone would read as a fault that is not there.
const PEAK_FLOOR := -199.0

@onready var _left: Label = $Columns/Left
@onready var _right: Label = $Columns/Right

var _watch: TouchWatch
var _hud: Hud
var _rects: HudRects
var _env: Dictionary = {}
var _since_sample := 0.0
var _since_env := ENV_INTERVAL
var _checked := false


func _ready() -> void:
	visible = false
	set_process(false)


## Wired by Hud, which owns all three. Exporting NodePaths for them would put
## the scene tree's shape into the inspector, where a rearrangement breaks it
## silently.
func bind(watch: TouchWatch, hud: Hud, rects: HudRects) -> void:
	_watch = watch
	_hud = hud
	_rects = rects


func toggle() -> void:
	visible = not visible
	set_process(visible)
	if visible:
		_since_sample = SAMPLE_INTERVAL
		_since_env = ENV_INTERVAL
		_checked = false
		return
	_publish({"visible": false})


func _process(delta: float) -> void:
	_since_env += delta
	if _since_env >= ENV_INTERVAL:
		_since_env = 0.0
		_env = _read_env()
	_since_sample += delta
	if _since_sample < SAMPLE_INTERVAL:
		return
	_since_sample = 0.0
	var sample := _sample()
	_fill(_lines(sample))
	_publish(sample)
	_check_placement()


## The overlay is the largest thing on this HUD, so it is the one most likely to
## grow into a thumb. Checked once per opening, and after a sample rather than
## on the toggle: before the first layout pass the panel has not been given the
## size its content needs, and an empty box clears everything.
func _check_placement() -> void:
	if _checked or _rects == null:
		return
	_checked = true
	_rects.require_clear(&"debug_overlay", get_global_rect())


## Split down the middle, left column first.
func _fill(lines: PackedStringArray) -> void:
	var half := int(ceil(float(lines.size()) * 0.5))
	_left.text = "\n".join(lines.slice(0, half))
	_right.text = "\n".join(lines.slice(half))


func _sample() -> Dictionary:
	var view := get_viewport().get_visible_rect().size
	var window := Vector2(get_window().size)
	return {
		"visible": true,
		"build": BuildInfo.describe(),
		"fps": Engine.get_frames_per_second(),
		"cpu_ms": _cpu_ms(),
		"draw_calls": int(_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tris": int(_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"view": "%dx%d" % [int(view.x), int(view.y)],
		"window": "%dx%d" % [int(window.x), int(window.y)],
		"touches": _touch_ids(),
		"audio_db": _peak_db(),
		"audio_latency_ms": int(AudioServer.get_output_latency() * MS_PER_S),
		"audio_gap_ms": int(AudioServer.get_time_since_last_mix() * MS_PER_S),
		"audio_source": _source_state(),
		"listener": get_viewport().is_audio_listener_3d(),
		"shell": _env,
		"hud": _hud.probe() if _hud != null else {},
		"overlay": _own_rect(),
	}


func _lines(s: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("pack  %s" % s["build"])
	lines.append("shell %s" % _env.get("build", "-"))
	lines.append("fps %d   cpu %.1f ms" % [s["fps"], s["cpu_ms"]])
	lines.append("draw %d   tris %s" % [s["draw_calls"], _thousands(s["tris"])])
	lines.append("view %s   win %s" % [s["view"], s["window"]])
	lines.append("css %s x %s   dpr %s" % [_env.get("css_w", "-"), _env.get("css_h", "-"), _env.get("dpr", "-")])
	lines.append("safe %s" % _env.get("safe", "-"))
	lines.append("touch %s" % ("none" if (s["touches"] as String).is_empty() else s["touches"]))
	lines.append("owned %s" % _claims(s))
	lines.append("stick %s" % _sticks(s))
	lines.append("store %s   persist %s   sw %s"
		% [_env.get("store", "-"), _env.get("persist", "-"), _env.get("worker", "-")])
	lines.append("hum %s   %s" % [s["audio_source"], _peak_text(s["audio_db"])])
	lines.append("mixer gap %s ms   lat %s ms" % [s["audio_gap_ms"], s["audio_latency_ms"]])
	lines.append("update %s   pwa %s" % [_env.get("update", "-"), _env.get("standalone", "-")])
	return lines


## Which control holds which finger. The single most useful line on this overlay
## while the control scheme is being tuned.
func _claims(s: Dictionary) -> String:
	var hud: Dictionary = s.get("hud", {})
	var claims: Dictionary = hud.get("claims", {})
	if claims.is_empty():
		return "none  (%s)" % hud.get("style", "-")
	var parts := PackedStringArray()
	for id in claims:
		parts.append("%s=%s" % [id, claims[id]])
	return "%s  (%s)" % [" ".join(parts), hud.get("style", "-")]


func _sticks(s: Dictionary) -> String:
	var hud: Dictionary = s.get("hud", {})
	var move: Array = hud.get("move", [0.0, 0.0])
	var look: Array = hud.get("look", [0.0, 0.0])
	return "move %+.2f,%+.2f   look %+.2f,%+.2f" % [move[0], move[1], look[0], look[1]]


## Where the overlay itself is, so the browser suite can prove it does not sit
## on top of the build stamp the HTML shell draws in the same corner.
func _own_rect() -> Array:
	var r := get_global_rect()
	return [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]


func _touch_ids() -> String:
	if _watch == null:
		return ""
	var parts := PackedStringArray()
	for index in _watch.active_indices():
		parts.append(str(index))
	return ",".join(parts)


## Whatever the scene nominated as an audible reference, and where its playback
## head has got to.
##
## A position that advances is the proof that audio is running. The bus peak next
## to it is the more obvious measure and is reported too, but Godot's web build
## leaves it at its -200 dB floor whatever is playing, so it means nothing here
## and everything on desktop.
func _source_state() -> String:
	var node := get_tree().get_first_node_in_group(&"audio_probe") as AudioStreamPlayer3D
	if node == null:
		return "none"
	return "%s %.2fs" % ["on" if node.is_playing() else "off", node.get_playback_position()]


## Peak on the master bus. A number that moves is direct proof that audio is
## being mixed, which is the one thing a silent phone cannot tell you.
func _peak_db() -> float:
	return AudioServer.get_bus_peak_volume_left_db(0, 0)


func _peak_text(db: float) -> String:
	if db <= PEAK_FLOOR:
		return "peak n/a"
	return "peak %.1f dB" % db


func _cpu_ms() -> float:
	var seconds := _monitor(Performance.TIME_PROCESS) + _monitor(Performance.TIME_PHYSICS_PROCESS)
	return seconds * MS_PER_S


func _monitor(id: Performance.Monitor) -> float:
	return Performance.get_monitor(id)


func _thousands(value: int) -> String:
	if value < 1000:
		return str(value)
	return "%.1fk" % (float(value) / 1000.0)


func _read_env() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw: Variant = JavaScriptBridge.eval(ENV_CALL, true)
	if not (raw is String) or (raw as String).is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw as String)
	return parsed if parsed is Dictionary else {}


## JSON is a subset of JavaScript literals, so this needs no escaping of its own.
func _publish(sample: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(PUBLISH_CALL + JSON.stringify(sample), true)
