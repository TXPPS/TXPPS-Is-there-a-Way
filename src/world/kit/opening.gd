@tool
class_name Opening
extends Resource

## A hole in a wall.
##
## A resource rather than a packed Vector4 because an opening has five numbers
## and the fifth -- the sill -- is the one that makes a level with more than one
## floor possible. A doorway from a hall into a stair shaft is a hole partway up
## the shaft's wall, and there is no way to say that with four.

enum Wall { NORTH, SOUTH, WEST, EAST }

@export var wall: Wall = Wall.NORTH

## Along the wall, from its centre. Negative is west on N/S walls, north on E/W.
@export var offset: float = 0.0

@export_range(0.4, 12.0, 0.1) var width: float = 1.2

@export_range(0.4, 12.0, 0.1) var height: float = 2.1

## Height of the bottom edge above this room's own floor. Zero for a doorway you
## walk through; anything else for a hatch, a window, or a landing partway up.
@export_range(0.0, 20.0, 0.1) var sill: float = 0.0
