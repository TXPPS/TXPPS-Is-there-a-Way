class_name RunState
extends Node

## The one thing that is true of the whole game rather than of an act.
##
## Protocol 4.4: *a run is not concluded until the observer leaves the lamp.*
## Concluding it happens in the annex — you stand at the last lit schedule
## luminaire and let the seam close over you — and it is *read* in the control
## house, which is in another act's scene entirely.
##
## Act stashes cannot carry that. They are per-act by design, so that walking
## through a door does not teleport the player to wherever they last stood in
## that building, and this is a fact about the player rather than about a
## building. So it lives here: outside every act, saved with the game, and read
## by whichever act needs to know.
##
## There is exactly one flag in it, and there should stay that way. The moment
## this becomes a bag of globals it stops being explicable.

signal concluded

@export var save_key: StringName = &"run"

var _concluded := false


## Whether the observation has been performed. Once true, always true: it is
## something that happened to the player, not a state they are in.
func run_concluded() -> bool:
	return _concluded


func conclude() -> void:
	if _concluded:
		return
	_concluded = true
	concluded.emit()


func save_state() -> Dictionary:
	return {"concluded": _concluded}


func load_state(state: Dictionary) -> void:
	_concluded = bool(state.get("concluded", false))
