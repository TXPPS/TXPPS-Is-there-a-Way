extends Node3D

## Composition root for the gray-box build. Wiring lives here, in one greppable
## place, rather than being buried in whichever node happened to need it.
##
## Settings are announced from one signal and each system takes the keys it owns
## and ignores the rest, so adding a preference never means finding the one
## switchboard that has to learn about it.

@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud
@onready var _menu: PauseMenu = $PauseMenu
@onready var _settings: GameSettings = $Settings
@onready var _world: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_hud.look_requested.connect(_player.add_look)
	_hud.pause_requested.connect(_menu.open)
	_menu.bind(_settings, _hud.tuning)
	_menu.opened.connect(_on_paused)
	_menu.closed.connect(_on_resumed)
	_settings.changed.connect(_player.on_setting)
	_settings.changed.connect(_hud.on_setting)
	_settings.changed.connect(_on_setting)
	_settings.apply_all()
	print("Is There a Way? — build %s" % BuildInfo.describe())


func _physics_process(_delta: float) -> void:
	_player.set_move_intent(_hud.get_move_intent())
	_player.set_look_intent(_hud.get_look_intent())


func _on_setting(key: StringName, value: float) -> void:
	match key:
		&"volume_master": AudioBuses.set_volume(AudioBuses.MASTER, value)
		&"volume_sfx": AudioBuses.set_volume(AudioBuses.SFX, value)
		&"volume_music": AudioBuses.set_volume(AudioBuses.MUSIC, value)
		&"volume_voice": AudioBuses.set_volume(AudioBuses.VOICE, value)
		&"brightness": _world.environment.tonemap_exposure = value


## Every touch is dropped before the tree stops delivering input, so no stick is
## still deflected by a thumb whose release nothing will hear.
func _on_paused() -> void:
	_hud.release_touches()
	_hud.set_input_enabled(false)


func _on_resumed() -> void:
	_hud.set_input_enabled(true)
