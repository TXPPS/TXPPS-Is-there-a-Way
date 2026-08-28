class_name Interactable
extends Area3D

## Marks a thing in the world as something the player can engage with, and
## carries the gestures through while they are engaged with it.
##
## Deliberately dumb: it holds no puzzle logic and knows nothing about what it
## is attached to. Whatever owns it connects to these signals, which is what
## lets a dial, a valve and a keypad share one targeting system without sharing
## a base class.

## Emitted when the player commits to this thing and the camera locks to it.
signal engaged
signal disengaged

## Gestures, only while engaged. Screen positions and deltas are viewport units,
## already claimed and clamped by TouchRouter.
signal pressed(screen: Vector2)
signal dragged(screen: Vector2, delta: Vector2)
signal lifted

## What the prompt says when this is the target. Written as an instruction.
@export var prompt: String = "Examine"

## What the action button says once engaged.
@export var release_prompt: String = "Step back"

## A solved puzzle stays solved and stops offering itself.
@export var available: bool = true

## True for things you *use* rather than things you engage *with*. A breaker is
## flipped and you step back in the same motion; a document is picked up and
## held. Instant things fire `engaged` and never enter FOCUSED, so the sticks
## never leave the screen for the sake of a switch.
@export var instant: bool = false


func engage() -> void:
	engaged.emit()


func disengage() -> void:
	disengaged.emit()


## Relayed in by Main while this is the focused thing. Methods rather than
## signals emitted from outside, so the owner of a signal stays the only thing
## that fires it.
func push_press(screen: Vector2) -> void:
	pressed.emit(screen)


func push_drag(screen: Vector2, delta: Vector2) -> void:
	dragged.emit(screen, delta)


func push_lift() -> void:
	lifted.emit()
