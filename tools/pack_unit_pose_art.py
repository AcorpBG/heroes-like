#!/usr/bin/env python3
"""Pack reviewed generated RGBA poses; never synthesize poses or remove a backdrop.

Recipes name source rectangles, an anatomical ground anchor, and uniform scale.
Multiple rectangles allow a long weapon to extend through an otherwise empty
neighboring cell. Source pixels are copied unchanged before uniform resampling;
there are no painting, rotation, tint, chroma-key, or silhouette-warp operations.
The caller explicitly chooses a candidate destination. Runtime registration is
a separate reviewed content change, never a side effect of packing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def pack(recipe_path: Path, output: Path) -> dict:
    recipe = json.loads(recipe_path.read_text())
    width, height = recipe["frame_size"]
    if not (1 <= width <= 2048 and 1 <= height <= 2048):
        raise ValueError("invalid frame dimensions")
    frames = recipe["frames"]
    columns = recipe["columns"]
    if not frames or not 1 <= columns <= 32:
        raise ValueError("invalid frame layout")
    rows = (len(frames) + columns - 1) // columns
    atlas = Image.new("RGBA", (width * columns, height * rows))
    sources = {}
    evidence = []
    for index, frame in enumerate(frames):
        source_path = (recipe_path.parent / frame["source"]).resolve()
        if source_path not in sources:
            source = Image.open(source_path)
            source.load()
            # Built-in cutouts may encode their opaque ink at 254/255. Keep
            # those original alpha values; an exact-255 requirement rejects
            # valid raster art. Still require fully clear and near-opaque ink.
            if source.mode != "RGBA" or not (
                source.getchannel("A").getextrema()[0] == 0
                and source.getchannel("A").getextrema()[1] >= 254
            ):
                raise ValueError(f"source must have real transparent alpha: {source_path}")
            sources[source_path] = source
        source = sources[source_path]
        rects = frame["rects"]
        x0 = min(r[0] for r in rects)
        y0 = min(r[1] for r in rects)
        x1 = max(r[2] for r in rects)
        y1 = max(r[3] for r in rects)
        cutout = Image.new("RGBA", (x1 - x0, y1 - y0))
        for left, top, right, bottom in rects:
            if not (0 <= left < right <= source.width and 0 <= top < bottom <= source.height):
                raise ValueError(f"out-of-source rectangle in frame {index}")
            # Unmasked paste preserves the generated alpha (no double alpha).
            cutout.paste(source.crop((left, top, right, bottom)), (left - x0, top - y0))
        scale = float(frame["scale"])
        if not 0 < scale <= 1:
            raise ValueError("only positive downsampling scales are supported")
        resized = cutout.resize((max(1, round(cutout.width * scale)),
                                 max(1, round(cutout.height * scale))), Image.Resampling.LANCZOS)
        anchor_x, anchor_y = frame["anchor"]
        px = round(width / 2 - (anchor_x - x0) * scale)
        py = round(height - recipe["ground_margin"] - (anchor_y - y0) * scale)
        bounds = resized.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"empty pose {index}")
        if not (0 <= px + bounds[0] and 0 <= py + bounds[1]
                and px + bounds[2] <= width and py + bounds[3] <= height):
            raise ValueError(f"pose {index} would clip: offset {(px, py)}, bounds {bounds}")
        tile = Image.new("RGBA", (width, height))
        tile.paste(resized, (px, py))
        atlas.paste(tile, ((index % columns) * width, (index // columns) * height))
        evidence.append({"name": frame["name"], "index": index,
                         "alpha_bounds": list(tile.getchannel("A").getbbox())})
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, optimize=True)
    return {"unit_id": recipe["unit_id"], "output": str(output),
            "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "frame_size": [width, height], "frames": evidence,
            "sources": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recipe", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(pack(args.recipe, args.output), indent=2))


if __name__ == "__main__":
    main()
