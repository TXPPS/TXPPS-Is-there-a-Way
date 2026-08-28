#!/usr/bin/env python3
"""Writing Godot scene files, for the level generators.

Shared by `make_shelter.py` and `make_gate.py`, and in one place for exactly one
reason: `facing()`. A `.tscn` stores a Transform3D as the basis **rows**, and
the axes everybody reasons about are its *columns*, so writing the axes in order
gives the transpose -- which for a rotation is its inverse, and hangs every prop
in the building facing backwards.

That has now happened twice, in two generators, the second time in a function
whose comment claimed to be avoiding it. There is one of them now.
"""

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


WALLS = ["NORTH", "SOUTH", "WEST", "EAST"]


# Dressing accumulates instead of emitting, and is flushed as one node per
# (parent, material, solid). One MeshInstance3D per prop cost more draw calls
# than the rooms did; a hundred boxes that draw once cost one.
_PILES = {}


def box(name, size, at, material, parent=".", solid=True):
    """Remember a box. Emits nothing -- `flush_boxes` does that."""
    key = (parent, material, bool(solid))
    _PILES.setdefault(key, {"names": [], "sizes": [], "positions": []})
    pile = _PILES[key]
    pile["names"].append(name)
    pile["sizes"].append(tuple(float(v) for v in size))
    pile["positions"].append(tuple(float(v) for v in at))
    return []


def solo_box(name, size, at, material, parent=".", solid=True, script="3_slab"):
    """A box that keeps its own node, because something addresses it by name.

    Almost nothing needs this. Dressing does not: nobody ever looks up a
    ration carton. State does -- the water over the annex stair is shown and
    hidden by `ShelterLogic`, and a merged pile has no handle for that.
    """
    return [
        '[node name="%s" type="Node3D" parent="%s"]' % (name, parent),
        "transform = %s" % upright(at),
        'script = ExtResource("%s")' % script,
        "size = Vector3(%s)" % ", ".join(fmt(float(v)) for v in size),
        'material = ExtResource("%s")' % material,
        "solid = %s" % ("true" if solid else "false"),
        "",
    ]


def flush_boxes():
    """Every pile, as one SlabGroup each. Call once, at the end of a build."""
    out = []
    for index, (key, pile) in enumerate(sorted(_PILES.items(), key=lambda kv: str(kv[0])), start=1):
        parent, material, solid = key
        # Named after the first thing in it, so a node in the tree still says
        # what it is rather than "Group3".
        name = "%s_%d" % (pile["names"][0], index)
        out.append('[node name="%s" type="Node3D" parent="%s"]' % (name, parent))
        out.append('script = ExtResource("slab_group")')
        out.append("sizes = PackedVector3Array(%s)"
                   % ", ".join(fmt(v) for triple in pile["sizes"] for v in triple))
        out.append("positions = PackedVector3Array(%s)"
                   % ", ".join(fmt(v) for triple in pile["positions"] for v in triple))
        out.append('material = ExtResource("%s")' % material)
        if not solid:
            out.append("solid = false")
        out.append("")
    _PILES.clear()
    return out
