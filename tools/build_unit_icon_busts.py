"""Turns the painted close-up icons of units into their runtime textures.

    python tools/build_unit_icon_busts.py

A beast, a winged or plant creature or a war machine has no head and shoulders a crop of its
portrait could show, so those units have a close-up painted from their own portrait (imggen,
see provenance.json in the source folder). This tool scales each 1024 px source in

    art/units/source/generated/icon_busts_20261110/<unit_id>.png   (not tracked)

to 160 px (the size of a battle icon) in art/units/icon_busts/<unit_id>.png, makes nearly opaque pixels opaque, and writes
the folder's provenance.json (prompt file, model, and each source's sha256). Run
tools/build_unit_bust_regions.py afterwards: it lists these icons in
content/unit_bust_regions.json, where UnitPortraitTexture.bust_for_unit finds them.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/units/source/generated/icon_busts_20261110"
OUT = ROOT / "art/units/icon_busts"
SIZE = 160


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    items = []
    for source in sorted(SOURCE.glob("unit_*.png")):
        image = Image.open(source).convert("RGBA")
        if image.size[0] != image.size[1]:
            raise SystemExit(f"{source.name} is not square: {image.size}")
        small = image.resize((SIZE, SIZE), Image.LANCZOS)
        red, green, blue, alpha = small.split()
        alpha = alpha.point(lambda value: 255 if value >= 250 else value)
        Image.merge("RGBA", (red, green, blue, alpha)).save(OUT / source.name)
        items.append({
            "unit_id": source.stem,
            "source": source.name,
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "runtime_path": f"res://art/units/icon_busts/{source.name}",
        })
    provenance = {
        "purpose": "Close-up icons of the units a crop of the portrait cannot show by head and shoulders: beasts, winged and plant creatures, war machines. Each is painted from the unit's own portrait (res://art/units/portraits), keeping its design.",
        "generator": "imggen skill (OpenAI Images API)",
        "model": "gpt-image-2.6-sunburst",
        "created": "2026-11-10",
        "size": "1024x1024", "quality": "medium", "transparent_background": True,
        "prompt_file": "unit_icon_bust.prompt.txt",
        "input": "image 1 is the unit's portrait",
        "runtime_tool": "tools/build_unit_icon_busts.py",
        "note": "The PNG sources are not tracked (art/*/source/**/*.png is ignored); they are in the source art archive (docs/source-material-storage-map.md) and come back with tools/restore_archived_source_material.py.",
        "items": items,
    }
    (SOURCE / "provenance.json").write_text(json.dumps(provenance, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(items)} icons in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
