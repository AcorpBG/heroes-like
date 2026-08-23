#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "art" / "towns" / "source" / "buildings" / "curated"
RUNTIME_ROOT = ROOT / "art" / "towns" / "runtime" / "buildings"
MANIFEST_PATH = ROOT / "content" / "building_art_manifest.json"
ICON_SIZE = (256, 256)
SOURCE_SIZE = (1254, 1254)
BUILDING_IDS = (
    "building_muster_yard",
    "building_bowyer_lodge",
    "building_embercourt_bargebow_slip",
    "building_embercourt_oath_pikehall",
    "building_embercourt_beacon_court",
    "building_embercourt_drake_sluice",
    "building_embercourt_charter_bastion",
    "building_mireclaw_blackbranch_den",
    "building_mireclaw_war_drum_circle",
    "building_mireclaw_floodtide_forge",
    "building_mireclaw_chainboom_ferry",
    "building_mireclaw_sporewake_shrine",
    "building_mireclaw_nightglass_dominion",
    "building_mireclaw_antler_pit",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render_icon(source_path: Path, runtime_path: Path) -> None:
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    if source.size != SOURCE_SIZE:
        raise ValueError(f"{source_path} must be {SOURCE_SIZE}, got {source.size}")
    alpha_bbox = source.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError(f"{source_path} contains no visible pixels")
    subject = source.crop(alpha_bbox)
    fitted = ImageOps.contain(subject, (236, 236), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", ICON_SIZE, (0, 0, 0, 0))
    icon.alpha_composite(fitted, ((ICON_SIZE[0] - fitted.width) // 2, (ICON_SIZE[1] - fitted.height) // 2))
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(runtime_path, format="PNG", optimize=False, compress_level=9)


def main() -> int:
    items = []
    for building_id in BUILDING_IDS:
        source_path = SOURCE_ROOT / f"{building_id}.png"
        runtime_path = RUNTIME_ROOT / f"{building_id}.png"
        if not source_path.is_file():
            raise FileNotFoundError(f"missing curated building source: {source_path}")
        render_icon(source_path, runtime_path)
        items.append({
            "id": building_id,
            "building_id": building_id,
            "source_kind": "curated_original_building",
            "source_path": "res://" + source_path.relative_to(ROOT).as_posix(),
            "source_sha256": sha256(source_path),
            "icon_path": "res://" + runtime_path.relative_to(ROOT).as_posix(),
            "icon_sha256": sha256(runtime_path),
        })
    manifest = {
        "schema_version": 1,
        "generator": "deterministic_building_icon_assets_v1",
        "source_size": {"width": SOURCE_SIZE[0], "height": SOURCE_SIZE[1]},
        "icon_size": {"width": ICON_SIZE[0], "height": ICON_SIZE[1]},
        "items": items,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"generated {len(items)} building icons into {RUNTIME_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
