extends Node3D

## Composition root for the gray-box build. Wiring lives here, in one greppable
## place, rather than being buried in whichever node happened to need it.

@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_hud.look_requested.connect(_player.add_look)
	print("Is There a Way? — build %s" % BuildInfo.describe())


func _physics_process(_delta: float) -> void:
	_player.set_move_intent(_hud.get_move_intent())
