#!/usr/bin/env python3
"""Run the one consolidated Twelve Marchland Grand-Route Operations smoke."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "TWELVE_MARCHLAND_GRAND_ROUTE_OPERATIONS_SMOKE"
REPORT_PATH = ROOT / ".artifacts/twelve_marchland_grand_route_operations_smoke/report.json"
CAPTURE_DIR = ROOT / ".artifacts/twelve_marchland_grand_route_operations_smoke/captures"
MANIFEST = ROOT / "art/overworld/source/generated/resource_sites/marchland_grand_route_operations_wave1/manifest.json"
SCENE = "res://tests/twelve_marchland_grand_route_operations_smoke.tscn"


def verify_manifest() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("generation_mode") != "built_in_imagegen" or len(manifest.get("items", [])) != 12:
        raise SystemExit("unexpected grand-route generated-source provenance")
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
    env["TWELVE_MARCHLAND_GRAND_ROUTE_CAPTURE_DIR"] = str(CAPTURE_DIR)
    completed = subprocess.run([xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE], cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900, check=False)
    print(completed.stdout, end="")
    if completed.returncode: return completed.returncode
    verify_manifest()
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {"ok":True,"case_count":12,"exact_launch_count":12,"production_battle_count":12,"production_claim_count":12,"exact_art_count":12,"objective_victory_count":12,"save_round_trip_count":12,"capture_count":12,"save_version":9,"single_consolidated_smoke":True}
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    if len(report.get("rows", [])) != 12 or any(int(row.get("completion_day", 99)) >= 28 for row in report.get("rows", [])):
        failures.append("all twelve rows must win and save exactly before their Day 28 or Day 32 deadline")
    if len(list(CAPTURE_DIR.glob("*.png"))) != 12: failures.append("capture_count must be exactly 12")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__": raise SystemExit(main())
