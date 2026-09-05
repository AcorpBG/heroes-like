#!/usr/bin/env python3
"""Exercise native player identity through actual adoption, AI and saves."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PROBE = r'''
extends Node
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
const Turns = preload("res://scripts/core/EnemyTurnRules.gd")
const Ai = preload("res://scripts/core/EnemyAdventureRules.gd")
const Battles = preload("res://scripts/core/BattleRules.gd")
const AutoBattle = preload("res://scripts/core/BattleAutoResolveRules.gd")
const Selection = preload("res://scripts/core/ScenarioSelectRules.gd")
const LegacyBridge = preload("__LEGACY_BRIDGE__")
func _ready() -> void:
	call_deferred("run")
func clone(session):
	var result = Store.new_session_data()
	result.from_dict(session.to_dict())
	return result
func run() -> void:
	var out := OS.get_environment("HEROES_PLAYERS_OUTPUT")
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("cases.json")))
	var service = ClassDB.instantiate("MapPackageService")
	var rows := []
	for case in cases:
		var generated: Dictionary = service.generate_random_map(case.config)
		var row := {"id": case.id, "generation_ok": generated.get("ok", false), "checks": {}}
		if bool(row.generation_ok):
			var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": "player_identity_validation"})
			var map_path := "user://players_" + String(case.id) + ".amap"
			var scenario_path := "user://players_" + String(case.id) + ".ascenario"
			var map_save: Dictionary = service.save_map_package(generated.map_document, map_path)
			var map_load: Dictionary = service.load_map_package(map_path)
			var scenario = generated.scenario_document
			scenario.configure({"scenario_id": scenario.get_scenario_id(), "scenario_hash": scenario.get_scenario_hash(), "map_ref": map_load.map_ref, "selection": scenario.get_selection(), "player_slots": scenario.get_player_slots(), "objectives": scenario.get_objectives(), "script_hooks": scenario.get_script_hooks(), "enemy_factions": scenario.get_enemy_factions(), "start_contract": scenario.get_start_contract()})
			var scenario_save: Dictionary = service.save_scenario_package(scenario, scenario_path)
			var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
			var boundary: Dictionary = adoption.session_boundary_record.duplicate(true)
			boundary.merge({"map_package_path": map_path, "scenario_package_path": scenario_path, "map_package_ref": map_load.map_ref, "scenario_package_ref": scenario_load.scenario_ref}, true)
			var session = Bridge.build_session_from_loaded_packages(map_load, scenario_load, boundary)
			var persisted := {"map_ref": map_load.map_ref, "scenario_ref": scenario_load.scenario_ref, "map_path": map_path, "scenario_path": scenario_path}
			session.flags["generated_random_map_provenance"] = Selection._native_random_map_provenance(case.config, generated, adoption, persisted, {"attempt_count": 1})
			session.flags["generated_random_map_package_paths"] = {"map_path": map_path, "scenario_path": scenario_path}
			row["checks"] = exercise(session, generated, int(case.players), int(case.get("computer_teams", 0)))
			row.checks["disk_package_adoption"] = bool(map_save.get("ok", false)) and bool(scenario_save.get("ok", false))
			row.checks.merge(exercise_ownership(session, String(case.id)))
			row.checks.merge(exercise_legacy(adoption, session, String(case.id)))
			row["slots"] = generated.scenario_document.get_player_slots()
			row["states"] = session.overworld.get("enemy_states", [])
			row["payload_hash"] = generated.get("final_payload_fnv1a32", "")
		rows.append(row)
		var progress := FileAccess.open(out.path_join("runtime_report.json"), FileAccess.WRITE)
		progress.store_string(JSON.stringify(rows, "  "))
		progress.close()
	service = null
	get_tree().quit()
func exercise(session, generated: Dictionary, count: int, computer_teams: int) -> Dictionary:
	var checks := {}
	var configs: Array = Turns._enemy_faction_configs_for_session(session)
	var states: Array = session.overworld.get("enemy_states", [])
	var ids := {}
	var faction_counts := {}
	for state in states:
		ids[Players.controller_id(state)] = true
		var faction := String(state.get("faction_id", ""))
		faction_counts[faction] = int(faction_counts.get(faction, 0)) + 1
	checks["distinct_native_players"] = session.overworld.get("players", []).size() == count and states.size() == count - 1 and ids.size() == count - 1
	checks["repeated_factions_retained"] = faction_counts.values().max() >= 2
	checks["source_slot_identity"] = true
	for slot in generated.scenario_document.get_player_slots():
		var expected := "player_%d" % int(slot.get("slot", 0))
		checks["source_slot_identity"] = checks["source_slot_identity"] and String(slot.get("player_id", "")) == expected and Players.player(session, expected).get("team_id", "") == slot.get("team_id", "")
	checks["source_teams_drive_alliances"] = true
	var teams := {}
	for first in session.overworld.players:
		teams[String(first.team_id)] = true
		for second in session.overworld.players:
			checks["source_teams_drive_alliances"] = checks["source_teams_drive_alliances"] and Players.allied(session, String(first.player_id), String(second.player_id)) == (String(first.team_id) == String(second.team_id))
	checks["source_teams_drive_alliances"] = checks["source_teams_drive_alliances"] and teams.size() == (computer_teams + 1 if computer_teams > 0 else count)
	checks["owned_towns_are_disjoint"] = true
	checks["commander_instances_are_distinct"] = true
	var seen_towns := {}
	var seen_commanders := {}
	for config in configs:
		var id := Players.controller_id(config)
		var entries: Array = Turns._owned_town_entries(session, id)
		checks["owned_towns_are_disjoint"] = checks["owned_towns_are_disjoint"] and entries.size() == 1
		for entry in entries:
			var town: Dictionary = entry.get("town", {})
			var placement_id := String(town.get("placement_id", ""))
			checks["owned_towns_are_disjoint"] = checks["owned_towns_are_disjoint"] and not seen_towns.has(placement_id) and Players.town_controller_id(town) == id
			seen_towns[placement_id] = true
		var state: Dictionary = Turns._find_state(states, id)
		checks["commander_instances_are_distinct"] = checks["commander_instances_are_distinct"] and not state.get("commander_roster", []).is_empty()
		for commander in state.get("commander_roster", []):
			var payload: Dictionary = commander.get("commander_state", {})
			var key := String(payload.get("id", ""))
			checks["commander_instances_are_distinct"] = checks["commander_instances_are_distinct"] and key != "" and not seen_commanders.has(key) and String(payload.get("faction_id", "")) == String(config.get("faction_id", ""))
			seen_commanders[key] = true
	var snapshot: Dictionary = session.to_dict()
	Rules.normalize_overworld_state(session)
	checks["normalization_preserves_controller_state"] = session.overworld.get("players") == snapshot.overworld.get("players") and session.overworld.get("enemy_states") == snapshot.overworld.get("enemy_states")
	var restored = clone(session)
	Rules.normalize_overworld_state(restored)
	checks["session_roundtrip_preserves_players"] = restored.overworld.get("players") == session.overworld.get("players") and restored.overworld.get("enemy_states") == session.overworld.get("enemy_states")
	checks["economy_changes_only_selected_player"] = true
	for config in configs:
		var one = clone(session)
		var id := Players.controller_id(config)
		var before: Array = one.overworld.enemy_states.duplicate(true)
		var result: Dictionary = Turns.run_enemy_town_economy_turn(one, id)
		checks["economy_changes_only_selected_player"] = checks["economy_changes_only_selected_player"] and bool(result.get("ok", false))
		var changed := false
		for previous in before:
			var key := Players.controller_id(previous)
			var after: Dictionary = Turns._find_state(one.overworld.enemy_states, key)
			if key == id:
				changed = after != previous
			else:
				checks["economy_changes_only_selected_player"] = checks["economy_changes_only_selected_player"] and after == previous
		checks["economy_changes_only_selected_player"] = checks["economy_changes_only_selected_player"] and changed
	var first = clone(session)
	var second = clone(session)
	var first_result: Dictionary = Rules.end_turn(first)
	var second_result: Dictionary = Rules.end_turn(second)
	checks["full_turn_deterministic"] = first_result == second_result and first.to_dict() == second.to_dict()
	checks["full_turn_keeps_all_opponents"] = first.overworld.enemy_states.size() == count - 1
	checks["task_boards_keep_player_ownership"] = true
	var task_count := 0
	for state in first.overworld.enemy_states:
		for task in state.get("hero_task_state", {}).get("tasks", []):
			task_count += 1
			checks["task_boards_keep_player_ownership"] = checks["task_boards_keep_player_ownership"] and Players.task_controller_id(task) == Players.controller_id(state) and String(task.get("owner_faction_id", "")) == String(state.faction_id)
	checks["task_boards_keep_player_ownership"] = checks["task_boards_keep_player_ownership"] and task_count > 0
	checks["task_count"] = task_count
	var next_first: Dictionary = Rules.end_turn(first)
	var next_second: Dictionary = Rules.end_turn(second)
	checks["second_turn_keeps_deterministic_player_state"] = next_first == next_second and first.to_dict() == second.to_dict() and first.overworld.enemy_states.size() == count - 1
	checks["spawn_ids_and_commanders_are_player_owned"] = true
	var hosts = clone(session)
	var host_ids := {}
	for config in configs:
		var id := Players.controller_id(config)
		var state: Dictionary = Turns._find_state(hosts.overworld.enemy_states, id)
		state["pressure"] = 999
		var spawn: Dictionary = Turns._spawn_raid(hosts, config, state)
		var placement := String(spawn.get("placement_id", ""))
		var raid: Dictionary = Ai._find_encounter_by_placement(hosts, placement).get("encounter", {})
		checks["spawn_ids_and_commanders_are_player_owned"] = checks["spawn_ids_and_commanders_are_player_owned"] and bool(spawn.get("ok", false)) and not raid.is_empty() and not host_ids.has(placement) and Players.raid_controller_id(raid) == id and String(raid.get("spawned_by_faction_id", "")) == String(config.get("faction_id", ""))
		host_ids[placement] = true
	checks["spawn_evidence"] = hosts.overworld.get("encounters", []).filter(func(record): return Players.raid_controller_id(record) != "")
	checks["runtime_faction_fields_are_content_ids"] = valid_faction_fields(hosts.to_dict()) and valid_faction_fields(first.to_dict())
	return checks

func valid_faction_fields(value) -> bool:
	if value is Dictionary:
		for key in value:
			if String(key).ends_with("faction_id") and value[key] is String and String(value[key]).begins_with("player_"):
				return false
			if not valid_faction_fields(value[key]):
				return false
	elif value is Array:
		for child in value:
			if not valid_faction_fields(child):
				return false
	return true

func exercise_ownership(source, case_id: String) -> Dictionary:
	var checks := {}
	var session = clone(source)
	var configs: Array = Turns._enemy_faction_configs_for_session(session)
	var config: Dictionary = configs[0]
	var id := Players.controller_id(config)
	var friendly = clone(source)
	friendly.overworld.players[0].team_id = String(config.team_id)
	var descriptors: Array = Ai._target_candidate_descriptors(friendly, config, true)
	checks["allied_human_towns_and_heroes_are_not_targets"] = true
	for target in descriptors:
		if target.get("target_kind", "") == "hero":
			checks["allied_human_towns_and_heroes_are_not_targets"] = false
		elif target.get("target_kind", "") == "town":
			var target_town: Dictionary = Rules._find_town_by_placement(friendly, String(target.get("target_placement_id", ""))).get("town", {})
			checks["allied_human_towns_and_heroes_are_not_targets"] = checks["allied_human_towns_and_heroes_are_not_targets"] and String(target_town.get("owner", "")) != "player"
	var sibling := ""
	for other in configs:
		if other.faction_id == config.faction_id and Players.controller_id(other) != id:
			sibling = Players.controller_id(other)
	var town: Dictionary = Turns._owned_town_entries(session, id)[0].town
	var placement := String(town.placement_id)
	var captured: Dictionary = Rules.transition_town_control(session, placement, "player", "", "player identity capture probe")
	checks["capture_retains_previous_player_front"] = bool(captured.get("ok", false)) and Players.controller_id(captured.get("town", {}).get("front", {})) == id and String(captured.get("town", {}).get("controlling_player_id", "")) == String(session.overworld.active_player_id)
	var retaken: Dictionary = Rules.transition_town_control(session, placement, "enemy", sibling, "player identity retake probe")
	checks["same_faction_town_transfer_changes_controller"] = bool(retaken.get("ok", false)) and Players.town_controller_id(retaken.get("town", {})) == sibling and Turns._owned_town_entries(session, id).is_empty() and Turns._owned_town_entries(session, sibling).size() == 2 and int(retaken.get("town", {}).get("owner_slot", -1)) == int(town.get("owner_slot", -2))
	var assault: Dictionary = Battles.create_town_assault_payload(session, placement)
	checks["town_battle_context_uses_current_controller"] = not assault.is_empty() and String(assault.get("context", {}).get("trigger_player_id", "")) == sibling and String(assault.get("context", {}).get("trigger_faction_id", "")) == String(config.faction_id)
	# This isolated authored mine fixture exercises capture/defense owners without
	# changing any generated package placement, mask, RNG or balancing rule.
	session = clone(source)
	var pos: Dictionary = session.overworld.hero_position
	session.overworld.resource_nodes = [{"placement_id": "identity_mine", "site_id": "site_ridge_quarry", "x": int(pos.x), "y": int(pos.y), "collected": false}]
	var state: Dictionary = Turns._find_state(session.overworld.enemy_states, id)
	state.pressure = 999
	var spawn: Dictionary = Turns._spawn_raid(session, config, state)
	var raid: Dictionary = Ai._find_encounter_by_placement(session, String(spawn.get("placement_id", ""))).get("encounter", {}).duplicate(true)
	raid.merge({"target_kind": "resource", "target_placement_id": "identity_mine", "target_reason_codes": ["site_defense", "defend_front"]}, true)
	var claimed: Dictionary = Ai._secure_resource_target(session, raid, state, id, config)
	var node: Dictionary = session.overworld.resource_nodes[0]
	checks["resource_capture_keeps_player_and_faction"] = Players.resource_controller_id(node) == id and String(node.get("collected_by_faction_id", "")) == String(config.faction_id)
	var control_label := Rules._resource_site_control_label(node, ContentService.get_resource_site(String(node.site_id)))
	checks["public_controller_label_uses_faction_and_player"] = String(ContentService.get_faction(String(config.faction_id)).name) in control_label and "Player 2" in control_label and not id in control_label
	checks["allied_sites_are_not_attack_targets"] = true
	var site := ContentService.get_resource_site(String(node.site_id))
	for other in configs:
		var other_id := Players.controller_id(other)
		checks["allied_sites_are_not_attack_targets"] = checks["allied_sites_are_not_attack_targets"] and Ai._resource_node_contestable_by_faction(node, site, other_id, session) == not Players.allied(session, id, other_id)
	var defense_raid: Dictionary = claimed.get("encounter", raid).duplicate(true)
	defense_raid.merge({"target_kind": "resource", "target_placement_id": "identity_mine", "target_reason_codes": ["site_defense", "defend_front"]}, true)
	var defended: Dictionary = Ai._defend_resource_target(session, defense_raid, claimed.get("state", state), id)
	node = session.overworld.resource_nodes[0]
	Rules.normalize_overworld_state(session)
	node = session.overworld.resource_nodes[0]
	checks["resource_defender_survives_normalization"] = not String(defended.get("event_message", "")).is_empty() and Players.defender_controller_id(node) == id and not Ai._active_resource_defender_entry(session, node, id).is_empty() and Ai._active_resource_defender_entry(session, node, sibling).is_empty()
	var commander_only: Dictionary = node.duplicate(true)
	commander_only.erase("ai_defended_by_player_id")
	checks["defender_commander_identity_precedes_faction"] = Players.defender_controller_id(commander_only) == id and Rules._resource_node_has_live_ai_defender(session, commander_only, site) and Players.defender_controller_id({"ai_defender_commander_state": null, "ai_defended_by_faction_id": "legacy"}) == "legacy"
	var human_capture = clone(session)
	var claim: Dictionary = Rules.capture_resource_after_defender_victory(human_capture, "identity_mine")
	var facts: Dictionary = claim.get("interaction_result", {}).get("mutation_facts", {})
	checks["human_resource_retake_remembers_actual_player"] = bool(claim.get("ok", false)) and Players.resource_controller_id(human_capture.overworld.resource_nodes[0]) == "player" and String(facts.get("previous_controller", "")) == id and String(facts.get("new_controller", "")) == "player"
	session.battle = Battles.create_resource_defense_payload(session, "identity_mine")
	session.game_state = "battle"
	checks["resource_battle_context_uses_defender_player"] = not session.battle.is_empty() and String(session.battle.get("context", {}).get("trigger_player_id", "")) == id and Battles._battle_enemy_faction_id(session) == id
	var before: Array = session.overworld.enemy_states.duplicate(true)
	Battles._add_enemy_treasury_resources(session, id, {"gold": 37})
	Battles._adjust_enemy_pressure(session, id, 3)
	Battles._set_enemy_siege_progress(session, id, 7)
	checks["battle_rewards_change_only_defender_player"] = true
	for previous in before:
		var key := Players.controller_id(previous)
		var after: Dictionary = Turns._find_state(session.overworld.enemy_states, key)
		checks["battle_rewards_change_only_defender_player"] = checks["battle_rewards_change_only_defender_player"] and (after == previous if key != id else int(after.treasury.gold) == int(previous.treasury.gold) + 37 and int(after.pressure) == int(previous.pressure) + 3 and int(after.siege_progress) == 7)
	var saved: Dictionary = SaveService.save_runtime_file_session(session, "players_battle_" + case_id)
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file("players_battle_" + case_id))
	checks["production_battle_save_preserves_ownership"] = bool(saved.get("ok", false)) and resumed != null and resumed.overworld.players == session.overworld.players and resumed.overworld.enemy_states == session.overworld.enemy_states and Battles._battle_enemy_faction_id(resumed) == id and Battles.battle_payload_can_resume(resumed)
	if resumed != null:
		var first: Dictionary = AutoBattle.resolve_active_battle(session)
		var second: Dictionary = AutoBattle.resolve_active_battle(resumed)
		checks["battle_resume_completes_deterministically"] = bool(first.get("completed", false)) and first == second and session.battle.is_empty() and resumed.battle.is_empty() and session.overworld.enemy_states == resumed.overworld.enemy_states
	return checks

func exercise_legacy(adoption: Dictionary, source, case_id: String) -> Dictionary:
	# Execute the actual committed pre-correction adapter, not a made-up fixture
	# that presumes which native slots the old runtime kept.
	var legacy = LegacyBridge.build_session_from_adoption(adoption)
	# The current native producer adds these fields; they did not exist in the
	# committed adapter's package inputs. Remove only that additive metadata.
	for town in legacy.overworld.towns:
		town.erase("controlling_player_id")
		town.erase("team_id")
	Rules.normalize_overworld_state(legacy)
	legacy.flags["generated_random_map_provenance"] = source.flags.generated_random_map_provenance.duplicate(true)
	legacy.flags["generated_random_map_package_paths"] = source.flags.generated_random_map_package_paths.duplicate(true)
	legacy.day = 4
	for state in legacy.overworld.enemy_states:
		state.treasury["gold"] = 12345
	Rules.normalize_overworld_state(legacy)
	var before: Array = legacy.overworld.enemy_states.duplicate(true)
	var saved: Dictionary = SaveService.save_runtime_file_session(legacy, "legacy_players_" + case_id)
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file("legacy_players_" + case_id))
	var checks := {"legacy_generated_save_keeps_pooled_history": bool(saved.get("ok", false)) and resumed != null and resumed.overworld.get("players", []).is_empty() and resumed.overworld.get("player_identity_mode", "") == "legacy_generated_faction_v0" and resumed.overworld.enemy_states == before and before.size() == 4}
	if resumed != null:
		var first: Dictionary = Rules.end_turn(legacy)
		var second: Dictionary = Rules.end_turn(resumed)
		checks["legacy_generated_resume_turn_matches"] = first == second and legacy.overworld.enemy_states == resumed.overworld.enemy_states
	return checks
'''

CHECKS = {
    "distinct_native_players", "repeated_factions_retained", "source_slot_identity",
    "source_teams_drive_alliances",
    "owned_towns_are_disjoint", "commander_instances_are_distinct",
    "normalization_preserves_controller_state", "session_roundtrip_preserves_players",
    "economy_changes_only_selected_player", "full_turn_deterministic",
    "full_turn_keeps_all_opponents", "spawn_ids_and_commanders_are_player_owned",
    "disk_package_adoption", "capture_retains_previous_player_front",
    "same_faction_town_transfer_changes_controller", "town_battle_context_uses_current_controller",
    "resource_capture_keeps_player_and_faction", "allied_sites_are_not_attack_targets",
    "resource_defender_survives_normalization", "resource_battle_context_uses_defender_player",
    "battle_rewards_change_only_defender_player", "production_battle_save_preserves_ownership",
    "battle_resume_completes_deterministically",
    "legacy_generated_save_keeps_pooled_history", "legacy_generated_resume_turn_matches",
    "runtime_faction_fields_are_content_ids",
    "task_boards_keep_player_ownership", "second_turn_keeps_deterministic_player_state",
    "allied_human_towns_and_heroes_are_not_targets",
    "defender_commander_identity_precedes_faction", "human_resource_retake_remembers_actual_player",
    "public_controller_label_uses_faction_and_player",
}


def failures(rows):
    return [{"case": row["id"], "check": check}
            for row in rows for check in CHECKS
            if row.get("checks", {}).get(check) is not True]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("label must be a safe path component")
    out = ROOT / ".artifacts/rmg_start_audit_20260905" / args.label
    out.mkdir(parents=True, exist_ok=False)
    cases = [{"id": f"players_{n}", "players": n, "config": {
        "seed": "10", "size": {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "medium"},
        "monster_strength": "weak", "player_constraints": {"human_count": 1, "computer_count": n-1, "player_count": n, "human_team_count": 1, "computer_team_count": 0},
    }} for n in (6, 8)]
    grouped = json.loads(json.dumps(cases[-1]))
    grouped["id"] = "players_8_teams"
    grouped["computer_teams"] = 2
    grouped["config"]["player_constraints"]["computer_team_count"] = 2
    cases.append(grouped)
    (out / "cases.json").write_text(json.dumps(cases, indent=2) + "\n")
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted((ROOT / "scripts").rglob("*.gd"))}
    with tempfile.TemporaryDirectory(prefix="players-adapter-", dir=out.parent) as temp:
        legacy_script = Path(temp) / "legacy_bridge.gd"
        legacy_source = subprocess.check_output(["git", "show", "df93e008ff8436811e58356107df71c3634be123:scripts/persistence/NativeRandomMapPackageSessionBridge.gd"], cwd=ROOT, text=True)
        legacy_script.write_text(legacy_source.replace("class_name NativeRandomMapPackageSessionBridge\n", "", 1))
        hashes["legacy_bridge_at_df93e008"] = hashlib.sha256(legacy_source.encode()).hexdigest()
        script = Path(temp) / "probe.gd"
        script.write_text(PROBE.replace("__LEGACY_BRIDGE__", "res://" + str(legacy_script.relative_to(ROOT))))
        scene = Path(temp) / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out / "data"), HEROES_PLAYERS_OUTPUT=str(out), HEROES_PROFILE_LOG="0")
        cmd = [shutil.which("godot4") or "godot", "--headless", "--path", str(ROOT), "--accessibility", "disabled", "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))]
        with (out / "runtime.log").open("w") as log:
            run = subprocess.Popen(cmd, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 900
            while run.poll() is None:
                log.flush()
                output = (out / "runtime.log").read_text()
                if "SCRIPT ERROR:" in output or time.monotonic() >= deadline:
                    run.terminate()
                    try:
                        run.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        run.kill()
                        run.wait(timeout=10)
                    break
                time.sleep(0.2)
    rows = json.loads((out / "runtime_report.json").read_text()) if (out / "runtime_report.json").exists() else []
    errors = [line for line in (out / "runtime.log").read_text().splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    failed = failures(rows)
    report = {"ok": run.returncode == 0 and len(rows) == len(cases) and not errors and not failed, "returncode": run.returncode, "failures": failed, "runtime_errors": errors, "runtime_source_sha256": hashes, "cases": rows}
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"ok": report["ok"], "failures": failed, "errors": errors, "output": str(out)}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
