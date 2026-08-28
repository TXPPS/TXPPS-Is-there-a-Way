#!/usr/bin/env python3
"""Write src/world/act2/shelter.tscn.

Act 2 is a spine corridor with rooms off it, which is what a 1962 community
shelter actually is: you do not get an interesting plan when the budget is
"capacity 140 and two weeks". The interest is in what is in the rooms.

Generated rather than hand-placed for the same reason Act 1 is (DECISIONS.md
D23): a room is six numbers, and a level whose geometry is arithmetic is a
level that can be moved half a metre without a day of clicking.

Two things this file exists to get right, both of which have bitten before:

  * A `.tscn` Transform3D takes the three basis vectors in order, so the fix
    for "everything faces into its wall" is to write the axes, not their
    transpose. `facing()` below is the only place that decides.
  * Room walls are shared. Two rooms that both build the wall between them get
    coplanar surfaces that fight, so the room whose doorway it is keeps it and
    the other omits that side.
"""
import math
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[2] / "src/world/act2/shelter.tscn"

# The fixture and prop convention: a bulkhead lamp faces +X, everything built
# out of device_*.tscn faces +Z. Both are handled by asking for a world
# direction rather than an angle.
EAST, WEST, NORTH, SOUTH = "east", "west", "north", "south"

_DIR = {EAST: (1.0, 0.0), WEST: (-1.0, 0.0), NORTH: (0.0, -1.0), SOUTH: (0.0, 1.0)}


def fmt(v):
    if not isinstance(v, float):
        return str(v)
    v = round(v, 5) + 0.0   # +0.0 turns -0.0 into 0.0, which keeps diffs quiet
    return "%g" % v


def facing(direction, local_forward="+z"):
    """The three basis axes that point `local_forward` along `direction`.

    Returns the axes themselves -- x, y, z as world vectors. Turning them into
    the twelve numbers a .tscn wants is `t3`'s job, and the two are separate
    because that serialisation is the thing this file has got wrong before.
    """
    dx, dz = _DIR[direction]
    if local_forward == "+z":
        z = (dx, 0.0, dz)
        x = (dz, 0.0, -dx)   # right-handed: y cross z
    elif local_forward == "+x":
        x = (dx, 0.0, dz)
        z = (-dz, 0.0, dx)   # right-handed: x cross y
    else:
        raise ValueError(local_forward)
    return x, (0.0, 1.0, 0.0), z


def t3(axes, pos):
    """A Transform3D literal, from three basis axes and an origin.

    **A .tscn stores the basis by rows, not by axis.** `Basis` keeps its rows,
    and the axes are its *columns*, so writing the axes out in order gives the
    transpose -- which for a rotation is its inverse, and mounts everything
    facing backwards. That bug shipped once already (every prop in Act 1 was
    hung facing into its wall) and it is invisible in a screenshot, because a
    flat panel on a wall looks the same from the front whichever way its normal
    points. tests/case_reach.gd is what catches it; this is what avoids it.
    """
    x, y, z = axes
    rows = (x[0], y[0], z[0],
            x[1], y[1], z[1],
            x[2], y[2], z[2])
    return "Transform3D(%s, %s)" % (
        ", ".join(fmt(v) for v in rows),
        ", ".join(fmt(v) for v in pos),
    )


def upright(pos):
    return t3(((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)), pos)


# --- the plan ---------------------------------------------------------------
#
# A spine corridor running north-south, rooms hung off it. Floor level is y=0
# for the whole act: RoomBox puts the floor's top surface at its own origin, so
# rooms at the same y share a floor. Interior clear dimensions, 0.5 m grid.
#
#   Vestibule      arrive here from Act 1's blast door, at the south end
#   Corridor       the spine, with panel DP-2 on its east side
#   PlantRoom      the set, the day tank, the transfer switch      (west)
#   Mess           the intercom, the table Emil reads at           (west)
#   BunkRoom       two bunks, one made and one stripped            (east)
#   StoreRoom      rations, rotated, dated this month              (east)
#   StairHead      the way down to the annex, under water until the sump runs
#
# Wall ownership: the corridor keeps every wall it has a doorway in, and the
# rooms omit the side they share with it.

THICK = 0.4
CORRIDOR = dict(interior=(2.5, 2.6, 20.0), at=(0.0, 0.0, 0.0))

# x of a room's centre when its <side> face abuts the corridor's outer wall.
def west_of_corridor(width):
    return -(CORRIDOR["interior"][0] / 2 + THICK) - width / 2


def east_of_corridor(width):
    return (CORRIDOR["interior"][0] / 2 + THICK) + width / 2


def south_of_corridor(depth):
    return (CORRIDOR["interior"][2] / 2 + THICK) + depth / 2


def north_of_corridor(depth):
    return -(CORRIDOR["interior"][2] / 2 + THICK) - depth / 2


ROOMS = [
    # name,        interior,             at,                                    omit,     roofed
    ("Corridor",   (2.5, 2.6, 20.0),     (0.0, 0.0, 0.0),                       [],        True),
    ("Vestibule",  (4.0, 2.6, 3.0),      (0.0, 0.0, south_of_corridor(3.0)),    ["NORTH"], True),
    ("PlantRoom",  (7.0, 3.0, 7.0),      (west_of_corridor(7.0), 0.0, -4.0),    ["EAST"],  True),
    ("Mess",       (6.0, 2.6, 6.0),      (west_of_corridor(6.0), 0.0, 5.5),     ["EAST"],  True),
    ("BunkRoom",   (6.0, 2.6, 5.0),      (east_of_corridor(6.0), 0.0, 5.0),     ["WEST"],  True),
    ("StoreRoom",  (3.0, 2.6, 4.0),      (east_of_corridor(3.0), 0.0, -3.0),    ["WEST"],  True),
    ("StairHead",  (3.0, 2.6, 4.0),      (0.0, 0.0, north_of_corridor(4.0)),    ["SOUTH"], True),
]

# Doorways, all in the corridor's own walls. offset runs along the wall: on a
# north/south wall that is x, on an east/west wall it is z, negative northward.
DOORS = [
    ("SOUTH", 0.0, 1.2, 2.1),   # to the vestibule, and back to Act 1
    ("WEST", -4.0, 1.4, 2.2),   # plant room: wide, because plant goes through it
    ("WEST", 5.5, 1.0, 2.1),    # mess
    ("EAST", 5.0, 1.0, 2.1),    # bunk room
    ("EAST", -3.0, 0.9, 2.1),   # store
    ("NORTH", 0.0, 1.2, 2.1),   # stair head
]


# --- what is in the rooms ---------------------------------------------------
#
# Panel DP-2, in schedule order. The kW figures are the puzzle: see
# docs/PUZZLES.md P2.3, and tests/case_devices.gd, which asserts the shape they
# make rather than trusting them to a scene file.
BREAKERS = [
    # node,             label,                    kW,  surge, column, row
    ("Sump",            "1  SUMP PUMP 7.5 HP",    6.9, 26.0,  0, 4),
    ("AnnexLighting",   "3  ANNEX LIGHTING",      4.4,  0.0,  0, 3),
    ("ShelterLighting", "5  SHELTER LIGHTING",    2.6,  0.0,  0, 2),
    ("Mess",            "7  MESS & GALLEY",       5.2,  0.0,  0, 1),
    ("Vent",            "9  VENT FAN 3 HP",       2.8,  8.4,  0, 0),
    ("Chambers",        "11 CHAMBER LUMINAIRES",  2.5,  0.0,  1, 4),
    ("Recorders",       "13 RECORDER BAY",        3.1,  0.0,  1, 3),
    ("Well",            "15 WELL PUMP 2 HP",      1.9,  7.6,  1, 2),
    ("Heater",          "17 UNIT HEATER",         9.0,  0.0,  1, 1),
]

PANEL_AT = (1.13, 0.0, -6.5)   # on the corridor's east wall, facing west
PANEL_COL = 0.5                # spacing between the two columns, along z
PANEL_ROW = 0.2                # spacing between rows, up the wall
PANEL_BASE = 1.05

LAMPS = [
    # node,          at,                     faces
    ("CorridorSouth", (-1.13, 2.2, 7.0),     EAST),
    ("CorridorMid",   (-1.13, 2.2, 0.0),     EAST),
    ("CorridorNorth", (-1.13, 2.2, -7.0),    EAST),
    ("Plant",         (-8.53, 2.5, -4.0),    EAST),
    ("Mess",          (-7.53, 2.2, 5.5),     EAST),
    ("Bunk",          (7.53, 2.2, 5.0),      WEST),
    ("Store",         (4.53, 2.2, -3.0),     WEST),
    ("Vestibule",     (-1.88, 2.2, 11.9),    EAST),
    ("StairHead",     (-1.38, 2.2, -12.4),   EAST),
]

# Pages, in the rooms the people who wrote them would have left them.
READABLES = [
    ("StockingManifest", "d07", (-1.88, 1.55, 11.4), EAST),   # vestibule, west wall
    ("OccupancyNotice",  "d11", (1.88, 1.55, 12.3),  WEST),   # taped over the capacity sign
    ("RationCard",       "d08", (4.53, 1.5, -2.2),   WEST),   # store room, clear of the drums
    ("ServiceCard",      "d09", (-8.53, 1.5, -3.0),  EAST),   # plant room, wire frame
    ("OperatingCard",    "d09a", (-4.4, 1.78, -7.38), SOUTH), # inside the cabinet door
    ("PanelSchedule",    "d09b", (1.10, 1.95, -6.5),  WEST),  # in the panel door
    ("Postcard",         "d10", (5.6, 0.92, 3.4),    WEST),   # bunk room, on the shelf
    ("WorkUnitCover",    "d12", (-7.53, 1.45, 5.5),  EAST),   # mess, on the board over the table
]


# --- writing the scene ------------------------------------------------------

DOCS = {
    "d07": "d07_stocking_manifest", "d08": "d08_ration_card",
    "d09": "d09_generator_card", "d09a": "operating_card",
    "d09b": "shelter_panel_schedule", "d10": "d10_postcard",
    "d11": "d11_occupancy_notice", "d12": "d12_work_unit_cover",
}

EXT = [
    ("Script", "res://src/world/kit/room_box.gd", "1_room"),
    ("Script", "res://src/world/kit/opening.gd", "2_open"),
    ("Script", "res://src/world/kit/slab.gd", "3_slab"),
    ("Material", "res://assets/materials/graybox_concrete.tres", "4_concrete"),
    ("Material", "res://assets/materials/graybox_steel.tres", "5_steel"),
    ("Material", "res://assets/materials/graybox_paint.tres", "6_paint"),
    ("Material", "res://assets/materials/graybox_silt.tres", "7_silt"),
    ("Material", "res://assets/materials/graybox_paper.tres", "7b_paper"),
    ("PackedScene", "res://src/world/kit/bulkhead_lamp.tscn", "8_lamp"),
    ("Script", "res://src/world/surface_tag.gd", "9_tag"),
    ("Resource", "res://assets/surfaces/concrete.tres", "10_surface"),
    ("Script", "res://src/audio/reverb_zone.gd", "11_verb"),
    ("PackedScene", "res://src/world/readable.tscn", "12_page"),
    ("PackedScene", "res://src/world/devices/device_toggle.tscn", "13_toggle"),
    ("PackedScene", "res://src/world/devices/device_push.tscn", "14_push"),
    ("PackedScene", "res://src/world/devices/device_door.tscn", "15_door"),
    ("PackedScene", "res://src/world/devices/device_valve.tscn", "16_valve"),
    ("PackedScene", "res://src/world/devices/device_selector.tscn", "17_selector"),
    ("Script", "res://src/world/act2/shelter_logic.gd", "18_logic"),
    ("Script", "res://src/world/act1/act_end.gd", "19_end"),
    ("Resource", "res://assets/documents/act_end_card.tres", "20_card"),
    ("Script", "res://src/world/act2/light_seam.gd", "21_seam"),
    ("AudioStream", "res://assets/audio/amb_powerhouse.wav", "22_tone"),
]
EXT += [("Resource", "res://assets/documents/%s.tres" % f, "doc_%s" % k) for k, f in sorted(DOCS.items())]


def ext_id(path_fragment):
    for _, path, ident in EXT:
        if path_fragment in path:
            return ident
    raise KeyError(path_fragment)


def box(name, size, at, material, parent=".", solid=True):
    return [
        '[node name="%s" type="Node3D" parent="%s"]' % (name, parent),
        "transform = %s" % upright(at),
        'script = ExtResource("3_slab")',
        "size = Vector3(%s)" % ", ".join(fmt(float(v)) for v in size),
        'material = ExtResource("%s")' % material,
        "solid = %s" % ("true" if solid else "false"),
        "",
    ]


def build():
    lines = []
    openings = []          # sub-resources for the corridor's doorways
    for i, (wall, offset, width, height) in enumerate(DOORS, start=1):
        openings.append([
            '[sub_resource type="Resource" id="Opening_%d"]' % i,
            'script = ExtResource("2_open")',
            "wall = %d" % ["NORTH", "SOUTH", "WEST", "EAST"].index(wall),
            "offset = %s" % fmt(float(offset)),
            "width = %s" % fmt(float(width)),
            "height = %s" % fmt(float(height)),
            "sill = 0.0",
            "",
        ])

    body = []
    body += ['[node name="Shelter" type="Node3D" groups=["act"]]', ""]

    # -- rooms
    for name, interior, at, omit, roofed in ROOMS:
        body.append('[node name="%s" type="Node3D" parent="."]' % name)
        body.append("transform = %s" % upright(at))
        body.append('script = ExtResource("1_room")')
        body.append("interior = Vector3(%s)" % ", ".join(fmt(float(v)) for v in interior))
        body.append("thickness = %s" % fmt(THICK))
        if name == "Corridor":
            ids = ", ".join('SubResource("Opening_%d")' % i for i in range(1, len(DOORS) + 1))
            body.append('openings = Array[ExtResource("2_open")]([%s])' % ids)
        if omit:
            walls = ", ".join(str(["NORTH", "SOUTH", "WEST", "EAST"].index(w)) for w in omit)
            body.append("omit_walls = Array[int]([%s])" % walls)
        body.append('wall_material = ExtResource("4_concrete")')
        body.append('floor_material = ExtResource("4_concrete")')
        if not roofed:
            body.append("roofed = false")
        body.append("")
        body.append('[node name="Surface" type="Node" parent="%s"]' % name)
        body.append('script = ExtResource("9_tag")')
        body.append('surface = ExtResource("10_surface")')
        body.append("")

    # -- lamps, all on the one shelter lighting circuit
    body += ['[node name="Lamps" type="Node3D" parent="."]', ""]
    for name, at, direction in LAMPS:
        body.append('[node name="%s" parent="Lamps" instance=ExtResource("8_lamp")]' % name)
        body.append("transform = %s" % t3(facing(direction, "+x"), at))
        body.append('circuit = &"SHLT"')
        body.append("lit = false")
        body.append("")

    body += _plant()
    body += _panel()
    body += _dressing()
    body += _pages()
    body += _ways_out()
    return lines, openings, body


def _plant():
    """The set, its fuel, and the three controls the act turns on."""
    out = ['[node name="Plant" type="Node3D" parent="."]', ""]
    # The set itself: a block on a housekeeping pad, against the plant room's
    # north wall. It is scenery -- everything the player touches is on the wall
    # beside it, which is where a 1962 set put its controls.
    out += box("Pad", (3.0, 0.15, 1.8), (-6.2, 0.07, -5.9), ext_id("concrete"), "Plant")
    out += box("Set", (2.6, 1.4, 1.4), (-6.2, 0.85, -5.9), ext_id("paint"), "Plant")
    out += box("Exhaust", (0.24, 1.9, 0.24), (-7.3, 1.9, -6.5), ext_id("steel"), "Plant")
    out += box("DayTank", (0.9, 0.9, 0.7), (-8.1, 1.85, -2.6), ext_id("steel"), "Plant")
    out += box("Cabinet", (1.1, 0.9, 0.16), (-4.4, 1.5, -7.42), ext_id("paint"), "Plant")
    # On the west wall rather than behind the set: the machine was standing in
    # front of its own controls, which case_reach found by trying to stand there.
    out += box("SetBoard", (0.14, 0.7, 1.4), (-8.58, 1.4, -4.6), ext_id("paint"), "Plant")

    out.append('[node name="DayTankValve" parent="Plant" instance=ExtResource("16_valve")]')
    out.append("transform = %s" % t3(facing(EAST), (-8.5, 1.25, -2.6)))
    out.append('save_key = &"day_tank"')
    out.append('label = "DAY TANK ISOL"')
    out.append("turns_to_open = 3")
    out.append("")

    out.append('[node name="Starter" parent="Plant" instance=ExtResource("14_push")]')
    out.append("transform = %s" % t3(facing(EAST), (-8.5, 1.55, -4.25)))
    out.append('label = "START"')
    out.append('prompt = "Press start"')
    out.append("")

    out.append('[node name="SetMain" parent="Plant" instance=ExtResource("13_toggle")]')
    out.append("transform = %s" % t3(facing(EAST), (-8.5, 1.55, -4.95)))
    out.append('save_key = &"set_main"')
    out.append('label = "SET MAIN"')
    out.append("on = false")
    out.append('prompt_when_on = "Open the set main"')
    out.append('prompt_when_off = "Close the set main"')
    out.append("")

    out.append('[node name="TransferSwitch" parent="Plant" instance=ExtResource("17_selector")]')
    out.append("transform = %s" % t3(facing(SOUTH), (-4.4, 1.4, -7.34)))
    out.append('save_key = &"transfer"')
    out.append("index = 1")   # left in TEST after the last monthly exercise
    out.append("")
    return out


def _panel():
    """DP-2, in the corridor, so the player walks between it and the set."""
    out = ['[node name="Panel" type="Node3D" parent="."]', ""]
    out += box("Board", (0.08, 1.3, 1.0), (1.16, 1.5, PANEL_AT[2]), ext_id("paint"), "Panel")
    out += ['[node name="Breakers" type="Node3D" parent="Panel"]', ""]
    for node, label, kw, surge, col, row in BREAKERS:
        z = PANEL_AT[2] + (col - 0.5) * PANEL_COL
        y = PANEL_BASE + row * PANEL_ROW
        out.append('[node name="%s" parent="Panel/Breakers" instance=ExtResource("13_toggle")]' % node)
        out.append("transform = %s" % t3(facing(WEST), (PANEL_AT[0], y, z)))
        out.append('save_key = &"%s"' % node)
        out.append('label = "%s"' % label)
        out.append("on = true")
        out.append("load_kw = %s" % fmt(kw))
        if surge > 0.0:
            out.append("surge_kw = %s" % fmt(surge))
        out.append('prompt_when_on = "Open the breaker"')
        out.append('prompt_when_off = "Close the breaker"')
        out.append("")
    return out


def _dressing():
    """Emil's housekeeping, which is the act's real subject (STORY_NOTES S1).

    None of it is interactive and none of it is commented on. A bunk that is
    made and a bunk that is stripped is a sentence about how many people live
    here, and the game never says it out loud.
    """
    out = ['[node name="Dressing" type="Node3D" parent="."]', ""]

    # Bunk room: two frames, one made up, one stripped to the springs.
    out += box("BunkMadeFrame", (0.9, 0.1, 1.9), (5.6, 0.55, 3.4), ext_id("steel"), "Dressing")
    out += box("BunkMade", (0.86, 0.16, 1.8), (5.6, 0.68, 3.4), ext_id("paper"), "Dressing")
    out += box("BunkMadeShelf", (0.34, 0.05, 0.5), (5.6, 0.88, 3.4), ext_id("steel"), "Dressing")
    out += box("BunkStripped", (0.9, 0.1, 1.9), (5.6, 0.55, 6.4), ext_id("steel"), "Dressing")
    out += box("BunkStrippedUpper", (0.9, 0.08, 1.9), (5.6, 1.45, 6.4), ext_id("steel"), "Dressing")

    # Store room: water drums and the ration cartons, rotated front to back.
    for i in range(4):
        out += box("Drum%d" % (i + 1), (0.56, 0.86, 0.56),
                   (2.1 + (i % 2) * 0.66, 0.43, -4.4 + (i // 2) * 0.66),
                   ext_id("steel"), "Dressing")
    out += box("Shelf", (2.6, 0.06, 0.5), (3.15, 1.2, -1.6), ext_id("steel"), "Dressing")
    for i in range(5):
        out += box("Carton%d" % (i + 1), (0.4, 0.3, 0.4), (2.1 + i * 0.45, 1.38, -1.6),
                   ext_id("paint"), "Dressing")

    # Mess: a table, a chair, one place set. Not two.
    out += box("MessTable", (1.6, 0.06, 0.8), (-4.65, 0.74, 5.5), ext_id("paint"), "Dressing")
    out += box("MessLeg1", (0.06, 0.72, 0.06), (-5.35, 0.36, 5.2), ext_id("steel"), "Dressing")
    out += box("MessLeg2", (0.06, 0.72, 0.06), (-3.95, 0.36, 5.8), ext_id("steel"), "Dressing")
    out += box("MessChair", (0.42, 0.05, 0.42), (-4.65, 0.46, 6.4), ext_id("paint"), "Dressing")

    # Plant room: the cable Emil taped down so nobody trips on it, which is the
    # S1 beat that lands earliest -- a hazard fixed rather than ignored.
    out += box("TapedCable", (2.2, 0.05, 0.09), (-7.0, 0.02, -2.0), ext_id("steel"), "Dressing")
    out += box("CableTape1", (0.12, 0.06, 0.13), (-7.9, 0.03, -2.0), ext_id("paper"), "Dressing")
    out += box("CableTape2", (0.12, 0.06, 0.13), (-6.1, 0.03, -2.0), ext_id("paper"), "Dressing")
    return out


def _pages():
    out = ['[node name="Readables" type="Node3D" parent="."]', ""]
    for node, key, at, direction in READABLES:
        out.append('[node name="%s" parent="Readables" instance=ExtResource("12_page")]' % node)
        out.append("transform = %s" % t3(facing(direction), at))
        out.append('document = ExtResource("doc_%s")' % key)
        out.append("")
    return out


def _ways_out():
    """The door back to Act 1, the door on to Act 3, and what is under it."""
    out = []
    out.append('[node name="ShelterDoor" parent="." instance=ExtResource("15_door")]')
    out.append("transform = %s" % t3(facing(NORTH), (0.0, 0.0, 13.6)))
    out.append('save_key = &"shelter_door"')
    out.append("open = false")
    out.append('prompt = "It will not move from this side"')
    out.append("available = false")
    out.append("")

    out.append('[node name="AnnexDoor" parent="." instance=ExtResource("15_door")]')
    out.append("transform = %s" % t3(facing(SOUTH), (0.0, 0.0, -14.4)))
    out.append('save_key = &"annex_door"')
    out.append("open = false")
    out.append("available = false")
    out.append("")

    # Water in the stair head, up over the nosings, until the sump has run.
    out += box("StairWater", (2.9, 0.34, 3.9), (0.0, 0.17, -12.4), ext_id("silt"), ".", solid=False)

    out.append('[node name="Logic" type="Node" parent="." groups=["saveable"]]')
    out.append('script = ExtResource("18_logic")')
    out.append('save_key = &"act2"')
    out.append("")

    out.append('[node name="Seam" type="Node3D" parent="." groups=["saveable"]]')
    out.append("transform = %s" % upright((-1.2, 1.3, 2.0)))
    out.append('script = ExtResource("21_seam")')
    out.append('save_key = &"seam"')
    out.append("")

    out.append('[node name="ActEnd" type="Area3D" parent="." groups=["act_end"]]')
    out.append("transform = %s" % upright((0.0, 1.0, -15.6)))
    out.append("collision_layer = 0")
    out.append("collision_mask = 2")
    out.append('script = ExtResource("19_end")')
    out.append('card = ExtResource("20_card")')
    out.append("return_to = Vector3(0, 0.1, -11.0)")
    out.append("")
    out.append('[node name="Shape" type="CollisionShape3D" parent="ActEnd"]')
    out.append('shape = SubResource("BoxShape3D_end")')
    out.append("")

    out.append('[node name="Air" type="AudioStreamPlayer3D" parent="."]')
    out.append("transform = %s" % upright((0.0, 1.6, 0.0)))
    out.append('stream = ExtResource("22_tone")')
    out.append("volume_db = -19.0")
    out.append('bus = &"SFX"')
    out.append("unit_size = 22.0")
    out.append("max_db = 0.0")
    out.append("autoplay = true")
    out.append("")
    return out


def main():
    _, openings, body = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(_head() + sum(openings, []) + body) + "\n"
    OUT.write_text(text)
    print("wrote %s (%d lines)" % (OUT, text.count("\n")))


def _head():
    out = ['[gd_scene load_steps=%d format=3]' % (len(EXT) + len(DOORS) + 2), ""]
    for kind, path, ident in EXT:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, ident))
    out.append("")
    out.append('[sub_resource type="BoxShape3D" id="BoxShape3D_end"]')
    out.append("size = Vector3(2.6, 2.2, 0.6)")
    out.append("")
    return out


if __name__ == "__main__":
    main()
