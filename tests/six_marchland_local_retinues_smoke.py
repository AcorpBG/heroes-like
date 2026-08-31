#!/usr/bin/env python3
"""Run the single consolidated Six Marchland Local Retinues smoke."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / ".artifacts/six_marchland_local_retinues_smoke/report.json"
UNIT_SOURCE_MANIFEST = ROOT / "art/units/source/generated/marchland_local_retinues/manifest.json"
BUILDING_SOURCE_MANIFEST = ROOT / "art/towns/source/generated/buildings/marchland_local_retinues/manifest.json"
SCENE = "res://tests/six_marchland_local_retinues_smoke.tscn"


def verify_manifest(path: Path) -> None:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("generator_mode") != "built_in_imagegen" or len(manifest.get("items", [])) != 6:
        raise SystemExit(f"unexpected generated-source provenance: {path}")
    for item in manifest["items"]:
        for path_key, hash_key in (("source_path", "source_sha256"), ("curated_path", "curated_sha256")):
            asset = ROOT / item[path_key].removeprefix("res://")
            if hashlib.sha256(asset.read_bytes()).hexdigest() != item[hash_key]:
                raise SystemExit(f"hash mismatch for {asset}")
        if not item.get("prompt") or not item.get("original_generated_path"):
            raise SystemExit(f"missing prompt provenance in {path}")


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
        timeout=600, check=False,
    )
    print(result.stdout, end="")
    if result.returncode:
        return result.returncode
    verify_manifest(UNIT_SOURCE_MANIFEST)
    verify_manifest(BUILDING_SOURCE_MANIFEST)
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    expected = {
        "ok": True, "case_count": 6, "exclusive_route_count": 6,
        "five_stack_company_count": 6, "town_build_count": 6,
        "town_recruit_count": 6, "battle_victory_count": 6,
        "battle_art_count": 6, "save_round_trip_count": 6,
        "save_version": 9, "single_consolidated_smoke": True,
    }
    for key, value in expected.items():
        if report.get(key) != value:
            raise SystemExit(f"unexpected {key}: {report.get(key)!r} != {value!r}")
    contact = ROOT / report["contact_sheet_path"].removeprefix("res://")
    if not contact.is_file():
        raise SystemExit("local-retinue contact sheet is missing")
    print("SIX_MARCHLAND_LOCAL_RETINUES_SMOKE VERIFIED " + json.dumps({key: report[key] for key in expected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
