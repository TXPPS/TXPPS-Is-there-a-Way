@tool
class_name SettingsRow
extends Resource

## One line in the settings menu, and the definition of one preference.
##
## Every setting is stored as a float: a toggle is 0 or 1, a choice is an index.
## That sounds reductive and is the point -- serialisation, migration, clamping
## and the settings UI all become one code path instead of four.

enum Kind {
	TOGGLE,  ## Off / On. Value is 0.0 or 1.0.
	SLIDER,  ## Continuous between minimum and maximum.
	CHOICE,  ## One of `choices`. Value is the index.
}

## Stable storage key. Changing one orphans the player's setting, so don't.
@export var key: StringName = &""

## What the player reads.
@export var label: String = ""

## One line under the label. Say what it does, not what it is.
@export var hint: String = ""

## Heading this row appears under. Rows are shown in spec order within a group.
@export var group: String = "General"

@export var kind: Kind = Kind.SLIDER

@export var default_value: float = 0.0

@export_group("Slider")
@export var minimum: float = 0.0
@export var maximum: float = 1.0
@export var step: float = 0.01

## Multiplier applied when showing the value, e.g. 100 to read a 0..1 slider as
## a percentage. Display only; never affects the stored value.
@export var display_scale: float = 100.0
@export var display_suffix: String = "%"

@export_group("Choice")
@export var choices: PackedStringArray = PackedStringArray()


func clamp_value(value: float) -> float:
	match kind:
		Kind.TOGGLE:
			return 1.0 if value >= 0.5 else 0.0
		Kind.CHOICE:
			var last := maxf(float(choices.size() - 1), 0.0)
			return clampf(roundf(value), 0.0, last)
		_:
			return clampf(value, minimum, maximum)


func describe(value: float) -> String:
	match kind:
		Kind.TOGGLE:
			return "On" if value >= 0.5 else "Off"
		Kind.CHOICE:
			var index := int(clamp_value(value))
			return choices[index] if index < choices.size() else "?"
		_:
			return "%d%s" % [roundi(value * display_scale), display_suffix]
