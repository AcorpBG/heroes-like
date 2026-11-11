"""The artifact icons of the artifact rework (docs/artifact-system.md).

The 150 artifacts are painted six to a sheet (a 3 by 2 grid on a transparent
1536x1024 sheet). This tool writes each sheet's prompt from the catalogue
(tools/artifact_catalogue.py) and cuts the painted sheets into the game's
128 pixel icons, art/artifacts/runtime/<name>.png.

    python tools/build_artifact_icons.py prompts          # sheet_NN.prompt.txt and sheets.json
    python tools/build_artifact_icons.py cut              # every sheet that is restored
    python tools/build_artifact_icons.py cut --sheet 3    # one sheet
    python tools/build_artifact_icons.py contact OUT.png  # all cut icons on one page, to look at
    python tools/build_artifact_icons.py provenance       # provenance.json from the sheets present

The sheets are source art: they live in the source art archive
(docs/source-material-storage-map.md) and come back with
tools/restore_archived_source_material.py. Painting them is not this tool's job;
a sheet is painted from its prompt with sheet_00.png as the style reference.

An icon repainted on its own sheet is listed in fixes.json beside the sheets:
[{"file": "fix_01.png", "columns": 3, "rows": 2, "names": ["Scribe's Cap", null, ...]}].
A fix replaces the icon cut from the first sheet.
"""
import argparse
import hashlib
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import artifact_catalogue as catalogue  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(ROOT, "art", "artifacts", "source", "generated", "artifact_rework_20261111")
RUNTIME = os.path.join(ROOT, "art", "artifacts", "runtime")
ICON = 128
COLUMNS, ROWS = 3, 2
# The trial sheet the owner approved, 2026-11-11; it is the style reference for the rest.
FIRST_SHEET = ["Scribe's Cap", "Cinder Pendant", "The Question", "Roadeater Boots", "Shroud of the Unseen Fleet", "Dawn Chime"]

BAND = {
    "common": "A humble, everyday object: plain materials, no gems, no glow.",
    "uncommon": "A well-made object: good materials and a little decoration, no glow.",
    "rare": "A fine object: rich materials, engraving or one gem, at most a faint glint.",
    "epic": "A legendary object: ornate and precious, with a soft magical glow.",
}
SLOT = {
    "head": "Headwear, shown empty with no head in it.",
    "neck": "Worn at the neck: the whole cord or chain is inside its cell.",
    "cloak": "A garment shown empty, as if worn by no one.",
    "armor": "Body armour shown empty, with no person in it.",
    "hand": "",
    "ring": "A single finger ring, shown large.",
    "boots": "A pair of boots or shoes, shown empty.",
    "banner": "Carried on a short pole; the whole pole is inside its cell.",
    "trinket": "",
}
FACTION = {
    "Embercourt": "River-court make: red cloth, brass, lock and beacon motifs.",
    "Mireclaw": "Bog-clan make: reeds, bone, raw hide, murky green.",
    "Sunvault": "Crystal-array make: white, gold and clear glass lenses.",
    "Thornwake": "Living-orchard make: green wood, bark, thorns and leaves.",
    "Brasshollow": "Foundry make: brass, black iron, rivets and gauges, soot.",
    "Veilmourn": "Funeral-fleet make: grey sailcloth, rope, salt and pale lantern light.",
}


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("'", "")).strip("_")


def rows_by_name():
    return {row[0]: row for row in catalogue.ARTIFACTS}


def sheets():
    """The names on each sheet, in grid order: the trial sheet, then the catalogue six by six."""
    rest = [row[0] for row in catalogue.ARTIFACTS if row[0] not in FIRST_SHEET]
    return [FIRST_SHEET] + [rest[index:index + COLUMNS * ROWS] for index in range(0, len(rest), COLUMNS * ROWS)]


def describe(row):
    name, slot_name, band, _bonuses, extra = row
    parts = [extra["what"][0].upper() + extra["what"][1:] + ".", SLOT[slot_name], FACTION.get(extra.get("faction", ""), ""), BAND[band]]
    return " ".join(part for part in parts if part)


def prompt(names, columns=COLUMNS, rows=ROWS):
    known = rows_by_name()
    count = len([name for name in names if name])
    lines = [
        "%s inventory icon%s for an original fantasy strategy game, on one sheet with a fully transparent background." % (["One", "Two", "Three", "Four", "Five", "Six"][count - 1], "" if count == 1 else "s"),
        "",
        "Layout: a strict grid of %d column%s and %d row%s. One object in each cell, centred, filling about three quarters of its cell, with clear empty space all around it. Nothing touches or crosses into a neighbouring cell or the edge of the sheet. No text, no letters, no numbers, no frames, no borders, no ground, no cast shadows, no background, no people." % (columns, "" if columns == 1 else "s", rows, "" if rows == 1 else "s"),
        "",
        "Style: image 1 is a finished sheet of this game's icons. Match its painting exactly: hand-painted, chunky readable silhouette, slight three-quarter view, warm key light with a soft rim light, earthy saturated colours, crisp painted edges, the same level of detail. Do not repeat its objects.",
        "",
        "The objects, left to right, top row first:",
    ]
    number = 0
    for name in names:
        if not name:
            continue
        number += 1
        lines.append("%d. %s" % (number, describe(known[name])))
    return "\n".join(lines) + "\n"


def sheet_path(index):
    return os.path.join(SOURCE, "sheet_%02d.png" % index)


def load_fixes():
    path = os.path.join(SOURCE, "fixes.json")
    if not os.path.exists(path):
        return []
    with io.open(path, encoding="utf-8") as handle:
        return json.load(handle)


def cut_cell(sheet, column, row, columns, rows):
    """One cell's object as a 128 pixel icon, and what looks wrong with it."""
    import numpy
    from PIL import Image
    from scipy import ndimage

    width, height = sheet.width // columns, sheet.height // rows
    cell = sheet.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))
    pixels = numpy.array(cell)
    solid = pixels[:, :, 3] > 24
    labels, count = ndimage.label(solid)
    if count == 0:
        return None, ["empty"]
    areas = ndimage.sum(solid, labels, range(1, count + 1))
    keep = numpy.isin(labels, [index + 1 for index, area in enumerate(areas) if area >= 0.01 * areas.max()])
    pixels[~keep, 3] = 0
    ys, xs = numpy.nonzero(keep)
    left, right, top, bottom = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    notes = []
    if keep.mean() < 0.04:
        notes.append("small")
    if left <= 1 or top <= 1 or right >= width - 1 or bottom >= height - 1:
        notes.append("touches its cell's edge")
    cut = Image.fromarray(pixels).crop((left, top, right, bottom))
    side = int(max(cut.size) * 1.08)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cut, ((side - cut.width) // 2, (side - cut.height) // 2), cut)
    return square.resize((ICON, ICON), Image.LANCZOS), notes


def cut_sheet(path, names, columns, rows, label):
    from PIL import Image

    sheet = Image.open(path).convert("RGBA")
    written = 0
    for index, name in enumerate(names):
        if not name:
            continue
        icon, notes = cut_cell(sheet, index % columns, index // columns, columns, rows)
        if icon is None:
            print("%s: %s is empty" % (label, name))
            continue
        icon.save(os.path.join(RUNTIME, slug(name) + ".png"))
        written += 1
        if notes:
            print("%s: %s %s" % (label, name, ", ".join(notes)))
    return written


def command_prompts(_args):
    os.makedirs(SOURCE, exist_ok=True)
    plan = sheets()
    names = [name for sheet in plan for name in sheet]
    slugs = [slug(name) for name in names]
    assert len(names) == len(catalogue.ARTIFACTS) and len(set(slugs)) == len(slugs), "every artifact on one sheet, under its own file name"
    for index, sheet in enumerate(plan):
        with io.open(os.path.join(SOURCE, "sheet_%02d.prompt.txt" % index), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(prompt(sheet))
    with io.open(os.path.join(SOURCE, "sheets.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump([{"file": "sheet_%02d.png" % index, "names": sheet} for index, sheet in enumerate(plan)], handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    for fix in load_fixes():
        with io.open(os.path.join(SOURCE, os.path.splitext(fix["file"])[0] + ".prompt.txt"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(prompt(fix["names"], fix["columns"], fix["rows"]))
    print("%d sheets, %d artifacts, in %s" % (len(plan), len(names), os.path.relpath(SOURCE, ROOT)))


def command_cut(args):
    plan = sheets()
    written = 0
    for index, sheet in enumerate(plan):
        if args.sheet is not None and index not in args.sheet:
            continue
        if os.path.exists(sheet_path(index)):
            written += cut_sheet(sheet_path(index), sheet, COLUMNS, ROWS, "sheet %02d" % index)
        elif args.sheet is not None:
            print("sheet %02d is not restored" % index)
    for fix in load_fixes():
        path = os.path.join(SOURCE, fix["file"])
        if os.path.exists(path) and args.sheet is None:
            written += cut_sheet(path, fix["names"], fix["columns"], fix["rows"], fix["file"])
    print("%d icons written to %s" % (written, os.path.relpath(RUNTIME, ROOT)))


def command_contact(args):
    from PIL import Image, ImageDraw, ImageFont

    names = [row[0] for row in catalogue.ARTIFACTS]
    bands = {row[0]: row[2] for row in catalogue.ARTIFACTS}
    tint = {"common": (167, 173, 179), "uncommon": (118, 194, 122), "rare": (98, 168, 230), "epic": (198, 144, 240)}
    per_row, tile, pad, caption = 10, 128, 10, 30
    count_rows = (len(names) + per_row - 1) // per_row
    board = Image.new("RGB", (pad + per_row * (tile + pad), pad + count_rows * (tile + caption + pad)), (20, 17, 13))
    draw = ImageDraw.Draw(board)
    try:
        font = ImageFont.truetype("segoeui.ttf", 11)
    except OSError:
        font = ImageFont.load_default()
    for index, name in enumerate(names):
        x = pad + (index % per_row) * (tile + pad)
        y = pad + (index // per_row) * (tile + caption + pad)
        draw.rectangle((x, y, x + tile, y + tile), fill=(29, 25, 19), outline=tint[bands[name]])
        path = os.path.join(RUNTIME, slug(name) + ".png")
        if os.path.exists(path):
            icon = Image.open(path).convert("RGBA")
            board.paste(icon, (x, y), icon)
        draw.text((x, y + tile + 2), name[:24], fill=(179, 166, 138), font=font)
    board.save(args.out)
    print("wrote", args.out, board.size)


def command_provenance(_args):
    items = []
    for entry in [{"file": "sheet_%02d.png" % index, "names": sheet} for index, sheet in enumerate(sheets())] + load_fixes():
        path = os.path.join(SOURCE, entry["file"])
        if not os.path.exists(path):
            continue
        with open(path, "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()
        items.append({"source": entry["file"], "prompt_file": os.path.splitext(entry["file"])[0] + ".prompt.txt", "names": entry["names"],
                      "inputs": [] if entry["file"] == "sheet_00.png" else ["image 1: sheet_00.png, for the style"], "transparent": True, "sha256": digest})
    data = {
        "purpose": "The icons of the 150 artifacts of the artifact rework (docs/artifact-system.md), six to a sheet. tools/build_artifact_icons.py writes the prompts and cuts the sheets into art/artifacts/runtime/<name>.png at 128 pixels. A fix sheet repaints single icons (fixes.json).",
        "generator": "imggen skill (OpenAI Images API)",
        "model": "gpt-image-2.6-sunburst",
        "created": "2026-11-11",
        "quality": "medium",
        "note": "The PNGs are not tracked (art/*/source/**/*.png is ignored); they are in the source art archive (docs/source-material-storage-map.md) and come back with tools/restore_archived_source_material.py.",
        "items": items,
    }
    with io.open(os.path.join(SOURCE, "provenance.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print("provenance for %d sheets" % len(items))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("prompts").set_defaults(run=command_prompts)
    cut = commands.add_parser("cut")
    cut.add_argument("--sheet", type=int, action="append")
    cut.set_defaults(run=command_cut)
    contact = commands.add_parser("contact")
    contact.add_argument("out")
    contact.set_defaults(run=command_contact)
    commands.add_parser("provenance").set_defaults(run=command_provenance)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
