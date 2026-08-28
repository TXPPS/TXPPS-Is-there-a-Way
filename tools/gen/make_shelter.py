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
import pathlib
import sys

OUT = pathlib.Path(__file__).resolve().parents[2] / "src/world/act2/shelter.tscn"

# The fixture and prop convention: a bulkhead lamp faces +X, everything built
# out of device_*.tscn faces +Z. Both are handled by asking for a world
# direction rather than an angle.
EAST, WEST, NORTH, SOUTH = "east", "west", "north", "south"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tscn import WALLS, box, facing, flush_boxes, fmt, solo_box, t3, upright  # noqa: E402

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


# --- the annex ---------------------------------------------------------------
#
# Cut into the rock behind the shelter in 1964, for the programme. It is rooms
# in this scene rather than an act of its own (DECISIONS.md D28): P3.3 sends the
# player back to the shelter's panel to take a load off, and that only means
# anything if it is the same panel and a real walk.
#
# The corridor runs east-west, across the shelter's north-south spine, so the
# two read as different buildings the moment you are in one -- which they are.

def north_of(z, depth, thickness=None):
    """Centre of a room whose south face abuts something ending at `z`."""
    return z - (thickness or THICK) - depth / 2


OBS_Z = north_of(-14.4, 2.5)          # the observation corridor
CHAMBER_Z = north_of(OBS_Z - 1.25, 3.0)
TANK = (-11.9, -16.05)
LIBRARY_Z = north_of(TANK[1] - 2.5, 4.0)

ROOMS = [
    # name,        interior,             at,                                    omit,     roofed
    ("Corridor",   (2.5, 2.6, 20.0),     (0.0, 0.0, 0.0),                       [],        True),
    ("Vestibule",  (4.0, 2.6, 3.0),      (0.0, 0.0, south_of_corridor(3.0)),    ["NORTH"], True),
    ("PlantRoom",  (7.0, 3.0, 7.0),      (west_of_corridor(7.0), 0.0, -4.0),    ["EAST"],  True),
    ("Mess",       (6.0, 2.6, 6.0),      (west_of_corridor(6.0), 0.0, 5.5),     ["EAST"],  True),
    ("BunkRoom",   (6.0, 2.6, 5.0),      (east_of_corridor(6.0), 0.0, 5.0),     ["WEST"],  True),
    ("StoreRoom",  (3.0, 2.6, 4.0),      (east_of_corridor(3.0), 0.0, -3.0),    ["WEST"],  True),
    ("StairHead",  (3.0, 2.6, 4.0),      (0.0, 0.0, north_of_corridor(4.0)),    ["SOUTH"], True),

    # The annex.
    ("ObsCorridor", (18.0, 2.6, 2.5),    (0.0, 0.0, OBS_Z),                     [],        True),
    ("ChamberA",   (3.0, 2.6, 3.0),      (-5.0, 0.0, CHAMBER_Z),                ["SOUTH"], True),
    ("ChamberB",   (3.0, 2.6, 3.0),      (0.0, 0.0, CHAMBER_Z),                 ["SOUTH"], True),
    ("ChamberC",   (3.0, 2.6, 3.0),      (5.0, 0.0, CHAMBER_Z),                 ["SOUTH"], True),
    ("TankRoom",   (5.0, 2.8, 5.0),      (TANK[0], 0.0, TANK[1]),               ["EAST"],  True),
    ("RecorderBay", (5.0, 2.6, 5.0),     (11.9, 0.0, OBS_Z),                    ["WEST"],  True),
    ("TapeLibrary", (4.0, 2.6, 4.0),     (TANK[0], 0.0, LIBRARY_Z),             ["SOUTH"], True),
]

# Doorways in the annex corridor's own walls, and the one in the tank room that
# leads on to the library.
ANNEX_DOORS = [
    ("ObsCorridor", "SOUTH", 0.0, 1.2, 2.1),   # back to the shelter stair head
    ("ObsCorridor", "NORTH", -5.0, 1.0, 2.1),  # chamber A
    ("ObsCorridor", "NORTH", 0.0, 1.0, 2.1),   # chamber B
    ("ObsCorridor", "NORTH", 5.0, 1.0, 2.1),   # chamber C
    ("ObsCorridor", "WEST", 0.0, 1.2, 2.1),    # tank room
    ("ObsCorridor", "EAST", 0.0, 1.2, 2.1),    # recorder bay
    ("TankRoom", "NORTH", 0.0, 1.0, 2.1),      # on to the tape library
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

# The annex runs on fluorescent, which is the palette shift, and the three
# chamber luminaires are C-1 -- the imposed signal itself, and the lamps the
# entity travels between. They are on their own circuits because the timeclock
# drives them one at a time.
TUBES = [
    ("ObsWest",   (-6.5, 2.3, -14.93),  SOUTH, "ANNEX"),
    ("ObsMid",    (0.0, 2.3, -14.93),   SOUTH, "ANNEX"),
    ("ObsEast",   (6.5, 2.3, -14.93),   SOUTH, "ANNEX"),
    ("Tank",      (-14.28, 2.4, -16.05), EAST,  "ANNEX"),
    ("Recorder",  (9.53, 2.2, -16.05),  WEST,  "ANNEX"),
    ("Library",   (-13.78, 2.2, -20.95), EAST,  "ANNEX"),
]

# C-1. One per chamber, on the schedule, dimmer-driven. Not fluorescent: these
# are the programme's own fittings and they are the oldest thing in the annex.
SCHEDULE_LAMPS = [
    ("ChamberA", (-5.0, 2.2, -20.58), NORTH, "CHAM_A"),
    ("ChamberB", (0.0, 2.2, -20.58),  NORTH, "CHAM_B"),
    ("ChamberC", (5.0, 2.2, -20.58),  NORTH, "CHAM_C"),
]

# How each space sounds, which is not decoration: the shelter is a municipal
# concrete box and the annex is a hole cut in rock, and the ear knows the
# difference before the eye does. One reverb on the SFX bus, driven by whichever
# zone the listener is in.
#
#   name,            centre,               half-extent,          size, damp, wet, predelay
REVERB = [
    ("Corridor",     (0.0, 1.3, 0.0),      (1.25, 1.3, 10.0),    0.58, 0.44, 0.34, 14.0),
    ("Plant",        (-5.15, 1.5, -4.0),   (3.5, 1.5, 3.5),      0.74, 0.34, 0.30, 30.0),
    ("Mess",         (-4.65, 1.3, 5.5),    (3.0, 1.3, 3.0),      0.46, 0.58, 0.22, 12.0),
    ("Vestibule",    (0.0, 1.3, 11.9),     (2.0, 1.3, 1.5),      0.34, 0.66, 0.18, 8.0),
    # Rock does not ring. Small, dead, and almost no predelay -- the walls are
    # where they sound like they are, which is very close.
    ("ObsCorridor",  (0.0, 1.3, OBS_Z),    (9.0, 1.3, 1.25),     0.40, 0.74, 0.20, 7.0),
    ("Chambers",     (0.0, 1.3, CHAMBER_Z), (7.0, 1.3, 1.5),     0.26, 0.80, 0.14, 5.0),
    # Except the tank room, which has a steel tank and standing water in it.
    ("TankRoom",     (TANK[0], 1.4, TANK[1]), (2.5, 1.4, 2.5),   0.62, 0.30, 0.42, 18.0),
    ("RecorderBay",  (11.9, 1.3, OBS_Z),   (2.5, 1.3, 2.5),      0.38, 0.70, 0.18, 9.0),
    ("TapeLibrary",  (TANK[0], 1.3, LIBRARY_Z), (2.0, 1.3, 2.0), 0.30, 0.82, 0.16, 6.0),
]

# Pages, in the rooms the people who wrote them would have left them.
READABLES = [
    ("StockingManifest", "d07", (-1.88, 1.55, 11.4), EAST),   # vestibule, west wall
    ("OccupancyNotice",  "d11", (1.88, 1.55, 12.3),  WEST),   # taped over the capacity sign
    ("RationCard",       "d08", (4.53, 1.5, -2.2),   WEST),   # store room, clear of the drums
    ("ServiceCard",      "d09", (-8.53, 1.5, -3.0),  EAST),   # plant room, wire frame
    ("OperatingCard",    "d09a", (-4.4, 1.78, -7.38), SOUTH), # inside the cabinet door
    ("PanelSchedule",    "d09b", (1.10, 1.95, -6.5),  WEST),  # in the panel door
    ("Postcard",         "d10", (5.6, 1.02, 3.4),    WEST),   # propped on the bunk shelf
    ("WorkUnitCover",    "d12", (-7.53, 1.45, 5.5),  EAST),   # mess, on the board over the table
    # The annex.
    ("Protocol4",        "d13", (-2.2, 1.5, -17.18),  SOUTH),  # framed at the observer station
    ("CamNotes",         "d16", (2.2, 1.5, -17.18),   SOUTH),  # beside the clock, in his hand
    ("AppendixC",        "d14", (14.28, 1.5, -15.2),  WEST),   # recorder bay
    ("QuarterlyReport",  "d15", (14.28, 1.5, -16.9),  WEST),   # recorder bay, her paperwork
    ("ChartTrace",       "d17", (11.9, 1.34, -14.52), NORTH),  # on the drum, where it stopped
    ("PhotometerLog",    "d18", (-1.38, 1.45, -19.2), EAST),   # chamber B, with the meter
    ("ReelIndex",        "d19", (-9.78, 1.5, -20.95), WEST),   # tape library
    ("AdmissionSheet",   "d20", (-11.9, 1.62, -22.83), SOUTH),  # filed above the shelf
]

# P3.4. Four hundred reels; the shelf shows the end of Run 9's block. The index
# gives the block, the admission sheet's amendment gives the day, and the boxing
# rule gives the name -- RF-0840 is the last of box C, which is "9-C".
REELS = [
    ("RF-0836", -1.35),
    ("RF-0837", -0.81),
    ("RF-0838", -0.27),
    ("RF-0839", 0.27),
    ("RF-0840", 0.81),
    ("RF-0841", 1.35),
]


# --- writing the scene ------------------------------------------------------

DOCS = {
    "d13": "d13_protocol_4", "d14": "d14_appendix_c", "d15": "d15_quarterly_report",
    "d16": "d16_cam_notes", "d17": "d17_chart_trace", "d18": "d18_photometer_log",
    "d19": "d19_reel_index", "d20": "d20_admission_sheet",
    "d07": "d07_stocking_manifest", "d08": "d08_ration_card",
    "d09": "d09_generator_card", "d09a": "operating_card",
    "d09b": "shelter_panel_schedule", "d10": "d10_postcard",
    "d11": "d11_occupancy_notice", "d12": "d12_work_unit_cover",
}

EXT = [
    ("Script", "res://src/world/kit/room_box.gd", "1_room"),
    ("Script", "res://src/world/kit/opening.gd", "2_open"),
    ("Script", "res://src/world/kit/slab_group.gd", "slab_group"),
    ("Material", "res://assets/materials/graybox_concrete.tres", "4_concrete"),
    ("Material", "res://assets/materials/graybox_steel.tres", "5_steel"),
    ("Material", "res://assets/materials/graybox_paint.tres", "6_paint"),
    ("Material", "res://assets/materials/graybox_silt.tres", "7_silt"),
    ("Material", "res://assets/materials/graybox_paper.tres", "7b_paper"),
    ("Script", "res://src/world/kit/slab.gd", "3_slab"),
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
    ("Resource", "res://assets/documents/built_end_card.tres", "20_card"),
    ("Script", "res://src/world/act2/light_seam.gd", "21_seam"),
    ("AudioStream", "res://assets/audio/amb_powerhouse.wav", "22_tone"),
    ("AudioStream", "res://assets/audio/mach_diesel.wav", "23_diesel"),
    ("AudioStream", "res://assets/audio/mach_crank.wav", "24_crank"),
    ("AudioStream", "res://assets/audio/mach_catch.wav", "25_catch"),
    ("AudioStream", "res://assets/audio/amb_annex.wav", "35_annexair"),
    ("AudioStream", "res://assets/audio/mach_tape.wav", "36_tape"),
    ("AudioStream", "res://assets/audio/click_cam.wav", "37_cam"),
    ("Script", "res://src/audio/occluder.gd", "26_occl"),
    ("PackedScene", "res://src/world/devices/device_intercom.tscn", "27_intercom"),
    ("PackedScene", "res://src/world/kit/fluorescent.tscn", "28_tube"),
    ("PackedScene", "res://src/world/puzzles/timeclock.tscn", "29_clock"),
    ("PackedScene", "res://src/world/devices/device_interlock.tscn", "30_interlock"),
    ("PackedScene", "res://src/world/tools/photometer.tscn", "31_meter"),
    ("Script", "res://src/render/grade_zone.gd", "32_grade"),
    ("Script", "res://src/world/act2/annex_logic.gd", "33_annex"),
    ("Script", "res://src/world/entity/observer.gd", "34_observer"),
]
EXT += [("Resource", "res://assets/documents/%s.tres" % f, "doc_%s" % k) for k, f in sorted(DOCS.items())]


def ext_id(path_fragment):
    for _, path, ident in EXT:
        if path_fragment in path:
            return ident
    raise KeyError(path_fragment)


def _doorways():
    """Every opening in the level, as sub-resources, grouped by the room that
    keeps the wall. A room omits the wall it shares; the room whose doorway it
    is builds it, which is the rule that stops coplanar surfaces fighting."""
    by_room = {}
    blocks = []
    index = 0
    everything = [("Corridor",) + door for door in DOORS] + list(ANNEX_DOORS)
    for room, wall, offset, width, height in everything:
        index += 1
        name = "Opening_%d" % index
        by_room.setdefault(room, []).append(name)
        blocks.append([
            '[sub_resource type="Resource" id="%s"]' % name,
            'script = ExtResource("2_open")',
            "wall = %d" % WALLS.index(wall),
            "offset = %s" % fmt(float(offset)),
            "width = %s" % fmt(float(width)),
            "height = %s" % fmt(float(height)),
            "sill = 0.0",
            "",
        ])
    return by_room, blocks


def build():
    lines = []
    doors_by_room, openings = _doorways()

    body = []
    body += ['[node name="Shelter" type="Node3D" groups=["act"]]', ""]

    # -- rooms
    for name, interior, at, omit, roofed in ROOMS:
        body.append('[node name="%s" type="Node3D" parent="."]' % name)
        body.append("transform = %s" % upright(at))
        body.append('script = ExtResource("1_room")')
        body.append("interior = Vector3(%s)" % ", ".join(fmt(float(v)) for v in interior))
        body.append("thickness = %s" % fmt(THICK))
        if name in doors_by_room:
            ids = ", ".join('SubResource("%s")' % o for o in doors_by_room[name])
            body.append('openings = Array[ExtResource("2_open")]([%s])' % ids)
        if omit:
            walls = ", ".join(str(WALLS.index(w)) for w in omit)
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

    body += _annex()
    body += _plant()
    body += _panel()
    body += _dressing()
    body += _intercom()
    body += _reverb()
    body += _pages()
    body += _ways_out()
    body += flush_boxes()
    return lines, openings, body


def _annex():
    """The programme's rooms: fittings, the observer station, and the tank."""
    out = ['[node name="Annex" type="Node3D" parent="."]', ""]

    for name, at, direction, circuit in TUBES:
        out.append('[node name="Tube%s" parent="Annex" instance=ExtResource("28_tube")]' % name)
        out.append("transform = %s" % t3(facing(direction, "+x"), at))
        out.append('circuit = &"%s"' % circuit)
        out.append("lit = false")
        out.append("")

    for name, at, direction, circuit in SCHEDULE_LAMPS:
        out.append('[node name="Lamp%s" parent="Annex" instance=ExtResource("8_lamp")]' % name)
        out.append("transform = %s" % t3(facing(direction, "+x"), at))
        out.append('circuit = &"%s"' % circuit)
        out.append("lit = false")
        out.append("energy = 2.6")
        # C-1 casts, and it is the only thing in the annex that does. The
        # entity's whole expression is the interruption of light.
        out.append("casts_shadow = true")
        # The chamber is three metres across. Anything past five is shadowing
        # rooms it does not light, six times a frame.
        out.append("reach = 5.0")
        out.append("")

    # The observer station. The bench is against the *south* wall, opposite the
    # equipment: on the north wall it stood squarely in chamber B's doorway,
    # which is where the run everybody cares about happened.
    out += box("ObsBench", (2.2, 0.06, 0.5), (0.0, 0.86, -15.05), ext_id("paint"), "Annex")
    for i, bx in enumerate([-1.0, 1.0]):
        out += box("ObsLeg%d" % (i + 1), (0.06, 0.84, 0.4),
                   (bx, 0.42, -15.05), ext_id("steel"), "Annex")

    out.append('[node name="Timeclock" parent="Annex" instance=ExtResource("29_clock")]')
    out.append("transform = %s" % t3(facing(SOUTH), (1.0, 1.45, -17.2)))
    out.append('save_key = &"timeclock"')
    out.append("")
    out.append('[node name="Detent" type="AudioStreamPlayer3D" parent="Annex/Timeclock"]')
    out.append('stream = ExtResource("37_cam")')
    out.append("volume_db = -8.0")
    out.append('bus = &"SFX"')
    out.append("unit_size = 2.2")
    out.append("max_db = 0.0")
    out.append("")

    out.append('[node name="Interlock" parent="Annex" instance=ExtResource("30_interlock")]')
    out.append("transform = %s" % t3(facing(SOUTH), (-1.0, 1.45, -17.2)))
    out.append('save_key = &"interlock"')
    out.append("")

    # C-6, in chamber B, which is where the last run was.
    out.append('[node name="Photometer" parent="Annex" instance=ExtResource("31_meter")]')
    out.append("transform = %s" % t3(facing(SOUTH), (0.7, 0.95, -19.6)))
    out.append("")
    out += box("ChamberBench", (1.2, 0.06, 0.5), (0.7, 0.9, -19.6), ext_id("paint"), "Annex")
    for i, bx in enumerate([-0.5, 0.5]):
        out += box("ChamberLeg%d" % (i + 1), (0.05, 0.88, 0.4),
                   (0.7 + bx, 0.44, -19.6), ext_id("steel"), "Annex")

    # C-5, the immersion tank -- 8 ft by 4 ft on the equipment schedule -- which
    # by 1998 is a reservoir. Set against the room's west side so there is floor
    # to walk round it on: at 3.4 m in a 5 m room the first capture put the
    # camera flat against its side with nowhere to stand.
    out += box("TankShell", (2.4, 1.3, 1.8), (-12.6, 0.65, -16.05), ext_id("steel"), "Annex")
    out += box("TankLid", (2.5, 0.08, 1.9), (-12.6, 1.34, -16.05), ext_id("paint"), "Annex")
    out += box("TankStand", (2.5, 0.12, 1.9), (-12.6, 0.06, -16.05), ext_id("concrete"), "Annex")
    out.append('[node name="TankDrain" parent="Annex" instance=ExtResource("13_toggle")]')
    out.append("transform = %s" % t3(facing(EAST), (-11.15, 1.2, -16.05)))
    out.append('save_key = &"tank_drain"')
    out.append('label = "TANK DRAIN"')
    out.append("on = false")
    out.append('prompt_when_on = "Shut the drain"')
    out.append('prompt_when_off = "Open the drain"')
    out.append("")

    # And the water that is over the sill until P3.3 takes a load off the set.
    out += solo_box("TankWater", (4.9, 0.5, 4.9), (-11.9, 0.25, -16.05),
                    ext_id("silt"), "Annex", solid=False)

    # C-4, the chart recorder, with Run 9 day 31 still on the drum.
    out += box("RecorderRack", (1.6, 1.1, 0.5), (11.9, 0.55, -14.3), ext_id("paint"), "Annex")
    out += box("RecorderDrum", (1.3, 0.34, 0.34), (11.9, 1.22, -14.3), ext_id("steel"), "Annex")

    # C-8, the tape library. Four hundred reels; six of them are the end of
    # Run 9's block, and one of those is the last thing anybody recorded here.
    out += box("ReelShelf", (3.6, 0.06, 0.4), (-11.9, 1.3, -22.4), ext_id("steel"), "Annex")
    out += box("ReelShelfLower", (3.6, 0.06, 0.4), (-11.9, 0.9, -22.4), ext_id("steel"), "Annex")
    out += ['[node name="Reels" type="Node3D" parent="Annex"]', ""]
    for accession, offset in REELS:
        out.append('[node name="%s" parent="Annex/Reels" instance=ExtResource("14_push")]'
                   % accession.replace("-", ""))
        out.append("transform = %s" % t3(facing(SOUTH), (-11.9 + offset, 1.44, -22.3)))
        out.append('label = "%s"' % accession)
        out.append('prompt = "Take reel %s"' % accession)
        out.append("")

    # Where the sodium stops and the programme begins.
    out.append('[node name="GradeThreshold" type="Area3D" parent="Annex"]')
    out.append("transform = %s" % upright((0.0, 1.3, -18.0)))
    out.append("collision_layer = 0")
    out.append("collision_mask = 2")
    out.append('script = ExtResource("32_grade")')
    out.append('grade = &"annex"')
    out.append("")
    out.append('[node name="Shape" type="CollisionShape3D" parent="Annex/GradeThreshold"]')
    out.append('shape = SubResource("BoxShape3D_annex")')
    out.append("")

    # The annex has its own air: a hole in rock rather than a room in a
    # building, so it is deader and lower than the shelter's.
    out.append('[node name="Air" type="AudioStreamPlayer3D" parent="Annex"]')
    out.append("transform = %s" % upright((0.0, 1.6, -17.0)))
    out.append('stream = ExtResource("35_annexair")')
    out.append("volume_db = -17.0")
    out.append('bus = &"SFX"')
    out.append("unit_size = 18.0")
    out.append("max_db = 0.0")
    out.append("autoplay = true")
    out.append("")

    # C-8. Four hundred reels, and the one transport somebody left threaded.
    out.append('[node name="TapeDeck" type="AudioStreamPlayer3D" parent="Annex"]')
    out.append("transform = %s" % upright((-11.9, 1.4, -21.6)))
    out.append('stream = ExtResource("36_tape")')
    out.append("volume_db = -15.0")
    out.append('bus = &"SFX"')
    out.append("unit_size = 5.0")
    out.append("max_db = 0.0")
    out.append("autoplay = true")
    out.append("")
    out.append('[node name="Occluder" type="Node" parent="Annex/TapeDeck"]')
    out.append('script = ExtResource("26_occl")')
    out.append("")

    # The entity, which has a rule and no act until now.
    out.append('[node name="Observer" type="Node3D" parent="Annex" groups=["observer"]]')
    out.append("transform = %s" % upright((0.0, 0.0, -16.05)))
    out.append('script = ExtResource("34_observer")')
    out.append("")
    out.append('[node name="Body" type="MeshInstance3D" parent="Annex/Observer"]')
    out.append("")

    out.append('[node name="Logic" type="Node" parent="Annex" groups=["saveable"]]')
    out.append('script = ExtResource("33_annex")')
    out.append('save_key = &"act3"')
    out.append("")
    return out


def _plant():
    """The set, its fuel, and the three controls the act turns on."""
    out = ['[node name="Plant" type="Node3D" parent="."]', ""]
    # The set itself: a block on a housekeeping pad, against the plant room's
    # north wall. It is scenery -- everything the player touches is on the wall
    # beside it, which is where a 1962 set put its controls.
    out += box("Pad", (3.0, 0.15, 1.8), (-6.2, 0.07, -5.9), ext_id("concrete"), "Plant")
    out += box("Set", (2.6, 1.4, 1.4), (-6.2, 0.85, -5.9), ext_id("paint"), "Plant")
    out += box("Exhaust", (0.24, 1.9, 0.24), (-7.3, 1.9, -6.5), ext_id("steel"), "Plant")
    # High enough that it is not in front of its own isolating valve. A day
    # tank sits above the engine and the valve sits under the tank, which is
    # both correct and the only arrangement you can actually reach.
    out += box("DayTank", (0.8, 0.7, 0.6), (-8.1, 2.05, -2.6), ext_id("steel"), "Plant")
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

    # The set's own voice, at the set. Three players rather than one because a
    # loop and two one-shots want different settings, and because the running
    # loop has to be able to start while a one-shot is still finishing.
    for node, stream, loud, autoplay in [
        ("Diesel", "23_diesel", -6.0, False),
        ("Crank", "24_crank", -9.0, False),
        ("Catch", "25_catch", -8.0, False),
    ]:
        out.append('[node name="%s" type="AudioStreamPlayer3D" parent="Plant"]' % node)
        out.append("transform = %s" % upright((-6.2, 1.2, -5.9)))
        out.append('stream = ExtResource("%s")' % stream)
        out.append("volume_db = %s" % fmt(loud))
        out.append('bus = &"SFX"')
        out.append("unit_size = 7.0")
        out.append("max_db = 0.0")
        if autoplay:
            out.append("autoplay = true")
        out.append("")
        out.append('[node name="Occluder" type="Node" parent="Plant/%s"]' % node)
        out.append('script = ExtResource("26_occl")')
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

    # Bunk room: two frames, one made up, one stripped to the springs. The legs
    # are not detail for its own sake -- a bunk without them floats, which the
    # first capture showed plainly.
    for i, z in enumerate([3.4, 6.4]):
        for j, (lx, lz) in enumerate([(-0.4, -0.85), (0.4, -0.85), (-0.4, 0.85), (0.4, 0.85)]):
            out += box("BunkLeg%d%d" % (i + 1, j + 1), (0.05, 0.5, 0.05),
                       (5.6 + lx, 0.25, z + lz), ext_id("steel"), "Dressing")
    out += box("BunkMadeFrame", (0.9, 0.1, 1.9), (5.6, 0.55, 3.4), ext_id("steel"), "Dressing")
    out += box("BunkMade", (0.86, 0.16, 1.8), (5.6, 0.68, 3.4), ext_id("paper"), "Dressing")
    out += box("BunkMadeShelf", (0.34, 0.05, 0.5), (5.6, 0.9, 3.4), ext_id("steel"), "Dressing")
    out += box("BunkStripped", (0.9, 0.1, 1.9), (5.6, 0.55, 6.4), ext_id("steel"), "Dressing")
    out += box("BunkStrippedRail", (0.05, 0.55, 1.9), (5.16, 0.85, 6.4), ext_id("steel"), "Dressing")

    # Store room: water drums and the ration cartons, rotated front to back.
    for i in range(4):
        out += box("Drum%d" % (i + 1), (0.56, 0.86, 0.56),
                   (2.1 + (i % 2) * 0.66, 0.43, -4.4 + (i // 2) * 0.66),
                   ext_id("steel"), "Dressing")
    out += box("Shelf", (2.6, 0.06, 0.5), (3.15, 1.2, -1.6), ext_id("steel"), "Dressing")
    for i, sx in enumerate([-1.25, 1.25]):
        out += box("ShelfBracket%d" % (i + 1), (0.05, 1.2, 0.45),
                   (3.15 + sx, 0.6, -1.6), ext_id("steel"), "Dressing")
    for i in range(5):
        out += box("Carton%d" % (i + 1), (0.4, 0.3, 0.4), (2.1 + i * 0.45, 1.38, -1.6),
                   ext_id("paint"), "Dressing")

    # Mess: a table, a chair, one place set. Not two.
    out += box("MessTable", (1.6, 0.06, 0.8), (-4.65, 0.74, 5.5), ext_id("paint"), "Dressing")
    for i, (lx, lz) in enumerate([(-0.72, -0.34), (0.72, -0.34), (-0.72, 0.34), (0.72, 0.34)]):
        out += box("MessLeg%d" % (i + 1), (0.06, 0.71, 0.06),
                   (-4.65 + lx, 0.355, 5.5 + lz), ext_id("steel"), "Dressing")
    out += box("MessChair", (0.42, 0.05, 0.42), (-4.65, 0.46, 6.4), ext_id("paint"), "Dressing")
    out += box("MessChairBack", (0.42, 0.44, 0.05), (-4.65, 0.7, 6.6), ext_id("paint"), "Dressing")
    for i, (lx, lz) in enumerate([(-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)]):
        out += box("ChairLeg%d" % (i + 1), (0.04, 0.44, 0.04),
                   (-4.65 + lx, 0.22, 6.4 + lz), ext_id("steel"), "Dressing")
    # One place set. Not two.
    out += box("MessMug", (0.09, 0.1, 0.09), (-4.35, 0.82, 5.5), ext_id("paint"), "Dressing")

    # Plant room: the cable Emil taped down so nobody trips on it, which is the
    # S1 beat that lands earliest -- a hazard fixed rather than ignored.
    out += box("TapedCable", (2.2, 0.05, 0.09), (-7.0, 0.02, -2.0), ext_id("steel"), "Dressing")
    out += box("CableTape1", (0.12, 0.06, 0.13), (-7.9, 0.03, -2.0), ext_id("paper"), "Dressing")
    out += box("CableTape2", (0.12, 0.06, 0.13), (-6.1, 0.03, -2.0), ext_id("paper"), "Dressing")
    return out


# Four sentences. He does not ask a question and does not answer one, because
# Protocol 4.3 says the observer shall not speak except on the schedule, and he
# has followed that line for thirty-four years. What makes it frightening is
# that it is punctual. See STORY.md, plot-hole audit question 9.
EMIL_LINES = [
    "Bus is up. That's the set carrying, not the station.",
    "You'll want the heater off. It's nine kilowatts and it isn't cold yet.",
    "There's food in the store room. The cycle card is on the door.",
    "Schedule says twenty-two hundred. I'll not speak again before then.",
]


def _intercom():
    """C-3, on the mess wall, where a 1964 retrofit would have put it."""
    out = ['[node name="Intercom" parent="." instance=ExtResource("27_intercom")]']
    out.append("transform = %s" % t3(facing(SOUTH), (-4.65, 1.5, 2.62)))
    out.append('save_key = &"intercom"')
    out.append('lines = Array[String]([%s])'
               % ", ".join('"%s"' % line.replace('"', '\\"') for line in EMIL_LINES))
    out.append("")
    return out


def _reverb():
    out = ['[node name="Reverb" type="Node3D" parent="."]', ""]
    for name, at, half, size, damp, wet, predelay in REVERB:
        out.append('[node name="%s" type="Area3D" parent="Reverb"]' % name)
        out.append("transform = %s" % upright(at))
        out.append("collision_layer = 0")
        out.append("collision_mask = 2")
        out.append('script = ExtResource("11_verb")')
        out.append("room_size = %s" % fmt(size))
        out.append("damping = %s" % fmt(damp))
        out.append("wet = %s" % fmt(wet))
        out.append("predelay_msec = %s" % fmt(predelay))
        out.append("")
        out.append('[node name="Shape" type="CollisionShape3D" parent="Reverb/%s"]' % name)
        out.append('shape = SubResource("BoxShape3D_verb_%s")' % name)
        out.append("")
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
    out += solo_box("StairWater", (2.9, 0.34, 3.9), (0.0, 0.17, -12.4), ext_id("silt"), ".", solid=False)

    out.append('[node name="Logic" type="Node" parent="." groups=["saveable", "act_logic"]]')
    out.append('script = ExtResource("18_logic")')
    out.append('save_key = &"act2"')
    out.append("")

    out.append('[node name="Seam" type="Node3D" parent="." groups=["saveable"]]')
    out.append("transform = %s" % upright((-1.2, 1.3, 2.0)))
    out.append('script = ExtResource("21_seam")')
    out.append('save_key = &"seam"')
    out.append("")

    # No trigger volume: Act 3 ends with a reel in your hand, and AnnexLogic is
    # what knows that. The volume this used to be sat at the annex door, which
    # is now the middle of the observation corridor -- walking into Act 3 ended
    # the game, which the first capture of the annex showed immediately.
    out.append('[node name="ActEnd" type="Area3D" parent="." groups=["act_end"]]')
    out.append("transform = %s" % upright((0.0, -40.0, 0.0)))
    out.append("collision_layer = 0")
    out.append("collision_mask = 0")
    out.append("monitoring = false")
    out.append('script = ExtResource("19_end")')
    out.append('card = ExtResource("20_card")')
    out.append("return_to = Vector3(0, 0.1, -11.0)")
    # Act 3 hands back to Act 1. The way out is up the pier stair from the
    # gallery, which the player walked in the dark in Act 1 and did not look at.
    out.append("next_act = 0")
    out.append("arrive_at = Vector3(9.9, -3.8, 16)")
    out.append("arrive_facing = -90.0")
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
    # Wide and deep enough to cover the whole annex, so the palette belongs to
    # the building rather than to a doorway the player might sidestep.
    for name, _at, half, _s, _d, _w, _p in REVERB:
        out.append('[sub_resource type="BoxShape3D" id="BoxShape3D_verb_%s"]' % name)
        out.append("size = Vector3(%s)" % ", ".join(fmt(v * 2.0) for v in half))
        out.append("")
    out.append('[sub_resource type="BoxShape3D" id="BoxShape3D_annex"]')
    out.append("size = Vector3(30.0, 3.4, 10.0)")
    out.append("")
    return out


if __name__ == "__main__":
    main()
