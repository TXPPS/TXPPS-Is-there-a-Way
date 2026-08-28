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
## Where the player is put when they put the card down.
@export var return_to: Vector3 = Vector3(9.9, -3.8, 24.0)

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
	if _fading or not body.is_in_group(&"listener"):
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
	_player.global_position = return_to
	_player.velocity = Vector3.ZERO
	_post.on_setting(&"brightness", 1.0)
	_level = 1.0
	_fading = false
