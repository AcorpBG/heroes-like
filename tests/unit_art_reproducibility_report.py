#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GENERATOR_PATH = ROOT / "tools" / "generate_unit_art_assets.py"
UNITS_PATH = ROOT / "content" / "units.json"
UNIT_ART_MANIFEST_PATH = ROOT / "content" / "unit_art_manifest.json"
UNIT_ANIMATION_MANIFEST_PATH = ROOT / "content" / "unit_animation_manifest.json"
ARTIFACT_DIR = ROOT / ".artifacts" / "unit_art_reproducibility_report"


def main() -> int:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    generator = load_generator()
    units = json.loads(UNITS_PATH.read_text(encoding="utf-8")).get("items", [])
    errors: list[str] = []
    asset_records: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="unit-art-reproducibility-") as temp_name:
        temp_root = Path(temp_name)
        generated = generate_temp_assets(generator, units, temp_root)
        expected_art_manifest = json.dumps(generated["art_manifest"], indent=2, sort_keys=False) + "\n"
        expected_animation_manifest = json.dumps(generated["animation_manifest"], indent=2, sort_keys=False) + "\n"
        compare_manifest_text("unit_art_manifest", UNIT_ART_MANIFEST_PATH, expected_art_manifest, errors)
        compare_manifest_text("unit_animation_manifest", UNIT_ANIMATION_MANIFEST_PATH, expected_animation_manifest, errors)
        for record in generated["assets"]:
            repo_path = res_path_to_disk(str(record["res_path"]))
            temp_path = Path(record["temp_path"])
            repo_hash = sha256_file(repo_path)
            temp_hash = sha256_file(temp_path)
            matches = repo_hash != "" and repo_hash == temp_hash
            if not matches:
                errors.append(
                    "%s for %s is not reproducible: repo=%s generated=%s path=%s"
                    % (record["surface"], record["unit_id"], repo_hash, temp_hash, record["res_path"])
                )
            asset_records.append({
                "unit_id": record["unit_id"],
                "surface": record["surface"],
                "res_path": record["res_path"],
                "repo_sha256": repo_hash,
                "generated_sha256": temp_hash,
                "matches": matches,
            })

    payload = {
        "ok": not errors,
        "unit_count": len(units),
        "asset_count": len(asset_records),
        "matching_asset_count": sum(1 for record in asset_records if bool(record.get("matches", False))),
        "manifest_count": 2,
        "matching_manifest_count": 2 - sum(1 for message in errors if "manifest text drifted" in message),
        "assets": asset_records,
        "errors": errors,
    }
    (ARTIFACT_DIR / "report.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if errors:
        for message in errors:
            print(f"ERROR: {message}")
        return 1
    print(
        "UNIT_ART_REPRODUCIBILITY_REPORT "
        + json.dumps({
            "ok": True,
            "unit_count": len(units),
            "asset_count": len(asset_records),
            "matching_asset_count": len(asset_records),
            "matching_manifest_count": 2,
        }, sort_keys=True)
    )
    return 0


def load_generator():
    spec = importlib.util.spec_from_file_location("generate_unit_art_assets", GENERATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load generator from {GENERATOR_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def generate_temp_assets(generator, units: list[dict[str, Any]], temp_root: Path) -> dict[str, Any]:
    art_root = temp_root / "art" / "units"
    animation_root = temp_root / "art" / "animation" / "runtime" / "units"
    for subdir in ("portraits", "battle_icons", "battle_standees", "overworld_icons"):
        (art_root / subdir).mkdir(parents=True, exist_ok=True)
    animation_root.mkdir(parents=True, exist_ok=True)

    art_manifest = {
        "schema_version": 1,
        "generator": "deterministic_unit_art_assets_v1",
        "source": "content/units.json",
        "surface_sizes": {
            "portrait": {"width": generator.PORTRAIT_SIZE[0], "height": generator.PORTRAIT_SIZE[1]},
            "battle_icon": {"width": generator.BATTLE_ICON_SIZE[0], "height": generator.BATTLE_ICON_SIZE[1]},
            "battle_standee": {"width": generator.BATTLE_STANDEE_SIZE[0], "height": generator.BATTLE_STANDEE_SIZE[1]},
            "overworld_icon": {"width": generator.OVERWORLD_ICON_SIZE[0], "height": generator.OVERWORLD_ICON_SIZE[1]},
        },
        "items": [],
    }
    animation_manifest = {
        "schema_id": "unit_animation_manifest_v1",
        "generator": "deterministic_unit_animation_assets_v1",
        "source": "content/units.json",
        "surface": "battle_troop_sprite_sheet",
        "frame_size": {"width": generator.ANIMATION_FRAME_SIZE[0], "height": generator.ANIMATION_FRAME_SIZE[1]},
        "frames_per_state": generator.ANIMATION_FRAMES_PER_STATE,
        "sheet_size": {
            "width": generator.ANIMATION_FRAME_SIZE[0] * generator.ANIMATION_FRAMES_PER_STATE,
            "height": generator.ANIMATION_FRAME_SIZE[1] * len(generator.BATTLE_TROOP_ANIMATION_STATES),
        },
        "states": generator.BATTLE_TROOP_ANIMATION_STATES,
        "items": [],
    }
    assets: list[dict[str, Any]] = []
    for unit in units:
        unit_id = str(unit["id"])
        faction_key = str(unit.get("faction_id") or unit.get("affiliation") or "neutral")
        if faction_key == "":
            faction_key = "neutral"
        palette = generator.PALETTES.get(faction_key, generator.PALETTES["neutral"])
        motif = generator.motif_for_unit(unit)
        initials = generator.initials_for(str(unit.get("name", unit_id)))
        portrait_path = art_root / "portraits" / f"{unit_id}.png"
        battle_path = art_root / "battle_icons" / f"{unit_id}.png"
        standee_path = art_root / "battle_standees" / f"{unit_id}.png"
        overworld_path = art_root / "overworld_icons" / f"{unit_id}.png"
        animation_path = animation_root / f"{unit_id}.png"

        curated_source = generator.load_curated_character_source(unit_id)
        if not generator.preserve_authored_asset(unit_id, "portrait", portrait_path):
            if curated_source is None:
                generator.draw_portrait(unit, palette, motif, initials, portrait_path)
            else:
                generator.draw_curated_portrait(unit, palette, curated_source, portrait_path)
        if not generator.preserve_authored_asset(unit_id, "battle_icon", battle_path):
            if curated_source is None:
                generator.draw_battle_icon(unit, palette, motif, initials, battle_path)
            else:
                generator.draw_curated_battle_icon(unit, palette, curated_source, battle_path)
        if not generator.preserve_authored_asset(unit_id, "battle_standee", standee_path):
            if curated_source is None:
                generator.draw_battle_standee(unit, palette, motif, initials, standee_path)
            else:
                generator.draw_curated_battle_standee(unit, palette, curated_source, standee_path)
        if not generator.preserve_authored_asset(unit_id, "overworld_icon", overworld_path):
            if curated_source is None:
                generator.draw_overworld_icon(unit, palette, motif, initials, overworld_path)
            else:
                generator.draw_curated_overworld_icon(unit, palette, curated_source, overworld_path)
        if not generator.preserve_authored_asset(unit_id, "battle_animation_sheet", animation_path):
            if curated_source is None:
                generator.draw_battle_troop_animation_sheet(unit, palette, motif, initials, animation_path)
            else:
                generator.draw_curated_battle_troop_animation_sheet(unit, palette, curated_source, animation_path)

        art_record = {
            "id": unit_id,
            "unit_id": unit_id,
            "name": str(unit.get("name", unit_id)),
            "faction_id": faction_key,
            "tier": int(unit.get("tier", 1)),
            "role": str(unit.get("role", "")),
            "motif": motif,
            "portrait": f"res://art/units/portraits/{unit_id}.png",
            "battle_icon": f"res://art/units/battle_icons/{unit_id}.png",
            "battle_standee": f"res://art/units/battle_standees/{unit_id}.png",
            "battle_standee_anchor": {"x": 0.5, "y": 0.973214},
            "overworld_icon": f"res://art/units/overworld_icons/{unit_id}.png",
        }
        animation_record = {
            "id": unit_id,
            "unit_id": unit_id,
            "name": str(unit.get("name", unit_id)),
            "faction_id": faction_key,
            "tier": int(unit.get("tier", 1)),
            "role": str(unit.get("role", "")),
            "motif": motif,
            "sprite_sheet": f"res://art/animation/runtime/units/{unit_id}.png",
            "states": [state["state"] for state in generator.BATTLE_TROOP_ANIMATION_STATES],
        }
        provenance = generator.curated_source_provenance(unit_id)
        if provenance:
            art_record.update(provenance)
            animation_record.update(provenance)
        art_manifest["items"].append(art_record)
        animation_manifest["items"].append(animation_record)
        assets.extend([
            {"unit_id": unit_id, "surface": "portrait", "res_path": f"res://art/units/portraits/{unit_id}.png", "temp_path": str(portrait_path)},
            {"unit_id": unit_id, "surface": "battle_icon", "res_path": f"res://art/units/battle_icons/{unit_id}.png", "temp_path": str(battle_path)},
            {"unit_id": unit_id, "surface": "battle_standee", "res_path": f"res://art/units/battle_standees/{unit_id}.png", "temp_path": str(standee_path)},
            {"unit_id": unit_id, "surface": "overworld_icon", "res_path": f"res://art/units/overworld_icons/{unit_id}.png", "temp_path": str(overworld_path)},
            {"unit_id": unit_id, "surface": "battle_animation_sheet", "res_path": f"res://art/animation/runtime/units/{unit_id}.png", "temp_path": str(animation_path)},
        ])
    return {
        "art_manifest": art_manifest,
        "animation_manifest": animation_manifest,
        "assets": assets,
    }


def compare_manifest_text(label: str, path: Path, expected: str, errors: list[str]) -> None:
    actual = path.read_text(encoding="utf-8") if path.exists() else ""
    if actual != expected:
        errors.append(f"{label} manifest text drifted from generator output.")


def res_path_to_disk(path: str) -> Path:
    if not path.startswith("res://"):
        return ROOT / path
    return ROOT / path.removeprefix("res://")


def sha256_file(path: Path) -> str:
    if not path.exists():
        return ""
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


if __name__ == "__main__":
    raise SystemExit(main())
