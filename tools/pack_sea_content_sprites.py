"""Pack the sea pickup sprites (docs/rmg-sea-content.md).

Random maps translate HoMM3's Flotsam, Sea Chest and Shipwreck Survivor into the
Drift Wreckage, Sea Coffer and Castaway Raft pickups. All three are original
paintings. Packing matches the other generated pickup sprites: alpha above 8 sets
the crop box, then an aspect-preserving resize onto the shared 512px canvas,
centred and bottom-aligned; no repainting. The tool registers the sprites in the
overworld art manifest and the map-object sprite mapping, and can be run again
where the source paintings are present (they live in the external source archive).
"""

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BATCH = "sea_content_20261109"
SOURCE = Path("art/overworld/source/generated/resource_sites") / BATCH
CANVAS = 512
# Floating pickups fill about 330px and ride on row 420, a little smaller than
# the land piles so they sit beside a boat (253px) without dwarfing it.
MAX_EXTENT = 330
BOTTOM = 420
SPRITES = [
    {
        "name": "drift_wreckage",
        "presentation_role": "floating_timber_pickup",
        "accessible_description": "Broken ship planks and a snapped spar adrift, with a lashed cask, a split crate and a scrap of sailcloth.",
        "fit": "Distinct original drift wreckage assigned to the Drift Wreckage pickup, which stands for HoMM3's Flotsam on random maps.",
        "site_fit": "One-time floating timber: wood, sometimes with gold.",
    },
    {
        "name": "sea_coffer",
        "presentation_role": "floating_gold_coffer_pickup",
        "accessible_description": "A tarred, iron-banded coffer with a brass lock riding on four cork floats, gold glinting under its lid.",
        "fit": "Distinct original floating coffer assigned to the Sea Coffer pickup, which stands for HoMM3's Sea Chest on random maps.",
        "site_fit": "One-time floating coffer: gold, sometimes with a treasure artifact.",
    },
    {
        "name": "castaway_raft",
        "presentation_role": "castaway_artifact_pickup",
        "accessible_description": "A lashed log raft with a ragged sail, a lantern, a bundle and a small chest, a silver amulet hanging from its mast.",
        "fit": "Distinct original castaway raft assigned to the Castaway Raft pickup, which stands for HoMM3's Shipwreck Survivor on random maps.",
        "site_fit": "One-time castaway raft: an artifact.",
    },
]


def pack(source: Path) -> Image.Image:
    image = Image.open(ROOT / source).convert("RGBA")
    assert image.getchannel("A").getextrema()[0] == 0, f"{source} must be transparent"
    bounds = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    cropped = image.crop(bounds)
    scale = MAX_EXTENT / max(cropped.size)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(resized, ((CANVAS - size[0]) // 2, BOTTOM - size[1]))
    return canvas


def main():
    manifest_path = ROOT / "art/overworld/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    mapping_path = ROOT / "art/overworld/map_object_sprites.json"
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    for sprite in SPRITES:
        name = sprite["name"]
        source = SOURCE / f"{name}-source.png"
        output = Path("art/overworld/runtime/objects/pickups") / f"{name}.png"
        (ROOT / output).parent.mkdir(parents=True, exist_ok=True)
        pack(source).save(ROOT / output, optimize=True)
        asset_id = "mapobj_" + name
        manifest["object_assets"][asset_id] = {
            "path": "res://" + output.as_posix(),
            "source_generated": "res://" + source.as_posix(),
            "source_processing_manifest": "res://" + (SOURCE / "provenance.json").as_posix(),
            "source_model": "gpt-image-2.6-sunburst_transparent",
            "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
            "distinct_sprite_assignment": True,
            "assigned_map_object_id": "object_" + name,
            "assigned_map_object_family": "pickup",
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
            coverage["by_family"]["pickup"] = int(coverage["by_family"].get("pickup", 0)) + 1
        mapping["object_sprite_mappings"]["object_" + name] = {
            "asset_id": asset_id,
            "fit": sprite["fit"],
            "assignment_source": "new_distinct_map_object_sprite",
            "family": "pickup",
            "source_batch": BATCH,
        }
        print(f"{name}: {output.as_posix()}")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    mapping_path.write_text(json.dumps(mapping, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
