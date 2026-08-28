class_name GradeZone
extends Area3D

## Where one act's colour ends and the next one's begins.
##
## `ART_BIBLE.md` fixes the palette shift from sodium to fluorescent green-white
## as the marker that the player has left the *dam* and entered the *programme*,
## and the strongest place to put that is a doorway. A grade that changes as you
## walk through a door says something; one that changes behind a loading fade
## says only that something loaded.
##
## The zone owns a grade and hands it back when the player leaves, so walking in
## and out of the annex walks the colour in and out with them. It does not know
## what the grade outside it is: the post stack keeps that, because the answer
## is "whatever the act said" and the act is not this zone's business.

## The grade to load while the player is inside. Must name a LUT that exists;
## `case_render` checks that every named grade does.
@export var grade: StringName = &"annex"

## How long the change takes. Zero is right for a doorway you walk through --
## the wall is the transition -- and there is deliberately no cross-fade, since
## fading between two lookup tables means holding both and blending per pixel
## for a moment nobody is looking at.
@export_range(0.0, 4.0, 0.1) var seconds: float = 0.0

var _outside := &""
var _inside := false


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func inside() -> bool:
	return _inside


func _on_entered(body: Node3D) -> void:
	if _inside or not body.is_in_group(&"listener"):
		return
	var post := _post()
	if post == null:
		return
	_inside = true
	_outside = post.grade()
	post.set_grade(grade)


func _on_exited(body: Node3D) -> void:
	if not _inside or not body.is_in_group(&"listener"):
		return
	_inside = false
	var post := _post()
	if post != null and _outside != &"":
		post.set_grade(_outside)


func _post() -> PostStack:
	return get_tree().get_first_node_in_group(&"post_stack") as PostStack
