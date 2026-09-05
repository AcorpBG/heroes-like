#!/usr/bin/env python3
"""Check current input flows and isolate a pre-existing town balance failure.

Existing GDScript fixtures remain the independent gameplay/input assertions.
Python selects a bounded current-UI subset or a method-matched old lookup owner;
it never modifies rules, assets, save data, or expected gameplay outcomes.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from full_play_runtime_profile import ROOT, OUTPUT
from full_play_large_session_profile import REFERENCE

INPUT_CASES = [
    "_check_overworld_focus_and_movement_key",
    "_check_overworld_controller_movement",
    "_check_overworld_controller_route_selection",
    "_check_overworld_end_turn_confirmation_cancel",
]


def run_scene(source: str, work: Path, out: Path, label: str, rendered: bool, accessibility: str) -> dict:
    script = work / (label + ".gd")
    script.write_text(source)
    scene = work / (label + ".tscn")
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
    env = dict(os.environ, XDG_DATA_HOME=str(out / (label + "_data")))
    command = ["godot4", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", accessibility, "res://" + str(scene.relative_to(ROOT))]
    command = ["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24"] + command if rendered else command + ["--headless"]
    with (out / (label + ".log")).open("w") as log:
        result = subprocess.run(["timeout", "900s"] + command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=920)
    lines = (out / (label + ".log")).read_text().splitlines()
    return {"returncode": result.returncode, "errors": [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line], "lines": lines}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--case", choices=["town_balance_control", "active_input"], required=True)
    parser.add_argument("--accessibility", choices=["auto", "disabled"], default="auto")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("invalid label")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="compatibility-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        if args.case == "active_input":
            source = (ROOT / "tests/active_play_keyboard_focus_smoke.gd").read_text()
            start = source.index("func _run() -> void:")
            end = source.index("\nfunc ", start + 1)
            replacement = "func _run() -> void:\n"
            for name in INPUT_CASES:
                assert "func " + name + "(" in source
                replacement += f'\tif not await {name}():\n\t\treturn\n\tprint("ACTIVE_INPUT_CASE {name} PASS")\n'
            replacement += '\tprint("ACTIVE_INPUT_COMPATIBILITY PASS")\n\tget_tree().quit(0)\n'
            result = run_scene(source[:start] + replacement + source[end:], work, out, "input", True, args.accessibility)
            passed = [name for name in INPUT_CASES if "ACTIVE_INPUT_CASE " + name + " PASS" in result["lines"]]
            report = {"ok": result["returncode"] == 0 and not result["errors"] and passed == INPUT_CASES, "passed": passed, "expected": INPUT_CASES, "returncode": result["returncode"], "runtime_errors": result["errors"], "accessibility": args.accessibility,
                      "boundary": "Four unchanged physical Overworld keyboard/controller/mouse assertions. Retired numbered-slot, Town TabBar and pre-casualty-report Battle route cases are not run or claimed passed. Current named files, Town icon/layout, Battle controller-board and actual dialog button regressions run separately. Disabled accessibility isolates the recorded engine AT-SPI crash, not UI focus rules."}
        else:
            source = (ROOT / "tests/town_development_save_resume_report.gd").read_text()
            target = "for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):"
            assert source.count(target) == 1
            source = source.replace(target, 'for town_id in ["town_moonbite_reedshrine"]:')
            reference = work / "reference_content.gd"
            legacy = subprocess.check_output(["git", "show", REFERENCE + ":scripts/autoload/ContentService.gd"], cwd=ROOT, text=True)
            reference.write_text(re.sub(r"^class_name .*\n", "", legacy, flags=re.M))
            reports = {}
            results = {}
            for label in ["control", "current"]:
                probe = source
                if label == "control":
                    probe = probe.replace("func _run() -> void:\n", 'func _run() -> void:\n\tContentService.set_script(load("res://%s"))\n' % reference.relative_to(ROOT), 1)
                result = run_scene(probe, work, out, label, False, "auto")
                rows = [json.loads(line.split(" ", 1)[1]) for line in result["lines"] if line.startswith("TOWN_DEVELOPMENT_SAVE_RESUME_REPORT ")]
                reports[label] = rows[-1] if rows else {}
                results[label] = {k: v for k, v in result.items() if k != "lines"}
            expected_error = ["town_moonbite_reedshrine did not complete development after save/resume within 30 turns"]
            current = reports["current"]
            row = current.get("towns", {}).get("town_moonbite_reedshrine", {})
            same = bool(current) and current == reports["control"]
            ok = same and current.get("errors") == expected_error and row.get("save_resume_ok") and row.get("same_day_guard_after_restore") and all(r["returncode"] == 1 and not r["errors"] for r in results.values())
            report = {"ok": bool(ok), "exact_report_parity": same, "reference": REFERENCE, "runs": results, "reports": reports,
                      "boundary": "Both old and indexed lookups fail the same authored 30-day completion budget with identical full reports. This proves no lookup regression; it does NOT turn the failing balance gate into a pass. Save/resume and same-day build guards must still pass. No balance change is made."}
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "reports"}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
