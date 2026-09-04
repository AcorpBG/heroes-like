#!/usr/bin/env python3
"""Validate dedicated cohesive blocker art and its deterministic live render."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "OVERWORLD_COHESIVE_BIOME_BLOCKER_MASS_REPORT"
ARTIFACT_DIR = ROOT / ".artifacts" / "overworld_cohesive_biome_blocker_mass_10232"
EXPECTED_BIOMES = {
    "biome_grasslands",
    "biome_deep_forest",
    "biome_mire_fen",
    "biome_coast_archipelago",
    "biome_highland_ridge",
    "biome_rough_badlands",
    "biome_snow_frost_marches",
    "biome_ash_lava_wastes",
    "biome_subterranean_underways",
}


def main() -> int:
    failures: list[str] = []
    decorative = json.loads((ROOT / "art/overworld/decorative_object_sprites.json").read_text())
    art_manifest = json.loads((ROOT / "art/overworld/manifest.json").read_text())
    provenance = json.loads(
        (ROOT / "art/overworld/source/generated/terrain/cohesive_blocker_mass_v3/manifest.json").read_text()
    )
    palettes = decorative.get("generated_body_palette", {})
    authored_ids = {
        str(value.get("asset_id", ""))
        for value in decorative.get("object_sprite_mappings", {}).values()
        if isinstance(value, dict)
    }
    palette_ids = {str(asset_id) for values in palettes.values() for asset_id in values}
    if set(palettes) != EXPECTED_BIOMES:
        failures.append("dedicated palette does not cover the exact nine runtime biomes")
    if len(palette_ids) < 18:
        failures.append("dedicated palette has fewer than 18 distinct production sprites")
    if any(not asset_id.startswith("cohesive_") for asset_id in palette_ids):
        failures.append("legacy or generic art remains in the generated-body palette")
    if palette_ids & authored_ids:
        failures.append("generated-body palette still mixes authored landmark identity art")

    object_assets = art_manifest.get("object_assets", {})
    missing_ids = sorted(asset_id for asset_id in palette_ids if asset_id not in object_assets)
    if missing_ids:
        failures.append(f"manifest is missing palette ids: {missing_ids}")
    runtime_paths = {
        str(object_assets.get(asset_id, {}).get("path", "")) for asset_id in palette_ids
    }
    expected_runtime_paths = {
        "res://art/overworld/runtime/objects/decorations/cohesive_blocker_mass_v3/temperate_atlas.png",
        "res://art/overworld/runtime/objects/decorations/cohesive_blocker_mass_v3/wet_cold_atlas.png",
        "res://art/overworld/runtime/objects/decorations/cohesive_blocker_mass_v3/harsh_atlas.png",
    }
    if runtime_paths != expected_runtime_paths:
        failures.append("palette is not restricted to the three cohesive runtime atlases")

    atlas_rows: list[dict[str, object]] = []
    for resource_path in sorted(expected_runtime_paths):
        path = ROOT / resource_path.removeprefix("res://")
        if not path.is_file():
            failures.append(f"runtime atlas is missing: {resource_path}")
            continue
        image = Image.open(path).convert("RGBA")
        alpha = image.getchannel("A")
        transparent = sum(1 for value in alpha.getdata() if value == 0)
        transparent_ratio = transparent / float(image.width * image.height)
        opaque_corner_count = 0
        for cell_y in range(4):
            for cell_x in range(4):
                for px, py in (
                    (cell_x * 128, cell_y * 128),
                    (cell_x * 128 + 127, cell_y * 128),
                    (cell_x * 128, cell_y * 128 + 127),
                    (cell_x * 128 + 127, cell_y * 128 + 127),
                ):
                    opaque_corner_count += int(alpha.getpixel((px, py)) > 32)
        if image.size != (512, 512):
            failures.append(f"runtime atlas has wrong size: {resource_path}={image.size}")
        if transparent_ratio < 0.12:
            failures.append(f"atlas lacks meaningful transparent separation: {resource_path}")
        if opaque_corner_count > 8:
            failures.append(f"atlas exposes rectangular cell plates: {resource_path}")
        atlas_rows.append(
            {
                "path": resource_path,
                "size": list(image.size),
                "mode": image.mode,
                "transparent_ratio": transparent_ratio,
                "opaque_cell_corner_count": opaque_corner_count,
            }
        )

    if provenance.get("generator") != "OpenAI built-in image generation":
        failures.append("source provenance does not name the approved generator")
    runtime_source = (ROOT / "scenes/overworld/OverworldMapView.gd").read_text()
    for required in (
        'GENERATED_DECORATIVE_BODY_PRESENTATION_MODEL := "cohesive_biome_exact_body_raster_mass_v6"',
        "_generated_decorative_blocker_asset_ids_by_biome.clear()",
        "_generated_decorative_blocker_fallback_asset_ids.clear()",
        'return "%s|%s|%d,%d"',
    ):
        if required not in runtime_source:
            failures.append(f"runtime dedicated-palette contract is missing: {required}")

    live = subprocess.run(
        [sys.executable, "tests/overworld_raster_terrain_blocker_mass_report.py"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=480,
        check=False,
    )
    print(live.stdout, end="")
    if live.returncode:
        failures.append(f"live deterministic report failed with exit {live.returncode}")
    live_report_path = ARTIFACT_DIR / "report.json"
    live_report = json.loads(live_report_path.read_text()) if live_report_path.is_file() else {}
    for key, expected in {
        "ok": True,
        "expected_body_tile_count": 2324,
        "visual_anchor_count": 2324,
        "uncovered_body_tile_count": 0,
        "session_authority_exact": True,
        "collision_authority_exact": True,
        "native_rmg_output_changed": False,
    }.items():
        if live_report.get(key) != expected:
            failures.append(f"live report {key}={live_report.get(key)!r}, expected {expected!r}")
    capture_paths = [Path(str(row.get("capture_path", ""))) for row in live_report.get("rows", [])]
    if len(capture_paths) != 2 or any(not path.is_file() for path in capture_paths):
        failures.append("responsive 1920x1080 and 1280x720 evidence is incomplete")

    payload = {
        "ok": not failures,
        "failures": failures,
        "palette_biome_count": len(palettes),
        "dedicated_palette_asset_count": len(palette_ids),
        "authored_palette_intersection_count": len(palette_ids & authored_ids),
        "runtime_atlas_count": len(runtime_paths),
        "atlases": atlas_rows,
        "live_report": live_report,
    }
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    (ARTIFACT_DIR / "cohesion_report.json").write_text(json.dumps(payload, indent=2) + "\n")
    print(f"{REPORT_ID} {json.dumps(payload, sort_keys=True)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
