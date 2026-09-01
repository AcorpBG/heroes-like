#!/usr/bin/env python3
"""Run the one consolidated Uncrowned Circuit content smoke."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "UNCROWNED_CIRCUIT_CAMPAIGN_SMOKE"
REPORT_PATH = ROOT / ".artifacts/uncrowned_circuit_campaign_smoke/report.json"
CAPTURE_DIR = ROOT / ".artifacts/uncrowned_circuit_campaign_smoke/captures"
FIELD_MANIFEST = ROOT / "art/overworld/source/generated/resource_sites/uncrowned_sovereign_roads_wave1/manifest.json"
CAMPAIGN_MANIFEST = ROOT / "art/campaigns/source/generated/uncrowned_circuit/manifest.json"
SCENE = "res://tests/uncrowned_circuit_campaign_smoke.tscn"


def verify_manifest(path: Path, expected_items: int) -> None:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("generation_mode", manifest.get("generator_mode")) != "built_in_image_gen":
        raise SystemExit(f"unexpected generation mode: {path}")
    assets = manifest.get("items", manifest.get("assets", []))
    if len(assets) != expected_items:
        raise SystemExit(f"unexpected identity count in {path}: {len(assets)}")
    for item in assets:
        for path_key, hash_key in (("source_path", "source_sha256"), ("runtime_path", "runtime_sha256")):
            if path_key not in item:
                continue
            asset = ROOT / str(item[path_key]).removeprefix("res://")
            if hashlib.sha256(asset.read_bytes()).hexdigest() != item[hash_key]:
                raise SystemExit(f"hash mismatch for {asset}")


def main() -> int:
    godot = shutil.which("godot4") or shutil.which("godot")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing Godot 4 or xvfb-run", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["UNCROWNED_CIRCUIT_CAPTURE_DIR"] = str(CAPTURE_DIR)
    completed = subprocess.run(
        [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=600, check=False,
    )
    print(completed.stdout, end="")
    if completed.returncode != 0:
        return completed.returncode
    verify_manifest(FIELD_MANIFEST, 6)
    verify_manifest(CAMPAIGN_MANIFEST, 7)
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {
        "ok": True, "case_count": 6, "exact_campaign_launch_count": 6,
        "exact_lead_count": 6, "resource_only_carryover_count": 6,
        "live_build_count": 6, "live_recruit_count": 6,
        "production_battle_count": 18, "live_throne_claim_count": 6,
        "witness_handoff_count": 6, "scenario_victory_count": 6,
        "save_round_trip_count": 6, "campaign_art_identity_count": 7,
        "field_art_identity_count": 6, "campaign_complete": True,
        "save_version": 9, "single_consolidated_smoke": True,
    }
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    captures = sorted(CAPTURE_DIR.glob("*.png")) if CAPTURE_DIR.is_dir() else []
    if len(captures) != 6:
        failures.append(f"capture_count={len(captures)}, expected 6")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
