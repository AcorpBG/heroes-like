#!/usr/bin/env python3
"""Run the single consolidated Six Marchland Seats gameplay smoke."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / ".artifacts/six_marchland_seats_smoke/report.json"
CAPTURES = ROOT / ".artifacts/six_marchland_seats_smoke/captures"
MANIFEST = ROOT / "art/towns/source/generated/marchland_seats/manifest.json"
SCENE = "res://tests/six_marchland_seats_smoke.tscn"


def main() -> int:
    godot = shutil.which("godot4") or shutil.which("godot")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print("Godot 4 and xvfb-run are required", file=sys.stderr)
        return 2
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    CAPTURES.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["SIX_MARCHLAND_SEATS_CAPTURE_DIR"] = str(CAPTURES)
    result = subprocess.run(
        [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=600,
        check=False,
    )
    print(result.stdout, end="")
    if result.returncode:
        return result.returncode
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for item in manifest["items"]:
        for path_key, hash_key in (("source_path", "source_sha256"), ("runtime_path", "runtime_sha256")):
            path = ROOT / item[path_key].removeprefix("res://")
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
            if actual != item[hash_key]:
                raise SystemExit(f"hash mismatch for {path}")
    expected = {
        "ok": True,
        "case_count": 6,
        "direct_battle_victory_count": 24,
        "counterstroke_battle_victory_count": 6,
        "named_rival_count": 6,
        "town_build_count": 6,
        "town_recruit_count": 6,
        "exact_scenic_art_count": 6,
        "scenario_victory_count": 6,
        "save_round_trip_count": 6,
        "map_capture_count": 6,
        "save_version": 9,
        "single_consolidated_smoke": True,
    }
    for key, value in expected.items():
        if report.get(key) != value:
            raise SystemExit(f"unexpected {key}: {report.get(key)!r} != {value!r}")
    contact = ROOT / report["contact_sheet_path"].removeprefix("res://")
    if not contact.is_file():
        raise SystemExit("Marchland Seats contact sheet is missing")
    print("SIX_MARCHLAND_SEATS_SMOKE VERIFIED " + json.dumps({key: report[key] for key in expected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
