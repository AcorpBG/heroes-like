#!/usr/bin/env python3
"""Run the single consolidated Twelve Command Relic Marches smoke."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / ".artifacts/twelve_command_relic_marches_smoke/report.json"
MANIFEST = ROOT / "art/artifacts/source/generated/command_relic_marches/manifest.json"
SCENE = "res://tests/twelve_command_relic_marches_smoke.tscn"


def verify_manifest() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("generator_mode") != "built_in_imagegen" or len(manifest.get("items", [])) != 12:
        raise SystemExit("unexpected twelve-command-relic generated-source provenance")
    atlas = ROOT / manifest["field_atlas_path"].removeprefix("res://")
    if hashlib.sha256(atlas.read_bytes()).hexdigest() != manifest.get("field_atlas_sha256"):
        raise SystemExit(f"field atlas hash mismatch: {atlas}")
    for item in manifest["items"]:
        for path_key, hash_key in (("source_path", "source_sha256"), ("runtime_path", "runtime_sha256")):
            asset = ROOT / item[path_key].removeprefix("res://")
            if hashlib.sha256(asset.read_bytes()).hexdigest() != item[hash_key]:
                raise SystemExit(f"hash mismatch for {asset}")
        if not item.get("prompt") or not item.get("generation_original") or not item.get("accessible_description"):
            raise SystemExit(f"incomplete prompt or accessibility provenance for {item.get('artifact_id')}")


def main() -> int:
    godot = shutil.which("godot4") or shutil.which("godot")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print("Godot 4 and xvfb-run are required", file=sys.stderr)
        return 2
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        timeout=900, check=False,
    )
    print(result.stdout, end="")
    if result.returncode:
        return result.returncode
    verify_manifest()
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    expected = {
        "ok": True, "case_count": 12, "exact_launch_count": 12,
        "battle_victory_count": 36, "artifact_collection_count": 12,
        "artifact_auto_equip_count": 12, "artifact_bonus_exact_count": 12,
        "exact_inventory_art_count": 12, "exact_field_art_count": 12,
        "objective_victory_count": 12, "save_round_trip_count": 12,
        "save_version": 9, "single_consolidated_smoke": True,
    }
    for key, value in expected.items():
        if report.get(key) != value:
            raise SystemExit(f"unexpected {key}: {report.get(key)!r} != {value!r}")
    contact = ROOT / report["contact_sheet_path"].removeprefix("res://")
    if not contact.is_file():
        raise SystemExit("twelve-command-relic contact sheet is missing")
    print("TWELVE_COMMAND_RELIC_MARCHES_SMOKE VERIFIED " + json.dumps({key: report[key] for key in expected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
