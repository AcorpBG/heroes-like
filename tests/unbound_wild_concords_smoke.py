#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "UNBOUND_WILD_CONCORDS_SMOKE"
REPORT_PATH = ROOT / ".artifacts" / "unbound_wild_concords_smoke" / "report.json"
CAPTURE_DIR = ROOT / ".artifacts" / "unbound_wild_concords_smoke" / "captures"
SCENE = "res://tests/unbound_wild_concords_smoke.tscn"


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing godot4 or xvfb-run", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["UNBOUND_WILD_CONCORD_CAPTURE_DIR"] = str(CAPTURE_DIR)
    completed = subprocess.run(
        [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=300,
        check=False,
    )
    print(completed.stdout, end="")
    if completed.returncode != 0:
        return completed.returncode
    if not REPORT_PATH.is_file():
        print(f"{REPORT_ID} missing report: {REPORT_PATH}", file=sys.stderr)
        return 1
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    rows = report.get("rows", [])
    valid_rows = len(rows) == 6 and all(
        row.get("battle_payload_count") == 3
        and row.get("army_objective_met") is True
        and row.get("scenario_victory") is True
        and row.get("exact_identity_art") is True
        and row.get("save_round_trip_exact") is True
        and len(row.get("unit_ids", [])) == 2
        and Path(row.get("capture_path", "")).is_file()
        for row in rows
    )
    expected = {
        "ok": True,
        "case_count": 6,
        "save_version": 9,
    }
    failures = [
        f"{key}={report.get(key)!r}, expected {value!r}"
        for key, value in expected.items()
        if report.get(key) != value
    ]
    if not valid_rows:
        failures.append("six live route/art/save rows were not exact")
    if not rows or rows[0].get("audio_runtime_validated") is not True:
        failures.append("consolidated Vorbis runtime validation was not recorded")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    summary = {
        "ok": True,
        "scenario_count": 6,
        "battle_payload_count": sum(row["battle_payload_count"] for row in rows),
        "dual_unit_route_count": 6,
        "exact_identity_art_count": 6,
        "save_round_trip_count": 6,
        "audio_runtime": "vorbis_44100_stereo",
        "single_consolidated_smoke": True,
    }
    print(f"{REPORT_ID} VERIFIED {json.dumps(summary, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
