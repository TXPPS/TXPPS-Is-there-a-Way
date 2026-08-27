class_name GameState
extends Node

## The player's mode of engagement with the world, and the only place that
## decides what input is allowed to do.
##
## Every system that cares about "can the player move / turn / open a door right
## now" asks here rather than keeping its own flag, because five independent
## booleans is how a game ends up letting you walk during a cutscene.
##
## Transitions are explicit. An illegal one is a programming error: it is
## refused and reported rather than silently allowed, so it surfaces in CI.

enum State {
	FREE,       ## Walking around. Full control.
	FOCUSED,    ## Locked to a puzzle. Gestures go to the puzzle, not the camera.
	MENU,       ## Settings or a confirmation. The world is paused-ish.
	CINEMATIC,  ## Scripted camera. Input is observed but ignored.
	DISABLED,   ## Loading, dying, or otherwise not a player yet.
}

signal changed(from: State, to: State)

## Who may go where. Read it as: from KEY you may enter any of VALUE.
const LEGAL: Dictionary = {
	State.FREE: [State.FOCUSED, State.MENU, State.CINEMATIC, State.DISABLED],
	State.FOCUSED: [State.FREE, State.MENU, State.DISABLED],
	State.MENU: [State.FREE, State.FOCUSED, State.DISABLED],
	State.CINEMATIC: [State.FREE, State.DISABLED],
	State.DISABLED: [State.FREE],
}

var current: State = State.DISABLED

## Where close_menu() returns to. The menu is the only state that is entered
## from more than one place and has to give control back to the right one.
var _resume: State = State.FREE


func enter(next: State) -> bool:
	if next == current:
		return true
	if not can_enter(next):
		push_error("Illegal state transition: %s -> %s" % [name_of(current), name_of(next)])
		return false
	var previous := current
	current = next
	changed.emit(previous, next)
	return true


func can_enter(next: State) -> bool:
	var allowed: Array = LEGAL.get(current, [])
	return allowed.has(next)


## Opens the menu, remembering what to give control back to.
func open_menu() -> bool:
	if current == State.MENU:
		return true
	var from := current
	if not enter(State.MENU):
		return false
	_resume = from
	return true


func close_menu() -> bool:
	if current != State.MENU:
		return false
	return enter(_resume)


## True only when the player is free to walk and look.
func accepts_world_input() -> bool:
	return current == State.FREE


## True when drags and pinches belong to a puzzle rather than the camera.
func routes_gestures_to_puzzle() -> bool:
	return current == State.FOCUSED


## True when the on-screen locomotion controls should be drawn at all.
func shows_touch_controls() -> bool:
	return current == State.FREE


static func name_of(state: State) -> String:
	return State.keys()[state]
