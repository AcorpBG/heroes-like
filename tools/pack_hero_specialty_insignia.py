#!/usr/bin/env python3
"""Pack hero specialty insignia into the runtime atlas.

The atlas is 7 columns by 5 rows of 28 px cells (content/hero_specialties.json
gives each specialty its cell). Row 1 keeps the seven original insignia
(generated 2026-08-29 from their own sources). The 28 insignia added with the
35-specialty catalog (2026-10-08) come from two generated sheets of painted
icons on transparency (4x4 and 4x3, cells in catalog icon order): each icon is
cut from its sheet cell by its alpha bounds, fitted into 24x24 and centred in
its 28 px cell. `--check` verifies the atlas is reproducible from the sheets.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art/heroes/source/generated/specialties"
MANIFEST = SOURCE_DIR / "manifest.json"
CATALOG = ROOT / "content/hero_specialties.json"
ATLAS = ROOT / "art/heroes/runtime/specialties/hero_specialty_insignia_atlas.png"
CELL = 28
CONTENT = 24
COLUMNS = 7
ROWS = 5


def drop_specks(cell):
    """Clear pieces smaller than 3% of the cell's largest opaque piece."""
    alpha = cell.getchannel("A")
    width, height = alpha.size
    solid = [value > 24 for value in alpha.tobytes()]
    label = [0] * len(solid)
    sizes = {}
    for start in range(len(solid)):
        if not solid[start] or label[start]:
            continue
        current = len(sizes) + 1
        label[start] = current
        stack = [start]
        count = 0
        while stack:
            index = stack.pop()
            count += 1
            x, y = index % width, index // width
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbour = ny * width + nx
                    if solid[neighbour] and not label[neighbour]:
                        label[neighbour] = current
                        stack.append(neighbour)
        sizes[current] = count
    if not sizes:
        return cell
    floor = max(sizes.values()) * 3 // 100
    # Faint pixels (alpha 24 or less) are dropped with the specks; at full
    # sheet resolution they vanish in the downscale anyway.
    cleaned = Image.new("L", alpha.size)
    cleaned.putdata([value if label[index] and sizes[label[index]] >= floor else 0 for index, value in enumerate(alpha.tobytes())])
    cell.putalpha(cleaned)
    return cell


def cut_icon(sheet, cols, rows, index):
    width, height = sheet.size
    box = (index % cols * width // cols, index // cols * height // rows,
           (index % cols + 1) * width // cols, (index // cols + 1) * height // rows)
    cell = sheet.crop(box)
    # A neighbour's halo or edge can reach into a cell; keep only what lies
    # inside a 5% border.
    margin = max(2, cell.width * 5 // 100)
    keep = Image.new("L", cell.size, 0)
    keep.paste(255, (margin, margin, cell.width - margin, cell.height - margin))
    cell.putalpha(Image.composite(cell.getchannel("A"), Image.new("L", cell.size, 0), keep))
    cell = drop_specks(cell)
    bounds = cell.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"empty icon cell {index}")
    icon = cell.crop(bounds)
    scale = CONTENT / max(icon.size)
    size = (max(1, round(icon.width * scale)), max(1, round(icon.height * scale)))
    return icon.resize(size, Image.Resampling.LANCZOS)


def packed_bytes(manifest, original_row):
    atlas = Image.new("RGBA", (COLUMNS * CELL, ROWS * CELL), (0, 0, 0, 0))
    atlas.paste(original_row, (0, 0))
    catalog = {item["id"]: item for item in json.loads(CATALOG.read_text(encoding="utf-8"))["items"]}
    for sheet in manifest["generated_sheets"]:
        path = ROOT / sheet["source"].removeprefix("res://")
        assert hashlib.sha256(path.read_bytes()).hexdigest() == sheet["source_sha256"], path
        with Image.open(path) as image:
            image = image.convert("RGBA")
            for index, specialty_id in enumerate(sheet["specialty_ids"]):
                icon = cut_icon(image, sheet["columns"], sheet["rows"], index)
                x, y = catalog[specialty_id]["icon_region"][:2]
                atlas.alpha_composite(icon, (x + (CELL - icon.width) // 2, y + (CELL - icon.height) // 2))
    output = io.BytesIO()
    atlas.save(output, format="PNG", optimize=True)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    with Image.open(ATLAS) as current:
        original_row = current.convert("RGBA").crop((0, 0, COLUMNS * CELL, CELL))
    result = packed_bytes(manifest, original_row)
    digest = hashlib.sha256(result).hexdigest()
    if args.check:
        assert ATLAS.read_bytes() == result, "Specialty insignia atlas is not reproducible from its sources"
        assert digest == manifest["runtime_sha256"], "Manifest runtime hash is stale"
    else:
        ATLAS.write_bytes(result)
    print(f"Specialty insignia atlas: {len(result)} bytes, sha256={digest}")


if __name__ == "__main__":
    main()
