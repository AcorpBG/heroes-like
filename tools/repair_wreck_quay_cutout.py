#!/usr/bin/env python3
"""Owner-approved matte repair of original Wreck Quay pixels, never drawn art.

Only this hash-locked asset is supported. Coordinates reject its known sheet
divider outside the painted body; chroma unmatting preserves original wood/water
pixels and recovers antialiased alpha from the magenta-key contamination.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/overworld/source/generated/full_match_art_repairs/mapobj_wreck_quay_before.png"
RUNTIME = ROOT / "art/overworld/runtime/objects/map_objects/distinct/mapobj_wreck_quay.png"
TRIMMED = ROOT / "art/overworld/source/trimmed/map_objects/distinct/mapobj_wreck_quay-trimmed.png"
# The magenta/white rectangular sheet divider is x=99/408..412, y=99/409;
# the complete painted wreck, quay, ropes and shoreline lie within this window.
BODY_WINDOW = (108, 120, 402, 390)


def repair_image(source: Image.Image) -> Image.Image:
    if source.mode != "RGBA" or source.size != (512, 512):
        raise ValueError("Expected the original 512x512 RGBA Wreck Quay")
    result = source.copy()
    pixels = result.load()
    left, top, right, bottom = BODY_WINDOW
    for y in range(result.height):
        for x in range(result.width):
            r, g, b, a = pixels[x, y]
            if not (left <= x < right and top <= y < bottom):
                pixels[x, y] = (0, 0, 0, 0)
                continue
            spill = max(0, min(r, b) - g)
            if a == 0 or spill <= 8:
                continue
            coverage = 1.0 - spill / 255.0
            if coverage <= 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (
                    min(255, round((r - spill) / coverage)),
                    min(255, round(g / coverage)),
                    min(255, round((b - spill) / coverage)),
                    round(a * coverage),
                )
    return result


def inspect_image(path: Path) -> dict:
    with Image.open(path) as source:
        image = source.convert("RGBA")
        pixels = image.load()
        left, top, right, bottom = BODY_WINDOW
        divider_pixels = sum(pixels[x, y][3] > 0 for y in range(512)
                             for x in range(512)
                             if not (left <= x < right and top <= y < bottom)) if image.size == (512, 512) else -1
        magenta_pixels = sum(a > 0 and min(r, b) - g > 8 for r, g, b, a in image.getdata())
        alpha = image.getchannel("A")
        errors = []
        if source.mode != "RGBA" or image.size != (512, 512):
            errors.append("not the required 512x512 alpha-preserving runtime canvas")
        if divider_pixels != 0:
            errors.append("sheet divider or pixels outside the complete painted-body window")
        if magenta_pixels:
            errors.append("magenta-key contamination remains")
        if alpha.getextrema() != (0, 255) or alpha.getbbox() is None:
            errors.append("missing genuine background transparency or painted object")
        return dict(ok=not errors, errors=errors, divider_pixels=divider_pixels,
                    magenta_pixels=magenta_pixels, alpha_bounds=alpha.getbbox(),
                    size=image.size, mode=source.mode)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.check:
        report = inspect_image(args.check)
        print(json.dumps(report))
        return 0 if report["ok"] else 1
    if not args.write:
        parser.error("Use --check IMAGE or --write")
    provenance = json.loads((SOURCE.parent / "manifest.json").read_text())
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != provenance["input_sha256"]:
        raise ValueError("The preserved original Wreck Quay hash changed")
    with Image.open(SOURCE) as source:
        result = repair_image(source)
    for path in (TRIMMED, RUNTIME):
        result.save(path, optimize=True)
    report = inspect_image(RUNTIME)
    print(json.dumps(report))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
