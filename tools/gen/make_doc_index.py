#!/usr/bin/env python3
"""Write assets/documents/index.tres -- every document in the game, in order.

The journal saves the *ids* of what the player has read, because ids are small
and stable and a save should not carry a copy of the text. Which means that
after a reload the journal knows twenty-nine ids and cannot show a single one of
them, and a game whose whole design is that reading the documents is how you get
out ought to let you read them twice.

So: an index, generated from what is actually on disk, and checked by the suite
against what is actually on disk. A document that exists and is not in here is a
document the player can find and then lose.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOCS = ROOT / "assets/documents"
OUT = DOCS / "index.tres"

# Story order, not filename order: the acts, then the equipment paperwork that
# hangs off them, then the cards. A player looking for the thing they read an
# hour ago is looking for it where they read it.
ORDER = [
    "d01", "d02", "d03", "d04", "panel_schedule", "d05", "d06",
    "d07", "d08", "d09", "operating_card", "shelter_panel_schedule",
    "d10", "d11", "d12",
    "d13", "d14", "d15", "d16", "d17", "d18", "d19", "d20",
    "d21", "d22", "d24",
]


def _id_of(path):
    found = re.search(r'^id = &"([^"]+)"', path.read_text(), re.M)
    return found.group(1) if found else ""


def main():
    files = sorted(p for p in DOCS.glob("*.tres") if p.name != "index.tres")
    # Cards are not documents: nobody wrote them and nobody left them anywhere.
    story = [p for p in files if not p.stem.endswith("_card")]

    def rank(path):
        for i, prefix in enumerate(ORDER):
            if path.stem.startswith(prefix):
                return i
        return len(ORDER)

    story.sort(key=lambda p: (rank(p), p.stem))

    lines = ['[gd_resource type="Resource" script_class="DocumentIndex" load_steps=%d format=3]'
             % (len(story) + 2), ""]
    lines.append('[ext_resource type="Script" path="res://src/core/document_index.gd" id="1_index"]')
    for i, path in enumerate(story, start=2):
        lines.append('[ext_resource type="Resource" path="res://assets/documents/%s" id="%d_%s"]'
                     % (path.name, i, path.stem))
    lines += ["", "[resource]", 'script = ExtResource("1_index")']
    ids = ", ".join('ExtResource("%d_%s")' % (i, p.stem) for i, p in enumerate(story, start=2))
    lines.append('documents = Array[ExtResource("1_index")]([])' if not story
                 else "documents = [%s]" % ids)
    lines.append("")
    OUT.write_text("\n".join(lines))
    print("wrote %s (%d documents)" % (OUT, len(story)))
    for path in story:
        print("   %-32s %s" % (path.name, _id_of(path)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
