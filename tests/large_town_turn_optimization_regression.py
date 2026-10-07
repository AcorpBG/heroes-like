#!/usr/bin/env python3
"""Check Town build preflight read boundaries and in-session save context reuse."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".artifacts/large_town_build_end_turn_20260905/regression"
MARKER = "LARGE_TOWN_TURN_OPTIMIZATION_REGRESSION "


SCRIPT = r'''
extends "res://tests/ai_known_world_memory_report.gd"

var optimization_errors := []

func check(condition: bool, label: String) -> void:
	if not condition:
		optimization_errors.append(label)

func _run() -> void:
	await _test_town_preflight_and_save_context()
	print("LARGE_TOWN_TURN_OPTIMIZATION_REGRESSION " + JSON.stringify({"ok": optimization_errors.is_empty(), "errors": optimization_errors, "save_version": SessionState.SAVE_VERSION}))
	get_tree().quit(0 if optimization_errors.is_empty() else 1)

func _test_town_preflight_and_save_context() -> void:
	var session = _base_session()
	session = SessionState.set_active_session(session)
	for town in session.overworld.towns:
		if town.owner == "player":
			OverworldRules.set_active_town_visit(session, String(town.placement_id))
			break
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	var selected := ""
	for action in TownRules.get_build_actions(session):
		if not bool(action.get("disabled", true)):
			selected = String(action.id)
			break
	check(selected != "", "town fixture has no enabled build")
	var expected_before := TownRules.town_action_consequence_signature(session)
	var expected_action: Dictionary = shell._validation_action_for_id(selected)
	var context: Dictionary = shell._prepare_build_read_context(selected)
	check(expected_before == context.before and expected_action == context.action, "preflight changed consequence/action values")
	check(TownRules._read_scope_depth == 0 and OverworldRules._normalized_read_scope_depth == 0, "preflight leaked a read scope across mutation")
	shell._select_build_action(selected)
	for resource_id in session.overworld.resources.keys():
		session.overworld.resources[resource_id] = 0
	var stale_before := JSON.stringify(session.to_dict())
	shell._on_confirm_build_pressed()
	check(stale_before == JSON.stringify(session.to_dict()), "confirmation reused stale affordability")
	for cycle in range(2):
		SaveService.validation_begin_summary_inspection_trace()
		var before := JSON.stringify(session.to_dict())
		var current: Dictionary = SaveService.build_current_session_save_context(session)
		var trace: Dictionary = SaveService.validation_end_summary_inspection_trace()
		for count in trace.values():
			check(int(count) == 0, "current action context inspected stored saves")
		var full: Dictionary = SaveService.build_in_session_save_surface(session)
		check(current.save_check == full.save_check and current.current_save_recap == full.current_save_recap, "current save context copy changed")
		check(before == JSON.stringify(session.to_dict()), "save context mutated session")
		session.overworld.resources.gold += 17
		session.day += 1
		SaveService.set_selected_manual_slot(2)
	shell.queue_free()
	await get_tree().process_frame
'''


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="probe-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / "regression.gd"
        script.write_text(SCRIPT)
        scene = work / "regression.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Regression" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT).as_posix())
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"), APPDATA=str(work / "data"), LOCALAPPDATA=str(work / "data"), HEROES_PROFILE_LOG="0", HEROES_STRATEGIC_AI_PROFILE="0")
        with (OUTPUT / "runtime.log").open("w") as log:
            result = subprocess.run(["godot4", "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + scene.relative_to(ROOT).as_posix()], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        lines = (OUTPUT / "runtime.log").read_text().splitlines()
        markers = [line[len(MARKER):] for line in lines if line.startswith(MARKER)]
        report = json.loads(markers[-1]) if markers else {"ok": False, "errors": lines[-25:]}
        if any("SCRIPT ERROR" in line for line in lines):
            report["ok"] = False
        (OUTPUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report))
        return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
