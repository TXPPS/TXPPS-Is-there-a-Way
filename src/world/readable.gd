class_name Readable
extends Node3D

## A thing in the world with something written on it.
##
## Follows DialLock's shape rather than inheriting from Interactable: the zone
## is a child, this owns the behaviour, and `Interactable` stays a dumb
## component. Engaging opens the reader; the drag that would have turned the
## camera scrolls the page instead, which is the focused-interaction contract
## doing exactly what it was built for.

signal opened(document: Document)
signal closed
signal scrolled(delta: Vector2)

@export var document: Document

## Overrides the zone's prompt when set, so a clipboard can say "Read the log"
## and a card on a panel can say "Read the card" without two scenes.
@export var prompt_override: String = ""

@onready var _zone: Interactable = $Zone


func _ready() -> void:
	if not prompt_override.is_empty():
		_zone.prompt = prompt_override
	_zone.release_prompt = "Put it down"
	_zone.engaged.connect(_on_engaged)
	_zone.disengaged.connect(_on_disengaged)
	_zone.dragged.connect(_on_dragged)


func _on_engaged() -> void:
	opened.emit(document)


func _on_disengaged() -> void:
	closed.emit()


func _on_dragged(_screen: Vector2, delta: Vector2) -> void:
	scrolled.emit(delta)
