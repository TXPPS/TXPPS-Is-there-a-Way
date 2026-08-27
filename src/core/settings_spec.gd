@tool
class_name SettingsSpec
extends Resource

## The whole settings menu, as data.
##
## Adding a preference is: add a row here, and read it wherever it applies. The
## menu builds itself from this, so there is no screen to edit and no chance of
## a setting that persists but is never shown (or shown but never saved).

@export var rows: Array[SettingsRow] = []


func find(key: StringName) -> SettingsRow:
	for row in rows:
		if row != null and row.key == key:
			return row
	return null


## Group headings, in the order the rows first mention them.
func groups() -> PackedStringArray:
	var seen := PackedStringArray()
	for row in rows:
		if row != null and not seen.has(row.group):
			seen.append(row.group)
	return seen


func rows_in(group: String) -> Array[SettingsRow]:
	var out: Array[SettingsRow] = []
	for row in rows:
		if row != null and row.group == group:
			out.append(row)
	return out
