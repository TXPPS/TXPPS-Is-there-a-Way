class_name Journal
extends Node

## What the player has read.
##
## Saveable, and the first thing in this game whose save state is about the
## player rather than about the world. It exists now because a document read in
## Act 1 has to still be read after a reload in Act 3, and retrofitting that
## later means every document's id becomes a migration.

signal read_first_time(document: Document)

@export var save_key: StringName = &"journal"

var _read: Dictionary[StringName, bool] = {}

## Every document there is, so that what was read can be read again. Ids alone
## survive a reload; the text does not, and this is where it comes back from.
@export var index: DocumentIndex


func mark_read(document: Document) -> void:
	if document == null or document.id == &"":
		return
	if _read.has(document.id):
		return
	_read[document.id] = true
	read_first_time.emit(document)


func has_read(id: StringName) -> bool:
	return _read.has(id)


func count() -> int:
	return _read.size()


## Everything read so far, in the order the index lists them -- which is story
## order, because somebody looking for what they read an hour ago is looking for
## it where they read it.
func read_documents() -> Array[Document]:
	var found: Array[Document] = []
	if index == null:
		return found
	for document in index.documents:
		if document != null and _read.has(document.id):
			found.append(document)
	return found


## How many there are to find, for a menu that can say "9 of 22".
func total() -> int:
	return 0 if index == null else index.count()


func save_state() -> Dictionary:
	var ids := PackedStringArray()
	for id in _read:
		ids.append(String(id))
	ids.sort()
	return {"read": Array(ids)}


func load_state(state: Dictionary) -> void:
	_read.clear()
	for id in state.get("read", []):
		_read[StringName(id)] = true
