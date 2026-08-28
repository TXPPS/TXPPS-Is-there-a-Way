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
@onready var _acts: ActRunner = $Acts
@onready var _hands: Hands = $Player/Head/Camera/Hands

## Whatever the player is engaged with, or null. The only thing gestures go to
## while GameState says FOCUSED.
var _engaged: Interactable


func _ready() -> void:
	_hud.look_requested.connect(_player.add_look)
	_hud.pause_requested.connect(_menu.open)
	_menu.bind(_settings, _hud.tuning, _saves, _journal, _reader)
	_saves.failed.connect(Notify.problem)
	_menu.opened.connect(_on_paused)
	_menu.closed.connect(_on_resumed)
	_settings.changed.connect(_player.on_setting)
	_settings.changed.connect(_hud.on_setting)
	_settings.changed.connect(_on_setting)
	_settings.changed.connect(_post.on_setting)
	_settings.changed.connect(_reader.on_setting)
	_settings.changed.connect(_hud.subtitles().on_setting)
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
	wire_level()
	if is_instance_valid(_acts):
		_acts.act_changed.connect(_on_act_changed)
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


## The act's own progression. Checkpoints are the only thing that writes an
## autosave during play (the other writer is the tab going away), and they are
## silent: a toast saying "checkpoint" would be the game addressing the player,
## which nothing in it does.
func _wire_act() -> void:
	for node in get_tree().get_nodes_in_group(&"act_end"):
		(node as ActEnd).bind(_post, _reader, _player)
	for node in get_tree().get_nodes_in_group(&"act"):
		# An act says what colour it is in one word in its own scene file. The
		# shift from sodium to fluorescent is the marker that the player has
		# left the dam and entered the programme, so it belongs to the level.
		_post.set_grade(StringName(node.get_meta(&"grade", "act1")))
	# The entity, where an act has one. It does not find the player for itself
	# and it does not reach for the fear state: both are handed to it here, so
	# it behaves the same in a test scene as in a level.
	for node in get_tree().get_nodes_in_group(&"observer"):
		var entity := node as Observer
		if entity == null:
			continue
		entity.bind(_player)
		_link(entity.approached, _fear.report_seam)

	var logic := get_tree().get_first_node_in_group(&"act_logic")
	if logic == null:
		return
	_link(Signal(logic, &"checkpoint_reached"), Callable(_saves, "checkpoint"))


## Connects everything in the level to the services that drive it: pages to the
## reader, tools to the hands, the act's checkpoints to the saves, the act's
## grade to the post stack.
##
## Public, and idempotent, because it is called from three places: once at
## startup, again whenever an act is swapped in, and by the suite when a test
## puts something in the level by hand. Everything wired to the old act went
## with it, so this is the same wiring again rather than an update of it.
func wire_level() -> void:
	_wire_readables()
	_wire_tools()
	_wire_act()


func _on_act_changed(_root: Node) -> void:
	wire_level()


## Every tool in the level, wired here for the same reason readables are: a tool
## that had to find the player's hands for itself would work differently in a
## test scene. A tool already in those hands is skipped -- it left the old act
## with the player and is not the new act's to claim.
func _wire_tools() -> void:
	for node in get_tree().get_nodes_in_group(&"carried_tool"):
		var tool := node as CarriedTool
		if tool == null or tool.held():
			continue
		_link(tool.taken, _on_tool_taken.bind(tool))


func _on_tool_taken(tool: CarriedTool) -> void:
	_hands.take(tool)
	_interactor.set_scanning(true)


## Every page in the level, wired here rather than each one finding the reader
## for itself. A Readable that had to locate a service would be a Readable that
## works differently in a test scene, and the whole point of the group is that
## adding a page to a room is adding a node.
func _wire_readables() -> void:
	for node in get_tree().get_nodes_in_group(&"readable"):
		var page := node as Readable
		if page == null:
			continue
		# Guarded rather than connected blind: `wire_level` is called again on
		# every act swap, and a page that survived one -- or was put in the
		# level by hand -- would otherwise open its document twice.
		_link(page.opened, _reader.show_document)
		_link(page.opened, _journal.mark_read)
		_link(page.closed, _reader.close)
		_link(page.scrolled, _reader.scroll_by)


## One connection, once. Enough of the wiring above runs more than once that
## the guard is worth a name rather than four copies of an `if`.
func _link(from: Signal, to: Callable) -> void:
	if not from.is_connected(to):
		from.connect(to)


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
	if target == null:
		# The action button with nothing to act on, while carrying something,
		# puts it down. No new control for it: "act" with no target is already
		# a press that does nothing, and this is the obvious thing for it to
		# mean once the player's hands can be full.
		if not _hands.empty():
			_hands.drop()
		return
	# A switch is used, not engaged with: it acts and the player is still
	# standing there with both sticks, which is what flipping a switch is like.
	if target.instant:
		target.engage()
		return
	if not _state.enter(GameState.State.FOCUSED):
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
