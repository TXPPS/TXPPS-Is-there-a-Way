@tool
class_name Document
extends Resource

## One readable thing: a memo, a logbook page, a card taped to a panel.
##
## Every document in this game was written by somebody for somebody else and
## left where it was left (`docs/STORY.md`, "The documents"). None of them
## address the player. That is a writing rule, but it has a mechanical
## consequence worth stating here: a document never contains an instruction, so
## the reader UI never needs a "hint" affordance and the player is never told
## they have found the answer.

## Which hand wrote it. Drives how the reader draws it, because the difference
## between a 1966 protocol and a pencil note on a service card is most of what
## the player learns from finding one.
enum Hand {
	TYPED,    ## Institutional. A typewriter, a form, a memo.
	PENCIL,   ## Emil. Engineer's capitals, and never a word he does not need.
	STENCIL,  ## Painted on the building itself.
	PRINTED,  ## Laminated, mass-produced: an operating card, a manufacturer's plate.
}

## Stable. Used in save data and by the journal, so changing one loses the
## record that it was read.
@export var id: StringName = &""

@export var title: String = ""

## Shown small under the title. Who and when, in the world's own words.
@export var byline: String = ""

@export var hand: Hand = Hand.TYPED

@export_multiline var body: String = ""


## Lines as they should be laid out, with the leading blank lines of a
## multiline export trimmed off. Authoring a body in the inspector always
## produces those and they always look like a bug.
func lines() -> PackedStringArray:
	return body.strip_edges().split("\n")
