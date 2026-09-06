#!/usr/bin/env python3
"""Check Town read boundaries and AI decision-local knowledge reuse."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".artifacts/large_town_build_end_turn_20260905/regression"
MARKER = "LARGE_TOWN_TURN_OPTIMIZATION_REGRESSION "


def legacy_queries() -> str:
    """Reference queries execute the same rules using uncached visibility reads.

    Do not copy a second AI policy into the test. Only disable the optimization's
    explicit preloaded inputs in temporary inherited query methods.
    """
    source = (ROOT / "scripts/core/EnemyAdventureRules.gd").read_text()
    result = 'extends "res://scripts/core/EnemyAdventureRules.gd"\n'
    for name in ["_target_candidate_descriptors", "_no_known_target_exploration_plan", "_no_known_target_frontier_sweep_plan"]:
        body = source.split("static func " + name + "(", 1)[1].split("\nstatic func ", 1)[0]
        original, replacement = (
            ("{} if include_unscouted else _enemy_target_knowledge_snapshot(session, config, faction_id)", "{}")
            if name == "_target_candidate_descriptors" else
            ("_enemy_target_currently_visible(session, config, faction_id, tile.x, tile.y, sources, int(path_context.get(\"level\", 0)))", "_enemy_target_currently_visible(session, config, faction_id, tile.x, tile.y, null, int(path_context.get(\"level\", 0)))")
        )
        if body.count(original) != 1:
            raise ValueError(f"{name}: cannot isolate the optimized input for a distinct reference query")
        body = body.replace(original, replacement)
        result += "\nstatic func legacy" + name + "(" + body
    return result


SCRIPT = r'''
extends "res://tests/ai_known_world_memory_report.gd"

var optimization_errors := []
var optimization_rows := []

func check(condition: bool, label: String) -> void:
	if not condition:
		optimization_errors.append(label)

func _run() -> void:
	var legacy = load(OS.get_environment("HEROES_LEGACY_QUERY_SCRIPT"))
	for scenario_id in ["three-hearth-auxiliary-charter", "bogbound-oath", "three-banner-field-commission", "rootway-graftmarch", "ashen-clausemarch", "false-channel-pursuit"]:
		var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		EnemyTurnRules.normalize_enemy_states(session)
		for faction in ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow", "faction_veilmourn"]:
			var config := {"faction_id": faction, "priority_target_placement_ids": []}
			var before := JSON.stringify(session.to_dict())
			var reference: Array = legacy.legacy_target_candidate_descriptors(session, config)
			var actual := EnemyAdventureRules._target_candidate_descriptors(session, config)
			check(reference == actual, "%s/%s descriptors differ" % [scenario_id, faction])
			for origin in [Vector2i(0, 0), Vector2i(3, 3)]:
				check(legacy.legacy_no_known_target_exploration_plan(session, config, origin) == EnemyAdventureRules._no_known_target_exploration_plan(session, config, origin), "exploration plan differs")
				check(legacy.legacy_no_known_target_frontier_sweep_plan(session, config, origin) == EnemyAdventureRules._no_known_target_frontier_sweep_plan(session, config, origin), "frontier sweep differs")
			check(before == JSON.stringify(session.to_dict()), "knowledge enumeration mutated session")
			optimization_rows.append({"scenario": scenario_id, "faction": faction, "descriptor_count": actual.size()})
	_test_knowledge_expiry_and_freshness()
	await _test_town_preflight_and_save_context()
	print("LARGE_TOWN_TURN_OPTIMIZATION_REGRESSION " + JSON.stringify({"ok": optimization_errors.is_empty(), "errors": optimization_errors, "query_rows": optimization_rows, "save_version": SessionState.SAVE_VERSION}))
	get_tree().quit(0 if optimization_errors.is_empty() else 1)

func _test_knowledge_expiry_and_freshness() -> void:
	var session = _base_session()
	var config := _enemy_config()
	for state in session.overworld.enemy_states:
		if String(state.get("faction_id", "")) == MIRECLAW:
			state["known_world_memory"] = {"scouted_targets": [
				{"target_kind": "resource", "target_id": "expired_first", "expires_day": session.day - 1},
				{"target_kind": "resource", "target_id": "expired_first", "expires_day": session.day + 5},
				{"target_kind": "resource", "target_id": "today", "expires_day": session.day},
				{"target_kind": "artifact", "target_id": "future", "expires_day": session.day + 1},
				{"target_kind": "", "target_id": "", "expires_day": session.day + 1},
			]}
	var snapshot := EnemyAdventureRules._enemy_target_knowledge_snapshot(session, config, MIRECLAW)
	for kind in ["resource", "artifact", "town", "encounter", ""]:
		for id in ["expired_first", "today", "future", "unknown", ""]:
			for force_known in [false, true]:
				var direct := EnemyAdventureRules._enemy_nonhero_target_known(session, config, MIRECLAW, kind, id, 10000, 10000, force_known)
				var reused := EnemyAdventureRules._enemy_nonhero_target_known(session, config, MIRECLAW, kind, id, 10000, 10000, force_known, snapshot)
				check(direct == reused, "memory expiry/first-match/forced knowledge differs")
	check(not bool(snapshot.scouted.get("resource:expired_first", true)), "duplicate memory changed first-match expiry")
	check(bool(snapshot.scouted.get("resource:today", false)), "same-day memory expired too early")
	check(not snapshot.sources.is_empty(), "freshness fixture has no sight source")
	var source: Dictionary = snapshot.sources[0]
	for town in session.overworld.towns:
		town.owner = "inactive"
	for node in session.overworld.resource_nodes:
		node.collected_by_faction_id = ""
	session.overworld.encounters = []
	var fresh := EnemyAdventureRules._enemy_target_knowledge_snapshot(session, config, MIRECLAW)
	check(fresh.sources.is_empty(), "new enumeration retained removed sight sources")
	check(EnemyAdventureRules._enemy_target_currently_visible(session, config, MIRECLAW, source.x, source.y, snapshot.sources), "old source fixture was not visible")
	check(not EnemyAdventureRules._enemy_target_currently_visible(session, config, MIRECLAW, source.x, source.y, fresh.sources), "current enumeration leaked stale visibility")

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
        legacy = work / "legacy_queries.gd"
        legacy.write_text(legacy_queries())
        script = work / "regression.gd"
        script.write_text(SCRIPT)
        scene = work / "regression.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Regression" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"), HEROES_LEGACY_QUERY_SCRIPT="res://" + str(legacy.relative_to(ROOT)), HEROES_PROFILE_LOG="0", HEROES_STRATEGIC_AI_PROFILE="0")
        with (OUTPUT / "runtime.log").open("w") as log:
            result = subprocess.run(["godot4", "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
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
