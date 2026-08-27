class_name LampHum
extends AudioStreamPlayer3D

## A ballast hum, synthesised here rather than shipped as a file.
##
## Its only job in this build is to prove on the device that the tap gate really
## did unlock WebKit's audio: a phone has no way to tell "silent because muted"
## from "silent because the AudioContext never started". P3 replaces it with
## real sound design, and deleting this node is the whole removal.
##
## The buffer is an exact whole number of cycles, so the loop point is silent.

## Mains hum is twice line frequency: 120 Hz on this side of the Atlantic.
@export_range(40.0, 400.0, 1.0) var fundamental_hz: float = 120.0
## First harmonic. A pure sine reads as a test tone; a little 240 Hz on top
## reads as a fitting with a tired ballast.
@export_range(0.0, 1.0, 0.01) var harmonic_mix: float = 0.34
## Low on purpose. This is a 120 Hz tone and the buffer is a cost in the pack.
@export var mix_rate: int = 24000
## Cycles of the fundamental per loop. More cycles, longer buffer, no other gain.
@export_range(4, 240, 1) var loop_cycles: int = 24

const MAX_S16 := 32767.0
## Headroom in the buffer itself; loudness is `volume_db`, set in the scene.
const PEAK := 0.62


## Joined so the debug overlay can report on it without knowing what it is.
const PROBE_GROUP := &"audio_probe"


func _ready() -> void:
	add_to_group(PROBE_GROUP)
	stream = _build_stream()
	play()


func _build_stream() -> AudioStreamWAV:
	var frames := maxi(2, int(round(mix_rate * loop_cycles / fundamental_hz)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	# Data before the loop points: the loop range is validated against the
	# buffer that is there at the time, and setting it first silences the stream.
	wav.data = _render(frames)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames - 1
	return wav


## Phase is derived from the frame count rather than the frequency, so the
## buffer is periodic even when mix_rate is not a whole multiple of the tone.
func _render(frames: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(frames * 2)
	var amplitude := PEAK / (1.0 + harmonic_mix)
	for i in frames:
		var phase := TAU * float(i) * float(loop_cycles) / float(frames)
		var value := sin(phase) + harmonic_mix * sin(phase * 2.0)
		data.encode_s16(i * 2, int(clampf(value * amplitude, -1.0, 1.0) * MAX_S16))
	return data
