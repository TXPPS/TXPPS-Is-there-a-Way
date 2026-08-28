class_name PostStack
extends CanvasLayer

## The fullscreen post pass, and the only thing that talks to post.gdshader.
##
## Sits on layer 0: above the 3D scene, below the HUD. Grading and graining the
## interface would make small text harder to read on a phone in daylight, which
## is the real viewing condition and the one the HUD is built for.
##
## Everything it sets comes from three places and nowhere else: RenderTuning for
## the authored values, GameSettings for the player's, and FearState for the
## one number that breathes.

## Each act's grade, by name. The palette shift from sodium to fluorescent is
## the marker that the player has left the *dam* and entered the *programme*
## (`ART_BIBLE.md`, "Palette"), so which one is loaded is a property of the act
## rather than a setting.
const LUT_DIR := "res://assets/luts/"
const DEFAULT_GRADE := &"act1"

@export var tuning: RenderTuning

@onready var _screen: ColorRect = $Screen

var _material: ShaderMaterial
var _grade := &""
var _fear := 0.0
var _reduce_motion := false
var _brightness := 1.0


func _ready() -> void:
	assert(tuning != null, "PostStack needs a RenderTuning resource assigned.")
	_material = _screen.material as ShaderMaterial
	assert(_material != null, "PostStack's ColorRect needs the post shader.")
	set_grade(DEFAULT_GRADE)
	_apply()


## Loads an act's grade. Named rather than passed as a Texture so that a level
## can say which colour it is in one word in its own scene file, and so that a
## name nobody wrote a LUT for fails loudly here rather than washing the whole
## act out to nothing.
func set_grade(name: StringName) -> void:
	if name == _grade:
		return
	var path := "%s%s.png" % [LUT_DIR, name]
	if not ResourceLoader.exists(path):
		# A warning rather than an error, and deliberately: a grade name comes
		# from a level's own metadata, so a wrong one is a content mistake, and
		# the game survives it by keeping the last good grade. What makes it
		# hard to ship is `case_render`, which checks every act's declared grade
		# exists -- a build-time guarantee beats a runtime scream.
		push_warning("No grade named '%s'; keeping '%s'." % [name, _grade])
		return
	_grade = name
	_material.set_shader_parameter("grade_lut", load(path))


func grade() -> StringName:
	return _grade


## 0..1. Drives grain amount and how far the grain stretches.
func set_fear(value: float) -> void:
	_fear = clampf(value, 0.0, 1.0)
	_apply()


func on_setting(key: StringName, value: float) -> void:
	match key:
		&"brightness":
			_brightness = value
		&"reduce_motion":
			_reduce_motion = value >= 0.5
		_:
			return
	_apply()


## What the stack is currently doing, for the debug overlay and the suite. The
## only way to see a shader parameter from outside a GPU.
func probe() -> Dictionary:
	return {
		"fear": _fear,
		"grain": _material.get_shader_parameter("grain_amount"),
		"aniso": _material.get_shader_parameter("grain_anisotropy"),
		"barrel": _material.get_shader_parameter("barrel_amount"),
		"exposure": _material.get_shader_parameter("exposure"),
		"dither": _material.get_shader_parameter("dither_amount"),
		"grade": String(_grade),
	}


## `reduce motion` takes the lens off entirely and softens the grain, per
## ART_BIBLE.md. It does not touch the dither: that is legibility, not motion.
func _apply() -> void:
	if _material == null:
		return
	var lens := 0.0 if _reduce_motion else 1.0
	var grain := lerpf(tuning.grain_calm, tuning.grain_afraid, _fear)
	if _reduce_motion:
		grain *= tuning.grain_reduced
	_material.set_shader_parameter("barrel_amount", tuning.barrel * lens)
	_material.set_shader_parameter("chroma_amount", tuning.chroma * lens)
	_material.set_shader_parameter("bloom_threshold", tuning.bloom_threshold)
	_material.set_shader_parameter("bloom_strength", tuning.bloom_strength)
	_material.set_shader_parameter("bloom_tint", tuning.bloom_tint)
	_material.set_shader_parameter("lut_amount", tuning.lut_amount)
	_material.set_shader_parameter("exposure", _brightness)
	_material.set_shader_parameter("grain_amount", grain)
	_material.set_shader_parameter("grain_anisotropy",
		lerpf(tuning.anisotropy_calm, tuning.anisotropy_afraid, _fear if not _reduce_motion else 0.0))
	_material.set_shader_parameter("grain_speed", tuning.grain_speed)
	_material.set_shader_parameter("dither_amount", tuning.dither)
	_material.set_shader_parameter("dither_ceiling", tuning.dither_ceiling)
	_material.set_shader_parameter("vignette_amount", tuning.vignette)
