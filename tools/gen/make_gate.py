#!/usr/bin/env python3
"""Write src/world/act1/gate.tscn -- Act 4, in Act 1's coordinate space.

Act 4 is rooms added to Act 1 rather than an act of its own, for the same reason
Act 3 is rooms added to Act 2 (DECISIONS.md D28 and D29): P4.1 and P4.2 are in
Act 1's gallery, and the gallery is where they belong. The player comes back
down through the shelter and out the way they came in, which is a walk, and the
walk is the point.

Kept in its own scene and instanced into `powerhouse.tscn` rather than appended
to it, so regenerating Act 4 cannot damage Act 1 and one line of Act 1's scene
file is all that changes.

Act 1's gallery: interior 3 x 2.6 x 20 at (9.9, -3.9, 18.4), so
    x 8.4 .. 11.4     y -3.9 .. -1.3     z 8.4 .. 28.4
and everything here hangs off its east side.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tscn import WALLS, EAST, WEST, NORTH, SOUTH, box, facing, fmt, t3, upright  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[2] / "src/world/act1/gate.tscn"

THICK = 0.4

# The gallery, for reference -- not built here, it is Act 1's.
GALLERY = dict(x=(8.4, 11.4), y=(-3.9, -1.3), z=(8.4, 28.4))

# The stair shaft climbs from gallery level to the pier deck. Its west wall is
# the gallery's east wall, so the gallery keeps that wall and this omits it.
SHAFT_X = GALLERY["x"][1] + THICK + 1.5      # centre, 3 m wide
SHAFT_Z = 13.0
GALLERY_FLOOR = -3.9

# Fifteen steps at 0.3 rise is 4.5 m, which is the climb, and at 0.315 tread is
# 4.7 m of run in an 8 m shaft. The stair descends along +Z from its top nosing.
STEPS = 15
RISE = 0.3
TREAD = 0.315
DECK_Y = GALLERY_FLOOR + STEPS * RISE        # 0.6
STAIR_TOP_Z = 9.6

# The way in from the gallery, at the *bottom* of the shaft and clear of the
# stair's foot -- a doorway under a flight of stairs is a doorway into a ceiling.
GALLERY_DOOR_Z = 16.0

ROOMS = [
    # name,          interior,           at,                            omit,      floored, roofed
    ("PierStair",    (3.0, 4.5, 8.0),    (SHAFT_X, GALLERY_FLOOR, SHAFT_Z), ["WEST"], True,  False),
    ("PierDeck",     (3.0, 3.0, 8.0),    (SHAFT_X, DECK_Y, SHAFT_Z),    [],        False, True),
    ("ControlHouse", (4.5, 2.8, 4.5),    (SHAFT_X, DECK_Y, 19.65),      ["NORTH"], True,  True),
]

DOORS = [
    ("PierDeck", "SOUTH", 0.0, 1.1, 2.1),     # out to the control house
]

# Act 1's gallery needs one more hole in its east wall. Offsets on an east wall
# run along z from the room's own centre, and the gallery's centre is z 18.4.
GALLERY_DOOR = ("EAST", GALLERY_DOOR_Z - 18.4, 1.1, 2.1)


# --- what is in them --------------------------------------------------------

# P4.1 and P4.2 live in the gallery, on its east wall, beside the new doorway.
GALLERY_WALL_X = GALLERY["x"][1] - 0.12
PANEL_Z = 13.6
BENCH_Z = 15.0

LAMPS = [
    ("PierStair", (11.93, -1.4, 15.6), EAST, "LT-4"),
    ("PierDeck",  (11.93, 2.6, 11.0),  EAST, "LT-4"),
    ("ControlHouse", (11.18, 2.2, 19.65), EAST, "LT-4"),
    ("Gallery",   (11.28, -2.0, 14.4), WEST, "LT-4"),
]

READABLES = [
    # On the box itself, not on the wall: he labelled the thing, not the room.
    ("BenchLabel",   "d21", (GALLERY_WALL_X - 0.51, -2.44, BENCH_Z), WEST),
    ("StageRecord",  "d22", (GALLERY_WALL_X, -2.0, 12.2),     WEST),
    ("FinalTape",    "d24", (SHAFT_X - 1.3, 1.55, 20.9),      EAST),
]

DOCS = {
    "d21": "d21_bench_label",
    "d22": "d22_stage_record",
    "d24": "d24_reel_9c",
    "end_a": "ending_a_card",
    "end_b": "ending_b_card",
}

EXT = [
    ("Script", "res://src/world/kit/room_box.gd", "1_room"),
    ("Script", "res://src/world/kit/opening.gd", "2_open"),
    ("Script", "res://src/world/kit/slab.gd", "3_slab"),
    ("Script", "res://src/world/kit/stair_run.gd", "4_stair"),
    ("Material", "res://assets/materials/graybox_concrete.tres", "5_concrete"),
    ("Material", "res://assets/materials/graybox_steel.tres", "6_steel"),
    ("Material", "res://assets/materials/graybox_paint.tres", "7_paint"),
    ("PackedScene", "res://src/world/kit/bulkhead_lamp.tscn", "8_lamp"),
    ("Script", "res://src/world/surface_tag.gd", "9_tag"),
    ("Resource", "res://assets/surfaces/concrete.tres", "10_surface"),
    ("Resource", "res://assets/surfaces/grating.tres", "11_grating"),
    ("PackedScene", "res://src/world/readable.tscn", "12_page"),
    ("PackedScene", "res://src/world/devices/device_toggle.tscn", "13_toggle"),
    ("PackedScene", "res://src/world/devices/device_push.tscn", "14_push"),
    ("PackedScene", "res://src/world/devices/device_door.tscn", "15_door"),
    ("PackedScene", "res://src/world/devices/device_gauge.tscn", "16_gauge"),
    ("PackedScene", "res://src/world/devices/device_interlock.tscn", "17_interlock"),
    ("Script", "res://src/world/act1/gate_logic.gd", "18_logic"),
    ("Script", "res://src/world/act1/act_end.gd", "19_end"),
]
EXT += [("Resource", "res://assets/documents/%s.tres" % f, "doc_%s" % k) for k, f in sorted(DOCS.items())]


def ext_id(fragment):
    for _, path, ident in EXT:
        if fragment in path:
            return ident
    raise KeyError(fragment)


def _head(openings):
    out = ['[gd_scene load_steps=%d format=3]' % (len(EXT) + len(openings) + 1), ""]
    for kind, path, ident in EXT:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, ident))
    out.append("")
    return out


def _rooms(doors_by_room):
    out = []
    for name, interior, at, omit, floored, roofed in ROOMS:
        out.append('[node name="%s" type="Node3D" parent="."]' % name)
        out.append("transform = %s" % upright(at))
        out.append('script = ExtResource("1_room")')
        out.append("interior = Vector3(%s)" % ", ".join(fmt(float(v)) for v in interior))
        out.append("thickness = %s" % fmt(THICK))
        if name in doors_by_room:
            ids = ", ".join('SubResource("%s")' % o for o in doors_by_room[name])
            out.append('openings = Array[ExtResource("2_open")]([%s])' % ids)
        if omit:
            out.append("omit_walls = Array[int]([%s])"
                       % ", ".join(str(WALLS.index(w)) for w in omit))
        out.append('wall_material = ExtResource("5_concrete")')
        out.append('floor_material = ExtResource("5_concrete")')
        if not floored:
            out.append("floored = false")
        if not roofed:
            out.append("roofed = false")
        out.append("")
        out.append('[node name="Surface" type="Node" parent="%s"]' % name)
        out.append('script = ExtResource("9_tag")')
        out.append('surface = ExtResource("10_surface")')
        out.append("")
    return out


def _stair():
    """One flight, landing exactly on the gallery floor."""
    out = ['[node name="StairRun" type="Node3D" parent="."]']
    out.append("transform = %s" % upright((SHAFT_X, DECK_Y, STAIR_TOP_Z)))
    out.append('script = ExtResource("4_stair")')
    out.append("steps = %d" % STEPS)
    out.append("rise = %s" % fmt(RISE))
    out.append("tread = %s" % fmt(TREAD))
    out.append("width = 1.4")
    out.append('material = ExtResource("6_steel")')
    out.append("")
    out.append('[node name="Surface" type="Node" parent="StairRun"]')
    out.append('script = ExtResource("9_tag")')
    out.append('surface = ExtResource("11_grating")')
    out.append("")
    return out


def _gallery():
    """P4.1 and P4.2, on the gallery's east wall where the design puts them."""
    out = ['[node name="Gallery" type="Node3D" parent="."]', ""]

    # The 1954 flood-response relay panel. It is not a puzzle: it is a thing to
    # read, and what it says is that the sequence is held by a number.
    out += box("RelayPanel", (0.1, 1.2, 1.4), (GALLERY_WALL_X + 0.06, -2.6, PANEL_Z),
               ext_id("paint"), "Gallery")
    out.append('[node name="StageGauge" parent="Gallery" instance=ExtResource("16_gauge")]')
    out.append("transform = %s" % t3(facing(WEST), (GALLERY_WALL_X, -2.3, PANEL_Z + 0.3)))
    out.append('save_key = &"stage_gauge"')
    out.append('units = "FT"')
    out.append("maximum = 40.0")
    out.append("")

    # The latch lamp: lit while the sequence is held. It is an indicator and not
    # a light, so it is a toggle whose handle happens to be a lens.
    out.append('[node name="SeqHeld" parent="Gallery" instance=ExtResource("13_toggle")]')
    out.append("transform = %s" % t3(facing(WEST), (GALLERY_WALL_X, -2.3, PANEL_Z - 0.4)))
    out.append('save_key = &"seq_held"')
    out.append('label = "SEQ HELD"')
    out.append("on = true")
    out.append("available = false")
    out.append("")

    # C-11: the box somebody built. Not on Appendix C, because it is not the
    # programme's -- it is one man's, made on a bench, in a week.
    out += box("BenchShelf", (0.42, 0.05, 0.9), (GALLERY_WALL_X - 0.2, -2.6, BENCH_Z),
               ext_id("steel"), "Gallery")
    out += box("BenchUnit", (0.3, 0.24, 0.5), (GALLERY_WALL_X - 0.22, -2.44, BENCH_Z),
               ext_id("paint"), "Gallery")
    out.append('[node name="BenchLead" parent="Gallery" instance=ExtResource("13_toggle")]')
    out.append("transform = %s" % t3(facing(WEST), (GALLERY_WALL_X, -2.3, BENCH_Z + 0.8)))
    out.append('save_key = &"bench_lead"')
    out.append('label = "XMTR SUBSTITUTE"')
    out.append("on = true")
    out.append('prompt_when_on = "Pull the lead"')
    out.append('prompt_when_off = "Put the lead back"')
    out.append("")
    return out


def _control_house():
    """The 1954 desk, and the third channel Emil retrofitted in 1966."""
    out = ['[node name="House" type="Node3D" parent="."]', ""]
    out += box("Desk", (2.6, 0.08, 0.7), (SHAFT_X, 0.6 + 0.86, 19.0), ext_id("paint"), "House")
    for i, dx in enumerate([-1.2, 1.2]):
        out += box("DeskLeg%d" % (i + 1), (0.06, 0.86, 0.6),
                   (SHAFT_X + dx, 0.6 + 0.43, 19.0), ext_id("steel"), "House")
    out += box("Cabinet", (1.1, 1.9, 0.4), (SHAFT_X + 1.3, 0.6 + 0.95, 21.5),
               ext_id("paint"), "House")

    # P4.3. The latch resets with a key, and the key is captive.
    out.append('[node name="Interlock" parent="House" instance=ExtResource("17_interlock")]')
    out.append("transform = %s" % t3(facing(NORTH), (SHAFT_X, 1.55, 21.6)))
    out.append('save_key = &"house_interlock"')
    out.append('channels = Array[StringName]([&"RUN"])')
    out.append("")

    out.append('[node name="LatchReset" parent="House" instance=ExtResource("14_push")]')
    out.append("transform = %s" % t3(facing(NORTH), (SHAFT_X - 0.7, 1.5, 21.75)))
    out.append('label = "SEQ RESET"')
    out.append('prompt = "Reset the sequence"')
    out.append("")
    return out


def _pier():
    """Ending B: the hydraulic power unit, which works when nothing else does."""
    out = ['[node name="Pier" type="Node3D" parent="."]', ""]
    out += box("HpuSkid", (1.6, 0.9, 1.0), (SHAFT_X, 1.05, 10.4), ext_id("steel"), "Pier")
    out += box("HpuMotor", (0.5, 0.5, 0.5), (SHAFT_X - 0.4, 1.75, 10.4), ext_id("paint"), "Pier")
    out.append('[node name="HandPump" parent="Pier" instance=ExtResource("13_toggle")]')
    out.append("transform = %s" % t3(facing(SOUTH), (SHAFT_X + 0.45, 1.6, 10.95)))
    out.append('save_key = &"hand_pump"')
    out.append('label = "GATE PERMISSIVE — LOCAL"')
    out.append("on = true")
    out.append('prompt_when_on = "Take the gate off its permissive"')
    out.append('prompt_when_off = "Put the permissive back"')
    out.append("")
    return out


def _lamps_and_pages():
    out = ['[node name="Lamps" type="Node3D" parent="."]', ""]
    for name, at, direction, circuit in LAMPS:
        out.append('[node name="%s" parent="Lamps" instance=ExtResource("8_lamp")]' % name)
        out.append("transform = %s" % t3(facing(direction, "+x"), at))
        out.append('circuit = &"%s"' % circuit)
        out.append("lit = false")
        out.append("")

    out += ['[node name="Readables" type="Node3D" parent="."]', ""]
    for name, key, at, direction in READABLES:
        out.append('[node name="%s" parent="Readables" instance=ExtResource("12_page")]' % name)
        out.append("transform = %s" % t3(facing(direction), at))
        out.append('document = ExtResource("doc_%s")' % key)
        out.append("")
    return out


def _logic():
    out = ['[node name="Logic" type="Node" parent="." groups=["saveable"]]']
    out.append('script = ExtResource("18_logic")')
    out.append('save_key = &"act4"')
    out.append("")

    # One card per ending, and no trigger volume for either: an ending is a
    # thing the player did with equipment, and `GateLogic` is what knows which.
    for name, doc in [("EndingA", "end_a"), ("EndingB", "end_b")]:
        out.append('[node name="%s" type="Area3D" parent="." groups=["act_end"]]' % name)
        out.append("transform = %s" % upright((SHAFT_X, -40.0, 0.0)))
        out.append("collision_layer = 0")
        out.append("collision_mask = 0")
        out.append("monitoring = false")
        out.append('script = ExtResource("19_end")')
        out.append('card = ExtResource("doc_%s")' % doc)
        out.append("fade_seconds = 3.4")
        out.append("return_to = Vector3(%s, %s, 11)" % (fmt(SHAFT_X), fmt(DECK_Y + 0.1)))
        out.append("")
    return out


def main():
    openings = []
    by_room = {}
    for index, (room, wall, offset, width, height) in enumerate(DOORS, start=1):
        name = "Opening_%d" % index
        by_room.setdefault(room, []).append(name)
        openings.append("\n".join([
            '[sub_resource type="Resource" id="%s"]' % name,
            'script = ExtResource("2_open")',
            "wall = %d" % WALLS.index(wall),
            "offset = %s" % fmt(float(offset)),
            "width = %s" % fmt(float(width)),
            "height = %s" % fmt(float(height)),
            "sill = 0.0",
            "",
        ]))

    body = ['[node name="Gate" type="Node3D"]', ""]
    body += _rooms(by_room)
    body += _stair()
    body += _gallery()
    body += _pier()
    body += _control_house()
    body += _lamps_and_pages()
    body += _logic()

    text = "\n".join(_head(openings)) + "\n".join(openings) + "\n".join(body) + "\n"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text)
    print("wrote %s (%d lines)" % (OUT, text.count("\n")))


if __name__ == "__main__":
    raise SystemExit(main())
