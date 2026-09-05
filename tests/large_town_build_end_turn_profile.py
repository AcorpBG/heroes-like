#!/usr/bin/env python3
"""Profile real Large-town purchases and full turns with isolated save data."""
from __future__ import annotations

import argparse
import json
import os
import platform
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / ".artifacts" / "large_town_build_end_turn_20260905"
MARKER = "LARGE_TOWN_BUILD_END_TURN_REPORT "


def compare_states(output: Path, reference: Path) -> dict:
    """Compare full session trees: no ignored gameplay, identity or time fields."""
    states = sorted(output.glob("day_*.json"))
    rows = {}
    for state in states:
        other = reference / state.name
        rows[state.name] = other.is_file() and json.loads(state.read_text()) == json.loads(other.read_text())
    return {"ok": len(rows) == 12 and all(rows.values()), "reference": str(reference), "states": rows}


def validate_measurements(report: dict) -> list[str]:
    errors = []
    builds = [row for row in report.get("rows", []) if row.get("kind") == "build"]
    turns = [row for row in report.get("rows", []) if row.get("kind") == "end_turn"]
    if len(builds) != 3 or len(turns) != 3:
        errors.append("expected three successful purchases and three full turns")
    expected_buckets = {"before_signature", "action_lookup", "rules", "recap", "refresh", "presentation"}
    for row in builds:
        commits = [event for event in row.get("general", []) if event.get("event") == "build_commit"]
        if len(commits) != 1 or not expected_buckets <= commits[0].get("buckets_ms", {}).keys():
            errors.append(f"missing complete build_commit timing on day {row['day']}")
        if not row.get("ok") or row.get("usable_ms", 0) < row.get("commit_ms", 0):
            errors.append(f"purchase or controls-ready measurement failed on day {row['day']}")
    for row in turns:
        if not row.get("ok") or row.get("day_after") != row.get("day_before", 0) + 1:
            errors.append("End Turn did not advance exactly one day")
        if not {"autosave", "rules_end_turn", "refresh_after_end_turn"} <= row.get("general", {}).get("buckets_ms", {}).keys():
            errors.append("End Turn omitted rules, autosave or refresh timing")
    return errors


def town_probe_script() -> str:
    """Time inherited production methods; nested timings are inclusive.

    This script exists only in the disposable profiling scene. No replacement
    game logic or instrumentation is installed in the shipped Town scene.
    """
    script = '''extends "res://scenes/town/TownShell.gd"
var profile_calls := {}
func profile_add(name: String, started: int) -> void:
\tvar row: Dictionary = profile_calls.get(name, {"calls": 0, "inclusive_ms": 0.0})
\trow.calls += 1
\trow.inclusive_ms += float(Time.get_ticks_usec() - started) / 1000.0
\tprofile_calls[name] = row
'''
    for name, declaration, arguments, return_type in [
        ("_refresh", "first_render_minimal: bool = false", "first_render_minimal", "void"),
        ("_open_town_catalog", "mode: String", "mode", "void"),
        ("_select_build_action", "action_id: String", "action_id", "void"),
        ("_on_confirm_build_pressed", "", "", "void"),
        ("_commit_build_action", "action_id: String", "action_id", "void"),
        ("_selected_build_action", "actions_override: Variant = null", "actions_override", "Dictionary"),
        ("_build_action_for_id", "action_id: String, actions_override: Variant = null", "action_id, actions_override", "Dictionary"),
        ("_rebuild_build_actions", "actions_override: Variant = null", "actions_override", "void"),
        ("_validation_action_for_id", "action_id: String", "action_id", "Dictionary"),
        ("_record_town_action_result", "lane: String, action_id: String, action: Dictionary, result: Dictionary, before: Dictionary", "lane, action_id, action, result, before", "void"),
        ("_record_town_action_presentation", "lane: String, action_id: String, action: Dictionary, result: Dictionary, before: Dictionary", "lane, action_id, action, result, before", "void"),
    ]:
        script += f"\nfunc {name}({declaration}) -> {return_type}:\n\tvar started := Time.get_ticks_usec()\n\t"
        script += "var result_value = " if return_type != "void" else ""
        script += f'super.{name}({arguments})\n\tprofile_add("{name}", started)\n'
        if return_type != "void":
            script += "\treturn result_value\n"
    return script


SCRIPT = r'''
extends "res://tests/large_generated_map_runtime_profile_report.gd"

var rows := []
var failures := []
var query_probe := {}

func take_calls(town_shell) -> Dictionary:
	if OS.get_environment("HEROES_TOWN_PROFILE_SCRIPT") == "":
		return {}
	var result: Dictionary = town_shell.profile_calls.duplicate(true)
	town_shell.profile_calls.clear()
	return result

func profile_catalog_reads(session) -> Dictionary:
	var before := JSON.stringify(session.to_dict()).sha256_text()
	var start := Time.get_ticks_usec()
	var unscoped := TownRules.get_build_catalog(session)
	var unscoped_ms := _elapsed_ms(start)
	start = Time.get_ticks_usec()
	OverworldRules.begin_normalized_read_scope(session)
	TownRules.begin_read_scope(session)
	var scoped := TownRules.get_build_catalog(session)
	TownRules.end_read_scope(session)
	OverworldRules.end_normalized_read_scope(session)
	var scoped_ms := _elapsed_ms(start)
	var unchanged := before == JSON.stringify(session.to_dict()).sha256_text()
	var same: bool = unscoped == scoped
	if not same or not unchanged:
		failures.append("catalog read probe changed results or session")
	return {"unscoped_ms": unscoped_ms, "scoped_ms": scoped_ms, "equal_catalogs": same, "unchanged_session": unchanged, "row_count": scoped.size(), "note": "read-only isolated probe, not a production optimization"}

func capture_state(phase: String, session) -> void:
	# Serialize one detached snapshot outside the timed interval, without retaining
	# several Large worlds in memory and contaminating subsequent measurements.
	var path := OS.get_environment("HEROES_TOWN_TURN_PROFILE_OUTPUT").path_join("day_%d_%s.json" % [session.day, phase])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(session.to_dict(), "", false))
	f.close()

func _run() -> void:
	get_tree().current_scene = null
	OS.set_environment("HEROES_PROFILE_LOG", "1")
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "1")
	SaveService.validation_clear_general_profile_log()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1", 4, "land", false, SIZE_CLASS_ID, ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, FACTION_ID, HERO_ID)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_fail("Large setup failed")
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	session = SessionState.set_active_session(session)
	var signature := String(session.flags.get("generated_random_map_materialization", {}).get("materialized_map_signature", setup.get("generated_identity", {}).get("materialized_map_signature", "")))
	if signature != EXPECTED_MATERIALIZED_SIGNATURE:
		_fail("Generated signature changed: " + signature)
		return
	var overworld = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld)
	for frame in range(5):
		await get_tree().process_frame
	overworld.validation_set_end_turn_resolution_routing_enabled(false)
	var placement := ""
	for town in session.overworld.towns:
		if town.owner == "player":
			placement = String(town.placement_id)
			break
	for cycle in range(3):
		var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement)
		if not bool(visit.get("ok", false)):
			failures.append("town visit failed")
			break
		var town_shell = load("res://scenes/town/TownShell.tscn").instantiate()
		if OS.get_environment("HEROES_TOWN_PROFILE_SCRIPT") != "":
			town_shell.set_script(load(OS.get_environment("HEROES_TOWN_PROFILE_SCRIPT")))
		var start := Time.get_ticks_usec()
		add_child(town_shell)
		for frame in range(4):
			await get_tree().process_frame
		var entry_ms := _elapsed_ms(start)
		var town: Dictionary = TownRules.get_active_town(session)
		var action := {}
		for candidate in TownRules.get_build_actions(session):
			if not bool(candidate.get("disabled", true)):
				action = candidate
				break
		if action.is_empty():
			failures.append("no naturally affordable build on day %d" % session.day)
			town_shell.queue_free()
			break
		capture_state("before_build", session)
		if cycle == 0 and OS.get_environment("HEROES_TOWN_PROFILE_SCRIPT") != "":
			query_probe = profile_catalog_reads(session)
			print("LARGE_TOWN_QUERY_PROBE " + JSON.stringify(query_probe))
		take_calls(town_shell)
		SaveService.validation_clear_general_profile_log()
		start = Time.get_ticks_usec()
		town_shell.call("_open_town_catalog", "build")
		await get_tree().process_frame
		var open_ms := _elapsed_ms(start)
		var open_calls := take_calls(town_shell)
		start = Time.get_ticks_usec()
		town_shell.call("_select_build_action", String(action.id))
		await get_tree().process_frame
		var select_ms := _elapsed_ms(start)
		var select_calls := take_calls(town_shell)
		start = Time.get_ticks_usec()
		town_shell.call("_on_confirm_build_pressed")
		var commit_ms := _elapsed_ms(start)
		for frame in range(3):
			await get_tree().process_frame
		var refreshed_ms := _elapsed_ms(start)
		var commit_calls := take_calls(town_shell)
		while town_shell._town_action_input_blocker.visible and _elapsed_ms(start) < 30000.0:
			await get_tree().process_frame
		var usable_ms := _elapsed_ms(start)
		if town_shell._town_action_input_blocker.visible:
			failures.append("construction input blocker did not release")
		var building := String(action.id).trim_prefix("build:")
		var after: Dictionary = TownRules.get_active_town(session)
		var built: bool = building in after.get("built_buildings", []) and int(after.get("last_build_day", 0)) == session.day
		var build_row := {"kind": "build", "cycle": cycle, "day": session.day, "action_id": action.id, "ok": built, "entry_ms": entry_ms, "ledger_open_ms": open_ms, "selection_ms": select_ms, "commit_ms": commit_ms, "refreshed_ms": refreshed_ms, "general": SaveService.validation_general_profile_log_last_records(40)}
		rows.append(build_row)
		build_row.merge({"usable_ms": usable_ms, "method_calls": {"open": open_calls, "select": select_calls, "commit": commit_calls}})
		print("LARGE_TOWN_ACTION " + JSON.stringify(build_row))
		if not built:
			failures.append("purchase did not build " + building)
		capture_state("after_build", session)
		town_shell.validation_prepare_town_return_handoff()
		town_shell.queue_free()
		await get_tree().process_frame
		OverworldRules.clear_active_town_visit(session)
		session.game_state = "overworld"
		overworld.call("_refresh")
		capture_state("before_turn", session)
		SaveService.validation_clear_general_profile_log()
		var turn := await _profile_end_turn(overworld, session)
		turn.erase("profile")
		turn.erase("result")
		turn["kind"] = "end_turn"
		turn["cycle"] = cycle
		rows.append(turn)
		print("LARGE_TOWN_ACTION " + JSON.stringify(turn))
		capture_state("after_turn", session)
		if not bool(turn.get("ok", false)):
			failures.append("end turn failed")
			break
	var round_trip := _validate_generated_save_round_trip(session)
	if not bool(round_trip.get("ok", false)):
		failures.append("final save round trip failed")
	var report := {"ok": failures.is_empty(), "failures": failures, "seed": SEED, "signature": signature, "scenario_id": session.scenario_id, "map_size": {"width": 108, "height": 108}, "rows": rows, "save_round_trip": round_trip, "engine": Engine.get_version_info()}
	report["query_probe"] = query_probe
	print("LARGE_TOWN_BUILD_END_TURN_REPORT " + JSON.stringify(report))
	# Query probes are diagnostics only and never run in the production scene.
	overworld.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="baseline")
    parser.add_argument("--detail", action="store_true", help="test-only method timing and read-only catalog comparison")
    parser.add_argument("--compare", help="compare all 12 complete session snapshots against a prior label")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("label must contain lowercase letters, digits, underscores or hyphens")
    if args.compare and any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.compare):
        parser.error("comparison label must contain lowercase letters, digits, underscores or hyphens")
    output = ARTIFACTS / args.label
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="run-", dir=ARTIFACTS) as temporary:
        work = Path(temporary)
        script = work / "profile.gd"
        script.write_text(SCRIPT, encoding="utf-8")
        scene = work / "profile.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Profile" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT), encoding="utf-8")
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"), HEROES_TOWN_TURN_PROFILE_OUTPUT=str(output))
        if args.detail:
            town_script = work / "town_probe.gd"
            town_script.write_text(town_probe_script(), encoding="utf-8")
            env["HEROES_TOWN_PROFILE_SCRIPT"] = "res://" + str(town_script.relative_to(ROOT))
        command = ["timeout", "360s", shutil.which("godot4") or "godot", "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))]
        with (output / "runtime.log").open("w") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=380)
        lines = (output / "runtime.log").read_text().splitlines()
        markers = [line for line in lines if line.startswith(MARKER)]
        if not markers:
            print("\n".join(lines[-35:]))
            return result.returncode or 1
        report = json.loads(markers[-1][len(MARKER):])
        measurement_errors = validate_measurements(report)
        if measurement_errors:
            report["ok"] = False
            report["failures"].extend(measurement_errors)
        report["revision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["host"] = {"platform": platform.platform(), "cpu_count": os.cpu_count(), "processor": platform.processor(), "peak_child_rss_kib": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}
        report["detail_instrumentation"] = args.detail
        if args.compare:
            report["state_comparison"] = compare_states(output, ARTIFACTS / args.compare)
            if not report["state_comparison"]["ok"]:
                report["ok"] = False
                report["failures"].append("complete session snapshot comparison failed")
        if any("SCRIPT ERROR" in line for line in lines):
            report["ok"] = False
            report["failures"].append("runtime script error")
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"ok": report["ok"], "failures": report["failures"], "rows": [{k:v for k,v in row.items() if k not in ["general", "enemy_turn_profile", "method_calls"]} for row in report["rows"]], "report": str(output / "report.json")}))
        return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
