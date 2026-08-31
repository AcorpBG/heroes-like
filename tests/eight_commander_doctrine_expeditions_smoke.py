#!/usr/bin/env python3
"""Run the one consolidated Eight Commander Doctrine Expeditions smoke."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "EIGHT_COMMANDER_DOCTRINE_EXPEDITIONS_SMOKE"
REPORT_PATH = ROOT / ".artifacts/eight_commander_doctrine_expeditions_smoke/report.json"
CAPTURE_DIR = ROOT / ".artifacts/eight_commander_doctrine_expeditions_smoke/captures"
MANIFEST = ROOT / "art/overworld/source/generated/resource_sites/commander_doctrine_expeditions_wave1/manifest.json"
SCENE = "res://tests/eight_commander_doctrine_expeditions_smoke.tscn"


def verify_manifest() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("generation_mode") != "built_in_imagegen" or len(manifest.get("items", [])) != 8:
        raise SystemExit("unexpected commander-doctrine generated-source provenance")
    atlas = ROOT / manifest["runtime_atlas"].removeprefix("res://")
    if hashlib.sha256(atlas.read_bytes()).hexdigest() != manifest.get("runtime_atlas_sha256"):
        raise SystemExit(f"runtime atlas hash mismatch: {atlas}")
    for item in manifest["items"]:
        source = ROOT / item["source_path"].removeprefix("res://")
        if hashlib.sha256(source.read_bytes()).hexdigest() != item.get("source_sha256"):
            raise SystemExit(f"source hash mismatch: {source}")
        if not item.get("prompt") or not item.get("generation_original") or not item.get("accessible_description"):
            raise SystemExit(f"incomplete landmark provenance for {item.get('site_id')}")


def main() -> int:
    godot = shutil.which("godot4") or shutil.which("godot")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} requires Godot 4 and xvfb-run", file=sys.stderr)
        return 2
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["EIGHT_COMMANDER_DOCTRINE_CAPTURE_DIR"] = str(CAPTURE_DIR)
    completed = subprocess.run([xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE], cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900, check=False)
    print(completed.stdout, end="")
    if completed.returncode:
        return completed.returncode
    verify_manifest()
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {"ok":True,"case_count":8,"exact_launch_count":8,"production_battle_count":32,"production_claim_count":8,"exact_art_count":8,"objective_victory_count":8,"save_round_trip_count":8,"capture_count":8,"save_version":9,"single_consolidated_smoke":True}
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    if len(report.get("rows", [])) != 8 or any(int(row.get("completion_day", 99)) >= 19 for row in report.get("rows", [])):
        failures.append("all eight rows must win and save exactly before Day 19")
    captures = sorted(CAPTURE_DIR.glob("*.png"))
    if len(captures) != 8:
        failures.append(f"capture_count={len(captures)}, expected 8")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
