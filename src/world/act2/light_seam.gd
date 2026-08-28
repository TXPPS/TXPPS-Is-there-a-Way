class_name LightSeam
extends Node3D

## The entity's motif, shown once.
##
## `ART_BIBLE.md` fixes the signature as **a vertical seam of light that should
## not be there**, and `STORY.md` puts the first one at the very end of Act 2,
## in a corridor the player has already walked. No sound. No consequence.
##
## It is deliberately not a scare and deliberately not a system. There is no
## entity to run, no AI, nothing to fight: a line of light appears on a wall
## where there is no gap, stays for a breath, and goes. A player who is not
## looking that way misses it entirely, and that is allowed. Making it
## unmissable would make it a jump scare, which `ART_BIBLE.md` rules out.

## How long the whole thing lasts, in and out.
@export_range(0.4, 8.0, 0.1) var seconds: float = 2.6

## Peak emission. Low: it is a seam of light, not a lamp.
@export var brightness: float = 1.4

## Size of the seam, in metres. Tall and very narrow -- the width of a join.
@export var size: Vector2 = Vector2(0.03, 1.9)

var _shown := false
var _elapsed := 0.0
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_build()
	set_process(false)
	visible = false


## Once, ever. A second showing would make it a mechanic, and it is not one.
func show_once() -> void:
	if _shown:
		return
	_shown = true
	_elapsed = 0.0
	visible = true
	set_process(true)


func was_shown() -> bool:
	return _shown


func save_state() -> Dictionary:
	return {"shown": _shown}


func load_state(state: Dictionary) -> void:
	_shown = bool(state.get("shown", _shown))
	if _shown:
		visible = false
		set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	var through := _elapsed / maxf(seconds, 0.01)
	if through >= 1.0:
		visible = false
		set_process(false)
		return
	# In quickly, out slowly. A light that fades up as gently as it fades down
	# reads as a dimmer being turned, which is a person; this reads as something
	# passing in front of a gap.
	var curve := sin(PI * pow(through, 0.7))
	_material.emission_energy_multiplier = brightness * curve


func _build() -> void:
	var quad := QuadMesh.new()
	quad.size = size

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0, 0.72, 0.44)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.72, 0.44)
	_material.emission_energy_multiplier = 0.0
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.disable_receive_shadows = true

	_mesh = MeshInstance3D.new()
	_mesh.name = "Seam"
	_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
