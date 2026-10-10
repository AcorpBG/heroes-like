#!/usr/bin/env python3
"""Derive the battle's runtime battlefields and obstacle props from the generated masters.

The masters and their production record live in
art/battle/source/generated/battlefields_20261010 (the PNGs stay out of Git).

Battlefields: a centred 16:9 crop of each master, resized to 1920x1080.

Props: each prop sheet holds three one-hex props in its top row and two two-hex
props in its bottom row, on transparency. Each prop is cut out by its alpha
island and scaled so that its ground tuft spans its hexes. The tuft centre is
placed on a fixed canvas anchor, so the game draws every prop the same way: the
anchor goes on the hex centre, or on the seam of a two-hex obstacle.

Nothing is repainted, recoloured, mirrored or invented here; only crops, scales
and placement. Run with Pillow, NumPy and SciPy:
    python tools/build_battlefield_art.py
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/battle/source/generated/battlefields_20261010"
BATTLEFIELDS = ROOT / "art/battle/runtime/battlefields"
OBSTACLES = ROOT / "art/battle/runtime/obstacles"
BATTLEFIELD_SIZE = (1920, 1080)
# Canvas pixels per hex width; scenes/battle/BattleBoardView.gd draws props with
# the same density (OBSTACLE_ART_PIXELS_PER_HEX) and anchor.
PIXELS_PER_HEX = 216.0
# A prop's ground tuft is a little wider than its hexes, so the ground under it
# reads as one patch.
TUFT_SPAN = 1.02
CANVAS = {1: (288, 352), 2: (512, 352)}
ANCHOR_Y = 256
# Imports: lossy WebP keeps the painted look at a fraction of the size; the board
# draws with linear filtering, so no mipmaps.
BATTLEFIELD_IMPORT_QUALITY = 0.82
OBSTACLE_IMPORT_QUALITY = 0.85


def resource(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def source_file(res_path: str) -> Path:
    return ROOT / res_path.removeprefix("res://")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_import(path: Path, quality: float) -> None:
    """Minimal import settings; Godot fills in the rest on its first import."""
    settings = path.with_name(path.name + ".import")
    if settings.exists():
        return
    settings.write_text(
        '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="%s"\n\n'
        "[params]\n\ncompress/mode=1\ncompress/lossy_quality=%s\nmipmaps/generate=false\n"
        "process/fix_alpha_border=true\nprocess/size_limit=0\n" % (resource(path), quality),
        encoding="utf-8", newline="\n")


def build_battlefield(entry: dict) -> dict:
    master_path = source_file(entry["source_path"])
    if sha256(master_path) != entry["source_sha256"]:
        raise ValueError("Master changed since production.json: " + entry["source_path"])
    master = Image.open(master_path).convert("RGB")
    width, height = master.size
    crop_width = min(width, round(height * 16 / 9))
    crop_height = min(height, round(crop_width * 9 / 16))
    left = (width - crop_width) // 2
    top = (height - crop_height) // 2
    box = (left, top, left + crop_width, top + crop_height)
    runtime = BATTLEFIELDS / (entry["family"] + ".png")
    master.crop(box).resize(BATTLEFIELD_SIZE, Image.LANCZOS).save(runtime, compress_level=9)
    write_import(runtime, BATTLEFIELD_IMPORT_QUALITY)
    return {"family": entry["family"], "terrains": entry["terrains"], "source_path": entry["source_path"],
            "crop": list(box), "runtime_path": resource(runtime), "size": list(BATTLEFIELD_SIZE),
            "sha256": sha256(runtime)}


def split_props(alpha: np.ndarray) -> list:
    """Five label masks, one per prop: near parts of a prop join, separate props stay apart."""
    solid = alpha >= 24
    for iterations in (10, 6, 3, 1, 0):
        merged = ndimage.binary_dilation(solid, np.ones((3, 3), bool), iterations=iterations) if iterations else solid
        labels, _ = ndimage.label(merged)
        kept = [index for index, box in enumerate(ndimage.find_objects(labels), start=1)
                if int(((labels[box] == index) & solid[box]).sum()) >= 2000]
        if len(kept) != 5:
            continue
        # Soft rim pixels below the threshold belong to the nearest prop.
        islands = np.where(np.isin(labels, kept), labels, 0)
        distance, (near_y, near_x) = ndimage.distance_transform_edt(islands == 0, return_indices=True)
        nearest = islands[near_y, near_x]
        return [(nearest == index) & (alpha > 0) & (distance <= 16) for index in kept]
    raise ValueError("Prop sheet does not split into five separate props")


def measure_tuft(mask: np.ndarray) -> dict:
    """The ground tuft: the widest rows in the lower part of the prop."""
    ys, xs = np.nonzero(mask)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    rows = []
    for y in range(y1 - int((y1 - y0 + 1) * 0.45), y1 + 1):
        filled = np.nonzero(mask[y])[0]
        if filled.size:
            rows.append((int(filled.max() - filled.min() + 1), y, (filled.min() + filled.max()) / 2.0))
    widest = max(row[0] for row in rows)
    plateau = [row for row in rows if row[0] >= widest * 0.97]
    return {"box": [x0, y0, x1 + 1, y1 + 1], "width": widest,
            "center": [float(np.median([row[2] for row in plateau])), float(np.median([row[1] for row in plateau]))]}


def place_prop(sheet: Image.Image, mask: np.ndarray, size: int) -> tuple:
    tuft = measure_tuft(mask)
    x0, y0, x1, y1 = tuft["box"]
    cutout = np.asarray(sheet).copy()
    cutout[~mask] = 0
    part = Image.fromarray(cutout[y0:y1, x0:x1], "RGBA")
    canvas_width, canvas_height = CANVAS[size]
    anchor_x = canvas_width / 2.0
    center_x, center_y = tuft["center"][0] - x0, tuft["center"][1] - y0
    scale = PIXELS_PER_HEX * size * TUFT_SPAN / tuft["width"]
    # A prop that would leave its canvas shrinks to fit rather than being clipped.
    limits = [anchor_x / max(center_x, 1.0), (canvas_width - anchor_x) / max(part.width - center_x, 1.0),
              ANCHOR_Y / max(center_y, 1.0), (canvas_height - ANCHOR_Y) / max(part.height - center_y, 1.0)]
    scale = min([scale] + [limit * 0.995 for limit in limits])
    scaled = part.convert("RGBa").resize((max(1, round(part.width * scale)), max(1, round(part.height * scale))),
                                         Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", CANVAS[size], (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (round(anchor_x - center_x * scale), round(ANCHOR_Y - center_y * scale)))
    return canvas, tuft, scale


def build_prop_sheet(entry: dict) -> list:
    sheet_path = source_file(entry["source_path"])
    if sha256(sheet_path) != entry["source_sha256"]:
        raise ValueError("Master changed since production.json: " + entry["source_path"])
    sheet = Image.open(sheet_path).convert("RGBA")
    masks = split_props(np.asarray(sheet)[:, :, 3])
    rows = sorted(masks, key=lambda mask: float(np.nonzero(mask)[0].mean()))
    by_size = {1: rows[:3], 2: rows[3:]}
    folder = OBSTACLES / entry["family"]
    folder.mkdir(parents=True, exist_ok=True)
    recipes = []
    for size, group in by_size.items():
        group.sort(key=lambda mask: float(np.nonzero(mask)[1].mean()))
        for index, mask in enumerate(group):
            canvas, tuft, scale = place_prop(sheet, mask, size)
            runtime = folder / f"{entry['kind']}_{size}_{index}.png"
            canvas.save(runtime, compress_level=9)
            write_import(runtime, OBSTACLE_IMPORT_QUALITY)
            recipes.append({"family": entry["family"], "kind": entry["kind"], "size": size, "index": index,
                            "name": entry["subjects"][str(size)][index], "source_path": entry["source_path"],
                            "source_box": tuft["box"], "tuft_center": [round(v, 1) for v in tuft["center"]],
                            "tuft_width": tuft["width"], "scale": round(scale, 4), "runtime_path": resource(runtime),
                            "size_px": list(CANVAS[size]), "sha256": sha256(runtime)})
    return recipes


def main() -> None:
    production = json.loads((SOURCE / "production.json").read_text(encoding="utf-8"))
    BATTLEFIELDS.mkdir(parents=True, exist_ok=True)
    battlefields = [build_battlefield(entry) for entry in production["battlefields"]]
    props = [recipe for entry in production["prop_sheets"] for recipe in build_prop_sheet(entry)]
    recipes = {
        "schema": "battle_battlefield_art_recipes_v1",
        "production": resource(SOURCE / "production.json"),
        "battlefield_size": list(BATTLEFIELD_SIZE),
        "obstacle_canvas": {str(size): list(dims) for size, dims in CANVAS.items()},
        "obstacle_anchor_y": ANCHOR_Y,
        "obstacle_pixels_per_hex": PIXELS_PER_HEX,
        "battlefields": battlefields,
        "obstacles": props,
    }
    (SOURCE / "recipes.json").write_text(json.dumps(recipes, indent=2, ensure_ascii=False) + "\n",
                                         encoding="utf-8", newline="\n")
    shrunk = [p["runtime_path"] for p in props
              if p["scale"] < PIXELS_PER_HEX * p["size"] * TUFT_SPAN / p["tuft_width"] - 1e-4]
    print("BATTLEFIELD_ART " + json.dumps({"battlefields": len(battlefields), "obstacles": len(props),
                                           "shrunk_to_fit": shrunk}))


if __name__ == "__main__":
    main()
