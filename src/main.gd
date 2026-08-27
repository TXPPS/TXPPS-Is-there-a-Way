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
@onready var _state: GameState = $State
@onready var _saves: SaveService = $Saves
@onready var _fear: FearState = $Fear
@onready var _post: PostStack = $PostStack
@onready var _shots: ShotList = $Shots
@onready var _score: AudioDirector = $Score
@onready var _reader: Reader = $Reader
@onready var _journal: Journal = $Journal
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _interactor: Interactor = $Player/Head/Camera/Interactor

## Whatever the player is engaged with, or null. The only thing gestures go to
## while GameState says FOCUSED.
var _engaged: Interactable


func _ready() -> void:
	_hud.look_requested.connect(_player.add_look)
	_hud.pause_requested.connect(_menu.open)
	_menu.bind(_settings, _hud.tuning, _saves)
	_saves.failed.connect(Notify.problem)
	_menu.opened.connect(_on_paused)
	_menu.closed.connect(_on_resumed)
	_settings.changed.connect(_player.on_setting)
	_settings.changed.connect(_hud.on_setting)
	_settings.changed.connect(_on_setting)
	_settings.changed.connect(_post.on_setting)
	_settings.changed.connect(_reader.on_setting)
	_fear.changed.connect(_post.set_fear)
	_fear.changed.connect(_score.set_fear)
	_hud.action_pressed.connect(_on_action)
	_hud.puzzle_pressed.connect(_on_puzzle_pressed)
	_hud.puzzle_dragged.connect(_on_puzzle_dragged)
	_hud.puzzle_lifted.connect(_on_puzzle_lifted)
	_interactor.occluded = _hud.blocks_world_point
	_interactor.target_changed.connect(_on_target_changed)
	if is_instance_valid(_shots):
		_shots.bind(_player, _hud, _reader)
	_wire_readables()
	_settings.apply_all()
	_state.enter(GameState.State.FREE)
	print("Is There a Way? — build %s" % BuildInfo.describe())


func _physics_process(_delta: float) -> void:
	if not _state.accepts_world_input():
		_player.set_move_intent(Vector2.ZERO)
		_player.set_look_intent(Vector2.ZERO)
		return
	_player.set_move_intent(_hud.get_move_intent())
	_player.set_look_intent(_hud.get_look_intent())
	_fear.set_in_light(_standing_in_light())


func _on_setting(key: StringName, value: float) -> void:
	match key:
		&"volume_master": AudioBuses.set_volume(AudioBuses.MASTER, value)
		&"volume_sfx": AudioBuses.set_volume(AudioBuses.SFX, value)
		&"volume_music": AudioBuses.set_volume(AudioBuses.MUSIC, value)
		&"volume_voice": AudioBuses.set_volume(AudioBuses.VOICE, value)


## Every touch is dropped before the tree stops delivering input, so no stick is
## still deflected by a thumb whose release nothing will hear.
func _on_paused() -> void:
	_hud.release_touches()
	_hud.set_input_enabled(false)
	_state.open_menu()


func _on_resumed() -> void:
	_hud.set_input_enabled(true)
	_state.close_menu()


## Every page in the level, wired here rather than each one finding the reader
## for itself. A Readable that had to locate a service would be a Readable that
## works differently in a test scene, and the whole point of the group is that
## adding a page to a room is adding a node.
func _wire_readables() -> void:
	for node in get_tree().get_nodes_in_group(&"readable"):
		var page := node as Readable
		if page == null:
			continue
		page.opened.connect(_reader.show_document)
		page.opened.connect(_journal.mark_read)
		page.closed.connect(_reader.close)
		page.scrolled.connect(_reader.scroll_by)


## Whether the player is inside the useful reach of any lit practical. The
## fraction is not 1.0 because the edge of a sodium lamp's range is not light --
## it is where the falloff has already gone to nothing.
const LIT_FRACTION := 0.62


func _standing_in_light() -> bool:
	for node in get_tree().get_nodes_in_group(&"practical"):
		var lamp := node as OmniLight3D
		if lamp == null or not lamp.visible or lamp.light_energy <= 0.0:
			continue
		if lamp.global_position.distance_to(_player.global_position) <= lamp.omni_range * LIT_FRACTION:
			return true
	return false


func _on_target_changed(target: Interactable) -> void:
	if _engaged == null:
		_hud.show_target(target.prompt if target != null else "")


## One button, two jobs: engage with what is in front of you, or step back from
## what you are already holding. There is never a moment when both are offered.
func _on_action() -> void:
	if _engaged != null:
		_release()
		return
	var target := _interactor.target()
	if target == null or not _state.enter(GameState.State.FOCUSED):
		return
	_engaged = target
	_interactor.set_scanning(false)
	_hud.set_focused(true)
	_hud.show_target(target.release_prompt)
	target.engage()


func _release() -> void:
	var was := _engaged
	_engaged = null
	_hud.set_focused(false)
	_hud.show_target("")
	was.disengage()
	_state.enter(GameState.State.FREE)
	_interactor.set_scanning(true)


func _on_puzzle_pressed(screen: Vector2) -> void:
	if _engaged != null:
		_engaged.push_press(screen)


func _on_puzzle_dragged(screen: Vector2, delta: Vector2) -> void:
	if _engaged != null:
		_engaged.push_drag(screen, delta)


func _on_puzzle_lifted() -> void:
	if _engaged != null:
		_engaged.push_lift()
