class_name ActEnd
extends Area3D

## The edge of what is built.
##
## Walking through the shelter door ends the slice. Without this the player
## steps into a three-metre concrete box and reports that nothing happened,
## which is a fair thing to report and a waste of their time.
##
## The fade is the post stack's own exposure, turned down. That is not a
## general-purpose transition system and does not want to be one yet; it is two
## lines that reuse something already on screen.

signal reached

@export var card: Document
@export_range(0.5, 8.0, 0.1) var fade_seconds: float = 2.2
## Where the player is put when they put the card down. Used only when this is
## the edge of what is built; an act that hands on to another does not need it.
@export var return_to: Vector3 = Vector3(9.9, -3.8, 24.0)

## The act to mount when the card is put down, or -1 for "there is no next one".
## The card reads "End of Act One" either way -- the difference is whether the
## player is put back where they were standing or somewhere else entirely.
@export var next_act: int = -1

## Where the player stands at the start of the act this hands on to.
@export var arrive_at: Vector3 = Vector3.ZERO
@export var arrive_facing: float = 0.0

var _post: PostStack
var _reader: Reader
var _player: Player
var _fading := false
var _level := 1.0


func bind(post: PostStack, reader: Reader, player: Player) -> void:
	_post = post
	_reader = reader
	_player = player


func _ready() -> void:
	body_entered.connect(_on_entered)
	set_process(false)


func _on_entered(body: Node3D) -> void:
	if not body.is_in_group(&"listener"):
		return
	trigger()


## Ends the act without anybody having walked through anything.
##
## Act 3 does not end at a doorway: it ends with a reel in your hand, and the
## thing that knows that is `AnnexLogic`. A trigger volume for it would have to
## be somewhere the player happens to stand afterwards, which is not the same
## event at all.
func trigger() -> void:
	if _fading:
		return
	_fading = true
	set_process(true)
	reached.emit()


func _process(delta: float) -> void:
	_level = maxf(0.0, _level - delta / maxf(fade_seconds, 0.01))
	_post.on_setting(&"brightness", _level)
	if _level > 0.0:
		return
	set_process(false)
	_reader.show_document(card)
	_reader.closed_by_player.connect(_restore, CONNECT_ONE_SHOT)


func _restore() -> void:
	var runner := get_tree().get_first_node_in_group(&"act_runner") as ActRunner
	if next_act >= 0 and runner != null:
		# The player and the post stack are not part of the act, so they can be
		# set up now. The swap itself is queued: `load_act` frees the act this
		# node is inside, and freeing the object whose method is running is the
		# one thing that is never safe. `request_act` rather than a bare
		# `call_deferred` so that a save loaded inside that one-frame window
		# wins -- it knows which act it wants and this only knows which it is
		# leaving.
		_player.global_position = arrive_at
		_player.face(deg_to_rad(arrive_facing), 0.0)
		_player.velocity = Vector3.ZERO
		_post.on_setting(&"brightness", 1.0)
		runner.request_act(next_act)
		return
	_player.global_position = return_to
	_player.velocity = Vector3.ZERO
	_post.on_setting(&"brightness", 1.0)
	_level = 1.0
	_fading = false
