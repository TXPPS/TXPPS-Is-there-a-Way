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

@export var watch: TouchWatch

@onready var _text: Label = $Text

var _env: Dictionary = {}
var _since_sample := 0.0
var _since_env := ENV_INTERVAL


func _ready() -> void:
	assert(watch != null, "DebugOverlay needs a TouchWatch assigned.")
	visible = false
	set_process(false)


func toggle() -> void:
	visible = not visible
	set_process(visible)
	if visible:
		_since_sample = SAMPLE_INTERVAL
		_since_env = ENV_INTERVAL
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
	_text.text = "\n".join(_lines(sample))
	_publish(sample)


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
	lines.append("store %s   sw %s" % [_env.get("store", "-"), _env.get("worker", "-")])
	lines.append("hum %s   %s" % [s["audio_source"], _peak_text(s["audio_db"])])
	lines.append("mixer gap %s ms   lat %s ms" % [s["audio_gap_ms"], s["audio_latency_ms"]])
	lines.append("update %s   pwa %s" % [_env.get("update", "-"), _env.get("standalone", "-")])
	return lines


func _touch_ids() -> String:
	if watch == null:
		return ""
	var parts := PackedStringArray()
	for index in watch.active_indices():
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
