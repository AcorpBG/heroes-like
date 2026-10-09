"""Pack the Wyrmcrown Hoard and Hushlock Casket sprites (docs/creature-banks.md).

The Wyrmcrown Hoard stands for HoMM3's Dragon Utopia and the Hushlock Casket
for Pandora's Box on random maps. Both are original paintings. Packing matches
the other generated object sprites: alpha above 8 sets the crop box, then an
aspect-preserving resize onto the shared 512px canvas, centred and
bottom-aligned with the sprites of the same family; no repainting. The tool
registers both sprites in the overworld art manifest and the map-object sprite
mapping, and can be run again.
"""

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("art/overworld/source/generated/resource_sites/creature_banks_20261009")
CANVAS = 512
SPRITES = [
    {
        "name": "wyrmcrown_hoard",
        "family": "guarded_reward_site",
        "runtime": Path("art/overworld/runtime/objects/map_objects/distinct/mapobj_wyrmcrown_hoard.png"),
        # The guarded reward sites fill about 300px and stand on row 410.
        "max_extent": 300,
        "bottom": 410,
        "presentation_role": "dragon_hoard_guarded_reward_site",
        "accessible_description": "A ring of jagged basalt crags under a great horned wyrm skull holds a heaped hoard of gold, gems, goblets and a crown.",
        "fit": "Distinct original wyrm's hoard assigned to the Wyrmcrown Hoard, which stands for HoMM3's Dragon Utopia on random maps.",
        "site_fit": "Guarded wyrm hoard: gold and four artifacts behind a dragon guard.",
    },
    {
        "name": "hushlock_casket",
        "family": "pickup",
        "runtime": Path("art/overworld/runtime/objects/pickups/hushlock_casket.png"),
        # The one-time chests fill up to about 360-400px and stand on row 456.
        "max_extent": 360,
        "bottom": 450,
        "presentation_role": "sealed_mystery_casket_pickup",
        "accessible_description": "A domed casket of dark wood and bronze, chained and sealed with three locks and purple wax, glows violet at its seams.",
        "fit": "Distinct original sealed casket assigned to the Hushlock Casket pickup, which stands for HoMM3's Pandora's Box on random maps.",
        "site_fit": "One-time sealed casket holding experience, gold, spells or troops.",
    },
]


def pack(source: Path, max_extent: int, bottom: int) -> Image.Image:
    image = Image.open(ROOT / source).convert("RGBA")
    assert image.getchannel("A").getextrema()[0] == 0, f"{source} must be transparent"
    bounds = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    cropped = image.crop(bounds)
    scale = max_extent / max(cropped.size)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(resized, ((CANVAS - size[0]) // 2, bottom - size[1]))
    return canvas


def main():
    manifest_path = ROOT / "art/overworld/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    mapping_path = ROOT / "art/overworld/map_object_sprites.json"
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    for sprite in SPRITES:
        name = sprite["name"]
        source = SOURCE / f"{name}-source.png"
        output = sprite["runtime"]
        (ROOT / output).parent.mkdir(parents=True, exist_ok=True)
        pack(source, sprite["max_extent"], sprite["bottom"]).save(ROOT / output, optimize=True)
        asset_id = "mapobj_" + name
        manifest["object_assets"][asset_id] = {
            "path": "res://" + output.as_posix(),
            "source_generated": "res://" + source.as_posix(),
            "source_processing_manifest": "res://" + (SOURCE / "provenance.json").as_posix(),
            "source_model": "built_in_image_gen_transparent",
            "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
            "distinct_sprite_assignment": True,
            "assigned_map_object_id": "object_" + name,
            "assigned_map_object_family": sprite["family"],
            "presentation_role": sprite["presentation_role"],
            "accessible_description": sprite["accessible_description"],
            "runtime_sha256": hashlib.sha256((ROOT / output).read_bytes()).hexdigest(),
        }
        manifest["resource_site_sprites"]["site_" + name] = {"asset_id": asset_id, "fit": sprite["site_fit"]}
        if asset_id not in mapping["distinct_asset_ids"]:
            mapping["distinct_asset_ids"].append(asset_id)
            coverage = mapping["coverage"]
            for key in ("authored_map_object_count", "new_distinct_non_decorative_asset_count", "total_distinct_authored_map_object_count_after_pass"):
                coverage[key] = int(coverage[key]) + 1
            coverage["by_family"][sprite["family"]] = int(coverage["by_family"].get(sprite["family"], 0)) + 1
        mapping["object_sprite_mappings"]["object_" + name] = {
            "asset_id": asset_id,
            "fit": sprite["fit"],
            "assignment_source": "new_distinct_map_object_sprite",
            "family": sprite["family"],
            "source_batch": "creature_banks_20261009",
        }
        print(f"{name}: {output.as_posix()}")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    mapping_path.write_text(json.dumps(mapping, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
