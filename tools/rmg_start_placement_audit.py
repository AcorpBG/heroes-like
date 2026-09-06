#!/usr/bin/env python3
"""Generated-start audit and entrance regressions, with Python orchestration.

The temporary Godot adapter invokes production generation/adoption and dumps
facts. Graph measurements below are diagnostics, never generation authority.
Success means evidence was collected, not that RMG has no defects or full parity.
"""
from __future__ import annotations

import argparse
from collections import Counter, deque
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".artifacts/rmg_start_audit_20260905"
PROBE = r'''
extends Node
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Selection = preload("res://scripts/core/ScenarioSelectRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const MapView = preload("res://scenes/overworld/OverworldMapView.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Ai = preload("res://scripts/core/EnemyAdventureRules.gd")
const Turns = preload("res://scripts/core/EnemyTurnRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Battles = preload("res://scripts/core/BattleRules.gd")
const AutoBattle = preload("res://scripts/core/BattleAutoResolveRules.gd")
const Scenario = preload("res://scripts/core/ScenarioRules.gd")
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var out := OS.get_environment("HEROES_RMG_AUDIT_OUTPUT")
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("cases.json")))
	var service = ClassDB.instantiate("MapPackageService")
	for case in cases:
		var started := Time.get_ticks_msec()
		var config: Dictionary = case.config
		var generated: Dictionary = service.generate_random_map(config, {"startup_path": "start_placement_audit"})
		var result := {"id": case.id, "config": config, "ok": generated.get("ok", false), "error_code": generated.get("error_code", ""), "normalized_config": generated.get("normalized_config", {})}
		if bool(result.ok):
			var map = generated.map_document
			var scenario = generated.scenario_document
			var objects := []
			for i in range(map.get_object_count()):
				objects.append(map.get_object_by_index(i))
			result.merge({"start_contract": scenario.get_start_contract(), "player_slots": scenario.get_player_slots(), "objects": objects, "terrain": map.get_terrain_layers(), "payload_fnv1a32": generated.get("final_payload_fnv1a32", ""), "payload_bytes": generated.get("final_payload_byte_count", 0), "metadata": map.get_metadata(), "map_size": {"width": map.get_width(), "height": map.get_height(), "levels": map.get_level_count()}})
			var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": "rmg_start_audit"})
			var session = Bridge.build_session_from_adoption(adoption)
			result["adoption_ok"] = adoption.get("ok", false)
			result["hero_position"] = session.overworld.get("hero_position", {})
			result["hero_id"] = session.hero_id
			result["enemy_states_before_normalization"] = session.overworld.get("enemy_states", []).duplicate(true)
			Rules.normalize_overworld_state(session)
			result["enemy_states"] = session.overworld.get("enemy_states", []).duplicate(true)
			result["towns"] = session.overworld.get("towns", []).duplicate(true)
			var pos := Rules.hero_position(session)
			var body_owners := []
			for family in ["towns", "map_objects", "encounters", "resource_nodes"]:
				for obj in session.overworld.get(family, []):
					if not Levels.on_level(obj, Levels.hero_level(session)):
						continue
					var tiles: Array = Rules._generated_body_tiles_for_placement(obj, bool(obj.get("blocking_body", true)))
					if family == "resource_nodes":
						var content: Dictionary = Rules._map_object_for_resource_node(obj)
						tiles = Rules._map_object_world_body_tiles(content, obj) if Rules._resource_node_blocks_body_tiles(obj, content) else []
					if pos in tiles:
						body_owners.append({"family": family, "placement_id": obj.get("placement_id", ""), "object_id": obj.get("object_id", ""), "level": obj.get("level", null), "package_block_tiles": obj.get("package_block_tiles", null), "body_tiles": obj.get("body_tiles", [])})
			result["hero_blocking_body_owners"] = body_owners
			var moves := []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var tile := pos + Vector2i(dx, dy)
					if tile.x < 0 or tile.y < 0 or tile.x >= map.get_width() or tile.y >= map.get_height():
						continue
					if not Rules.tile_is_blocked(session, tile.x, tile.y) and not Rules.tile_step_cuts_blocked_corner(session, pos, tile):
						moves.append({"x": tile.x, "y": tile.y})
			result["unblocked_first_steps"] = moves
			var runtime_blocked := []
			for y in range(map.get_height()):
				for x in range(map.get_width()):
					if Rules.tile_is_blocked(session, x, y):
						runtime_blocked.append({"x": x, "y": y, "level": Levels.hero_level(session)})
			result["runtime_blocked"] = runtime_blocked
			result["hero_tile_blocked"] = Rules.tile_is_blocked(session, pos.x, pos.y)
			if OS.get_environment("HEROES_RMG_AUDIT_ENTRANCE") == "1":
				result["entrance_actions"] = exercise_entrance(session, out.path_join(String(case.id) + "_session.json"))
			if OS.get_environment("HEROES_RMG_AUDIT_RENDER") == "1":
				var map_path := "user://audit_" + String(case.id) + ".amap"
				var scenario_path := "user://audit_" + String(case.id) + ".ascenario"
				var map_save: Dictionary = service.save_map_package(map, map_path)
				var map_load: Dictionary = service.load_map_package(map_path)
				scenario.configure({"scenario_id": scenario.get_scenario_id(), "scenario_hash": scenario.get_scenario_hash(), "map_ref": map_load.map_ref, "selection": scenario.get_selection(), "player_slots": scenario.get_player_slots(), "objectives": scenario.get_objectives(), "script_hooks": scenario.get_script_hooks(), "enemy_factions": scenario.get_enemy_factions(), "start_contract": scenario.get_start_contract()})
				var scenario_save: Dictionary = service.save_scenario_package(scenario, scenario_path)
				var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
				var boundary: Dictionary = adoption.session_boundary_record.duplicate(true)
				boundary["map_package_path"] = map_path
				boundary["scenario_package_path"] = scenario_path
				boundary["map_package_ref"] = map_load.map_ref
				boundary["scenario_package_ref"] = scenario_load.scenario_ref
				session = Bridge.build_session_from_loaded_packages(map_load, scenario_load, boundary)
				var persisted := {"map_ref": map_load.map_ref, "scenario_ref": scenario_load.scenario_ref, "map_path": map_path, "scenario_path": scenario_path}
				session.flags["generated_random_map_provenance"] = Selection._native_random_map_provenance(config, generated, adoption, persisted, {"attempt_count": 1})
				session.flags["generated_random_map_package_paths"] = {"map_path": map_path, "scenario_path": scenario_path}
				result["disk_roundtrip"] = {"ok": bool(map_save.get("ok", false)) and bool(scenario_save.get("ok", false)), "position_preserved": session.overworld.hero_position == result.hero_position}
				SessionState.active_session = session
				var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
				add_child(shell)
				for frame in range(12):
					await get_tree().process_frame
				var requested_size := OS.get_environment("HEROES_RMG_AUDIT_RESOLUTION").split("x")
				get_window().size = Vector2i(int(requested_size[0]), int(requested_size[1]))
				for frame in range(4):
					await get_tree().process_frame
				result["briefing_autosave"] = shell._last_briefing_consumption_autosave_result.duplicate(true)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join(String(case.id) + ".png"))
				if OS.get_environment("HEROES_RMG_AUDIT_LEVELS") == "1":
					result["level_runtime"] = await exercise_level_runtime(shell, session, out, String(case.id))
				shell.queue_free()
				await get_tree().process_frame
		result["elapsed_ms"] = Time.get_ticks_msec() - started
		var file := FileAccess.open(out.path_join(String(case.id) + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
		print("RMG_AUDIT_CASE " + JSON.stringify({"id": case.id, "ok": result.ok, "elapsed_ms": result.elapsed_ms, "error_code": result.error_code}))
	get_tree().quit(0)

func exercise_level_runtime(shell, session, out: String, case_id: String) -> Dictionary:
	var checks := {}
	var requested_size := OS.get_environment("HEROES_RMG_AUDIT_RESOLUTION").split("x")
	checks["rendered_resolution_matches_request"] = get_viewport().get_texture().get_image().get_size() == Vector2i(int(requested_size[0]), int(requested_size[1]))
	var hero_level := Levels.hero_level(session)
	var hero_tile := Rules.hero_position(session)
	var map_before: Array = session.overworld.map.duplicate(true)
	var position_before: Dictionary = session.overworld.hero_position.duplicate(true)
	var movement_before: Dictionary = session.overworld.movement.duplicate(true)
	checks["main_map_matches_hero_level"] = shell._map_view._level == hero_level and shell._map_data == Levels.terrain_rows(session, hero_level)
	checks["minimap_matches_hero_level"] = shell._minimap.validation_snapshot().level == hero_level
	checks["hero_is_on_own_map"] = shell._map_view._has_hero_at(hero_tile)
	checks["hero_fog_own_level"] = Rules.is_tile_explored(session, hero_tile.x, hero_tile.y, hero_level)
	var fog_before: Dictionary = session.overworld.fog.duplicate(true)
	var saved: Dictionary = SaveService.save_runtime_file_session(session, "level_" + case_id)
	var restored = SaveService.restore_session_from_summary(SaveService.inspect_save_file("level_" + case_id))
	checks["production_save_restore"] = bool(saved.get("ok", false)) and restored != null
	checks["saved_position_level"] = restored != null and restored.overworld.hero_position == position_before
	checks["saved_all_fog_levels"] = restored != null and restored.overworld.fog == fog_before
	checks["saved_surface_unchanged"] = restored != null and restored.overworld.map == map_before
	if Levels.level_count(session) > 1:
		checks["layer_button_accessible"] = shell._map_level_button.visible and shell._map_level_button.focus_mode == Control.FOCUS_ALL and shell._map_level_button.accessibility_name != ""
		shell._map_level_button.pressed.emit()
		for frame in range(3):
			await get_tree().process_frame
		var other := 1 - hero_level
		checks["toggle_selects_other_map"] = shell._map_view._level == other and shell._map_data == Levels.terrain_rows(session, other)
		checks["toggle_selects_other_minimap"] = shell._minimap.validation_snapshot().level == other
		checks["other_level_action_shows_hero_focus"] = shell._primary_action_button.text.contains("Show Active Hero")
		checks["hero_not_projected_to_other_level"] = not shell._map_view._has_hero_at(hero_tile)
		checks["toggle_preserves_surface_authority"] = session.overworld.map == map_before
		shell._try_move(0, 1)
		checks["view_only_cannot_move_other_level_hero"] = session.overworld.hero_position == position_before and session.overworld.movement == movement_before
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(case_id + "_other_level.png"))
		shell._on_context_action_pressed("focus_hero")
		for frame in range(3):
			await get_tree().process_frame
		checks["focus_returns_to_hero_level"] = shell._map_view._level == hero_level and shell._minimap.validation_snapshot().level == hero_level
		checks["toggle_preserves_fog"] = session.overworld.fog == fog_before
	checks["spatial_fixture"] = exercise_level_isolation()
	checks.merge(exercise_level_interactions())
	checks.merge(exercise_level_battle(session, case_id))
	checks.merge(exercise_level_turns(session))
	checks["ai_native_town_doorway_egress"] = exercise_ai_town_egress(session)
	if Levels.level_count(session) > 1:
		var primary_id := String(session.overworld.active_hero_id)
		var reserve: Dictionary = session.overworld.hero.duplicate(true)
		reserve["id"] = "hero_caelen" if primary_id != "hero_caelen" else "hero_lyra"
		reserve["is_primary"] = false
		reserve["position"] = Levels.moved_position(position_before, hero_tile, 1 - hero_level)
		session.overworld.player_heroes.append(reserve)
		Heroes.normalize_session(session)
		shell._on_hero_roster_pressed(String(reserve.id))
		for frame in range(3):
			await get_tree().process_frame
		checks["roster_switches_hero_and_layer"] = String(session.overworld.active_hero_id) == String(reserve.id) and Levels.hero_level(session) == 1 - hero_level and shell._map_view._level == 1 - hero_level and shell._minimap.validation_snapshot().level == 1 - hero_level
		checks["roster_keeps_same_xy_distinct"] = Heroes.hero_position_by_id(session, primary_id) == position_before and Heroes.hero_position_by_id(session, String(reserve.id)) == reserve.position
		shell._on_hero_roster_pressed(primary_id)
		for frame in range(3):
			await get_tree().process_frame
		checks["roster_returns_to_underground_hero"] = session.overworld.hero_position == position_before and shell._map_view._level == hero_level
	return checks

func clone_session(source):
	var clone = Store.new_session_data()
	clone.from_dict(source.to_dict())
	return clone

func exercise_ai_town_egress(session) -> bool:
	var checked := 0
	for town in session.overworld.towns:
		if String(town.get("owner", "")) not in ["player", "enemy"]:
			continue
		var point := Levels.town_entrance(town)
		var start := Vector2i(int(point.x), int(point.y))
		var level := Levels.level_of(town)
		var can_exit := false
		for delta in Ai.PATH_MOVEMENT_DELTAS:
			var goal: Vector2i = start + delta
			if Rules.tile_is_blocked(session, goal.x, goal.y, level) or Rules.tile_step_cuts_blocked_corner(session, start, goal, level):
				continue
			var plan: Dictionary = Ai._path_plan_toward(session, start, [goal], String(town.placement_id), "")
			if plan.get("next_step") == goal and int(plan.get("goal_distance", 9999)) == 1:
				can_exit = true
		checked += 1
		if not can_exit:
			return false
	return checked > 0

func exercise_level_battle(source, case_id: String) -> Dictionary:
	var checks := {}
	var session = clone_session(source)
	var encounter := {}
	for candidate in session.overworld.get("encounters", []):
		if Levels.on_level(candidate, Levels.hero_level(session)) and not Rules.is_encounter_resolved(session, candidate):
			encounter = candidate
			break
	checks["battle_native_encounter_exists"] = not encounter.is_empty()
	if encounter.is_empty():
		return checks
	Rules.clear_active_town_visit(session)
	Rules._set_active_hero_position(session, Vector2i(int(encounter.x), int(encounter.y)))
	Heroes.commit_active_hero(session)
	var position: Dictionary = session.overworld.hero_position.duplicate(true)
	var started: Dictionary = Rules._resolve_destination_descriptor_interaction(session, {"kind": "encounter", "placement_id": encounter.placement_id, "level": Levels.level_of(encounter)})
	checks["battle_real_descriptor_handoff"] = bool(started.get("ok", false)) and started.get("route", "") == "battle" and not session.battle.is_empty()
	if session.battle.is_empty():
		return checks
	session.game_state = "battle"
	checks["battle_payload_preserves_level"] = Levels.level_of(session.battle.position) == Levels.level_of(encounter)
	var saved: Dictionary = SaveService.save_runtime_file_session(session, "battle_layer_" + case_id)
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file("battle_layer_" + case_id))
	checks["battle_disk_resume_preserves_level"] = bool(saved.get("ok", false)) and resumed != null and Levels.level_of(resumed.battle.get("position", {})) == Levels.level_of(encounter) and Battles.battle_payload_can_resume(resumed)
	if resumed == null:
		return checks
	var battle_before := {"before": session.to_dict(), "resumed": resumed.to_dict()}
	var first: Dictionary = AutoBattle.resolve_active_battle(session)
	var second: Dictionary = AutoBattle.resolve_active_battle(resumed)
	battle_before.merge({"first_result": first, "second_result": second, "first_after": session.to_dict(), "second_after": resumed.to_dict()})
	var evidence := FileAccess.open(OS.get_environment("HEROES_RMG_AUDIT_OUTPUT").path_join(case_id + "_battle_evidence.json"), FileAccess.WRITE)
	evidence.store_string(JSON.stringify(battle_before))
	evidence.close()
	checks["battle_completes_after_resume"] = bool(first.get("completed", false)) and bool(second.get("completed", false)) and session.battle.is_empty() and resumed.battle.is_empty()
	checks["battle_resume_same_outcome"] = first == second and session.overworld.hero_position == resumed.overworld.hero_position and session.overworld.resolved_encounters == resumed.overworld.resolved_encounters and session.overworld.army == resumed.overworld.army
	checks["battle_outcome_keeps_hero_layer"] = session.overworld.hero_position == position
	return checks

func exercise_level_turns(source) -> Dictionary:
	var first = clone_session(source)
	var second = clone_session(source)
	var levels := {}
	for collection in ["towns", "resource_nodes", "artifact_nodes", "encounters", "map_objects"]:
		for record in first.overworld.get(collection, []):
			levels[String(record.get("placement_id", ""))] = Levels.level_of(record)
	var deterministic := true
	var preserved := true
	var active := true
	for turn in range(2):
		var a: Dictionary = Rules.end_turn(first)
		var b: Dictionary = Rules.end_turn(second)
		deterministic = deterministic and a == b and first.to_dict() == second.to_dict()
		active = active and first.day == source.day + turn + 1 and first.scenario_status == "in_progress"
		for collection in ["towns", "resource_nodes", "artifact_nodes", "encounters", "map_objects"]:
			for record in first.overworld.get(collection, []):
				var id := String(record.get("placement_id", ""))
				if levels.has(id):
					preserved = preserved and Levels.level_of(record) == int(levels[id])
	return {"two_level_end_turns_complete": active, "two_level_end_turns_deterministic": deterministic, "end_turn_preserves_object_levels": preserved and Levels.hero_level(first) == Levels.hero_level(source)}

func exercise_level_interactions() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", Store.LAUNCH_MODE_SKIRMISH)
	var surface: Array = session.overworld.map.duplicate(true)
	session.overworld["map_size"]["level_count"] = 2
	var codes := []
	var ids := []
	for row in surface:
		for terrain in row:
			if terrain not in ids:
				ids.append(terrain)
			codes.append(ids.find(terrain))
	session.overworld["terrain_layers"] = {"terrain_id_by_code": ids, "terrain": {"levels": [codes.duplicate(), codes.duplicate()]}}
	var tile := Rules.hero_position(session)
	session.overworld.hero_position["level"] = 1
	session.overworld.hero["position"] = session.overworld.hero_position.duplicate(true)
	Heroes.commit_active_hero(session)
	var checks := {}
	var before: Dictionary = session.to_dict()
	for kind in ["resource", "artifact", "encounter", "town", "hero", "open"]:
		var result: Dictionary = Rules.execute_prevalidated_route(session, [tile, tile + Vector2i(1, 0)], {}, -1, {"kind": kind, "level": 0})
		checks["stale_" + kind + "_route_nonmutating"] = not bool(result.get("ok", true)) and session.to_dict() == before
	var resource: Dictionary = session.overworld.resource_nodes[0]
	var collected_before: Dictionary = session.to_dict()
	var rejected: Dictionary = Rules._resolve_destination_descriptor_interaction(session, {"kind": "resource", "placement_id": resource.placement_id})
	checks["placement_id_cannot_bypass_layer"] = not bool(rejected.get("ok", true)) and session.to_dict() == collected_before
	var fake_raid := {"placement_id": "layer_guard_probe", "x": int(resource.x), "y": int(resource.y), "level": 1, "target_kind": "resource", "target_placement_id": resource.placement_id}
	Ai._resolve_arrived_target(session, fake_raid, {}, "faction_mireclaw")
	checks["enemy_arrival_cannot_claim_other_layer"] = session.to_dict() == collected_before
	checks["exploration_identity_is_level_aware"] = Ai.exploration_target_id(tile, 0) != Ai.exploration_target_id(tile, 1) and Ai._exploration_target_tile_from_id(Ai.exploration_target_id(tile, 1)) == tile and Ai._exploration_target_level(Ai.exploration_target_id(tile, 1)) == 1
	var fingerprint := Ai._path_distance_resource_fingerprint(session)
	resource["level"] = 1
	checks["ai_cache_detects_same_xy_layer_change"] = Ai._path_distance_resource_fingerprint(session) != fingerprint
	var town: Dictionary = session.overworld.towns[0]
	var entrance := Levels.town_entrance(town)
	session.overworld.hero_position = Levels.moved_position(entrance, Vector2i(int(entrance.x), int(entrance.y)), 1)
	Heroes.commit_active_hero(session)
	var objective := {"hero_id": String(session.overworld.active_hero_id), "placement_id": String(town.placement_id)}
	checks["stationing_rejects_other_layer"] = not bool(Scenario._hero_stationing_progress(session, objective).position_matches)
	town["level"] = 1
	if town.get("visit_tile") is Dictionary:
		town.visit_tile["level"] = 1
	checks["stationing_accepts_own_entrance"] = bool(Scenario._hero_stationing_progress(session, objective).position_matches)
	town["owner"] = "enemy"
	var assault: Dictionary = Battles.create_town_assault_payload(session, String(town.placement_id))
	checks["town_assault_preserves_entrance_level"] = not assault.is_empty() and assault.position == Levels.town_entrance(town)
	resource = Rules._find_resource_node_by_placement(session, String(resource.placement_id)).get("node", {})
	resource["ai_defender_army"] = session.overworld.army.duplicate(true)
	var defense: Dictionary = Battles.create_resource_defense_payload(session, String(resource.placement_id))
	checks["resource_defense_preserves_level"] = not defense.is_empty() and Levels.level_of(defense.position) == 1
	checks["missing_terrain_layer_is_blocked"] = Rules.tile_is_blocked(session, tile.x, tile.y, 9)
	var anchors := [Vector2i(2, 2), Vector3i(9, 9, 1)]
	checks["ai_objective_proximity_is_layer_local"] = Ai._objective_proximity_bonus_from_tiles(anchors, 2, 2, 0) == 45 and Ai._objective_proximity_bonus_from_tiles(anchors, 2, 2, 1) == 0 and Ai._objective_proximity_bonus_from_tiles(anchors, 9, 9, 1) == 45
	return checks

func exercise_level_isolation() -> bool:
	var ground := []
	var codes := []
	for y in range(16):
		var row := []
		for x in range(16):
			row.append("grass")
			codes.append(0)
		ground.append(row)
	ground[2][3] = "water"
	var fixture = Store.new_session_data("level_isolation", "", "hero_lyra", 1, {
		"map": ground, "map_size": {"width": 16, "height": 16, "level_count": 2},
		"terrain_layers": {"terrain_id_by_code": ["grass"], "terrain": {"levels": [codes.duplicate(), codes.duplicate()]}},
		"hero_position": {"x": 2, "y": 2, "level": 1},
		"hero": {"id": "hero_lyra", "level": 7, "position": {"x": 2, "y": 2, "level": 1}},
		"player_heroes": [{"id": "hero_lyra", "level": 7, "position": {"x": 2, "y": 2, "level": 1}}],
		"towns": [{"placement_id": "surface_town", "owner": "player", "x": 12, "y": 12}],
		"map_objects": [{"placement_id": "surface_body", "level": 0, "kind": "decorative_obstacle", "package_block_tiles": [{"x": 3, "y": 3}]}],
		"encounters": [{"placement_id": "under_encounter", "x": 4, "y": 4, "level": 1}],
	})
	Rules.invalidate_spatial_lookup(fixture)
	Rules._refresh_blocked_tile_index(fixture)
	Rules._normalize_fog_of_war(fixture)
	var ok := Levels.level_of(fixture.overworld.hero) == 1
	ok = ok and Rules.tile_is_blocked(fixture, 3, 2, 0) and not Rules.tile_is_blocked(fixture, 3, 2, 1)
	ok = ok and Rules.tile_is_blocked(fixture, 3, 3, 0) and not Rules.tile_is_blocked(fixture, 3, 3, 1)
	ok = ok and not Rules.tile_has_route_interaction(fixture, 4, 4, 0) and Rules.tile_has_route_interaction(fixture, 4, 4, 1)
	ok = ok and not Rules.is_tile_explored(fixture, 2, 2, 0) and Rules.is_tile_explored(fixture, 2, 2, 1)
	ok = ok and Rules.is_tile_explored(fixture, 12, 12, 0) and not Rules.is_tile_explored(fixture, 12, 12, 1)
	var above: Dictionary = Ai._path_distance_surface_context(fixture, "", "", 0)
	var below: Dictionary = Ai._path_distance_surface_context(fixture, "under_encounter", "")
	ok = ok and above.level == 0 and below.level == 1
	ok = ok and above.terrain_blocked.has("3,2") and not below.terrain_blocked.has("3,2")
	ok = ok and above.resource_blocked.has("3,3") and not below.resource_blocked.has("3,3")
	var path: Dictionary = Ai._path_plan_toward(fixture, Vector2i(4, 4), [Vector2i(4, 5)], "under_encounter", "")
	ok = ok and path.next_step == Vector2i(4, 5) and int(path.goal_distance) == 1
	var points: Array = Turns._open_spawn_points(fixture, {"spawn_points": [{"x": 2, "y": 2}, {"x": 2, "y": 2, "level": 1}]})
	ok = ok and points == [{"x": 2, "y": 2}]
	var source := {"x": 4, "y": 4, "radius": 3}
	var catalog := [{"target_kind": "resource", "target_id": "above", "target_tile": Vector2i(4, 4)}, {"target_kind": "resource", "target_id": "below", "target_tile": Vector2i(4, 4), "level": 1}]
	var records: Array = Ai._current_enemy_visible_target_records_for_source(fixture, {}, "faction_mireclaw", source, catalog)
	ok = ok and records.size() == 1 and records[0].target_id == "above"
	source["level"] = 1
	records = Ai._current_enemy_visible_target_records_for_source(fixture, {}, "faction_mireclaw", source, catalog)
	ok = ok and records.size() == 1 and records[0].target_id == "below" and records[0].level == 1
	fixture.overworld.towns.append({"placement_id": "enemy_sight_source", "town_id": "town_duskfen", "owner": "enemy", "x": 2, "y": 3})
	ok = ok and not Ai._player_hero_currently_visible_to_enemy_faction(fixture, fixture.overworld.hero, "faction_mireclaw")
	fixture.overworld.towns[-1]["level"] = 1
	ok = ok and Ai._player_hero_currently_visible_to_enemy_faction(fixture, fixture.overworld.hero, "faction_mireclaw")
	ok = ok and Ai._commander_map_level({"roster_hero_id": "hero_caelen", "level": 7}) == 0
	return ok

func exercise_entrance(session, save_path: String) -> Dictionary:
	var start := Rules.hero_position(session)
	var entered: Dictionary = Rules._resolve_post_move_interaction(session)
	Rules.clear_active_town_visit(session)
	var away := {}
	var returned := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var target := start + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or Rules.tile_is_blocked(session, target.x, target.y) or Rules.tile_has_route_interaction(session, target.x, target.y) or Rules.tile_step_cuts_blocked_corner(session, start, target):
				continue
			away = Rules.try_move(session, dx, dy)
			if bool(away.get("ok", false)) and Rules.hero_position(session) != start:
				returned = Rules.try_move(session, -dx, -dy)
				break
		if not returned.is_empty():
			break
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(session.to_dict()))
	file.close()
	var restored = Store.new_session_data()
	restored.from_dict(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	Rules.normalize_overworld_state(restored)
	var restored_entry: Dictionary = Rules._resolve_post_move_interaction(restored)
	var view = MapView.new()
	var town_anchor_matches := true
	for town in session.overworld.get("towns", []):
		var visit: Dictionary = town.get("visit_tile", town)
		town_anchor_matches = town_anchor_matches and view._town_entry_tile(town) == Vector2i(int(visit.x), int(visit.y))
	view.free()
	return {"initial_town_route": entered.get("route", ""), "exit_ok": bool(away.get("ok", false)) and not returned.is_empty(), "return_ok": bool(returned.get("ok", false)) and returned.get("route", "") == "town" and Rules.hero_position(session) == start, "restored_position": restored.overworld.hero_position, "restored_town_route": restored_entry.get("route", ""), "initial_result": entered, "exit_message": away.get("message", ""), "return_message": returned.get("message", ""), "town_visual_anchors_match": town_anchor_matches, "corner_controls": exercise_corner_contract()}

func exercise_corner_contract() -> Dictionary:
	var town := {"placement_id": "corner_town", "x": 1, "y": 1, "visit_tile": {"x": 1, "y": 1}, "package_block_tiles": [{"x": 1, "y": 1}, {"x": 2, "y": 1}]}
	var obstacle := {"placement_id": "corner_rock", "kind": "decorative_obstacle", "package_block_tiles": [{"x": 1, "y": 2}]}
	var fixture = Store.new_session_data("entrance_corner_controls", "", "", 1, {"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]], "map_size": {"width": 3, "height": 3}, "towns": [town], "map_objects": [obstacle]})
	Rules.invalidate_spatial_lookup(fixture)
	Rules._refresh_blocked_tile_index(fixture)
	var opens: bool = not Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(1, 1), Vector2i(2, 2))
	var ingress: bool = not Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(2, 2), Vector2i(1, 1))
	var bodies_preserved: bool = Rules.tile_is_blocked(fixture, 1, 1) and Rules.tile_is_blocked(fixture, 2, 1) and Rules.tile_is_blocked(fixture, 1, 2)
	fixture.overworld.map_objects.append({"placement_id": "overlapping_rock", "kind": "decorative_obstacle", "package_block_tiles": [{"x": 2, "y": 1}]})
	Rules._refresh_blocked_tile_index(fixture)
	var overlap_blocks: bool = Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(1, 1), Vector2i(2, 2))
	fixture.overworld.map_objects.pop_back()
	fixture.overworld.towns[0].erase("visit_tile")
	Rules.invalidate_spatial_lookup(fixture)
	Rules._refresh_blocked_tile_index(fixture)
	var ordinary_blocks: bool = Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(1, 1), Vector2i(2, 2))
	return {"doorway_egress": opens, "doorway_ingress": ingress, "bodies_preserved": bodies_preserved, "unrelated_overlap_blocks": overlap_blocks, "ordinary_corner_blocks": ordinary_blocks}
'''


def point(value: dict) -> tuple[int, int, int]:
    return int(value["x"]), int(value["y"]), int(value.get("level", 0))


def distances(start, width, height, blocked):
    """Fixed-body eight-way diagnostic; does not model town doorway passages."""
    result = {start: 0}
    queue = deque([start])
    while queue:
        x, y, z = queue.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                target = x + dx, y + dy, z
                if not (dx or dy) or target in result or target in blocked:
                    continue
                if not (0 <= target[0] < width and 0 <= target[1] < height):
                    continue
                if dx and dy and (x + dx, y, z) in blocked and (x, y + dy, z) in blocked:
                    continue
                result[target] = result[x, y, z] + 1
                queue.append(target)
    return result


def analyze(raw):
    row = {k: raw.get(k) for k in ("id", "ok", "error_code", "payload_fnv1a32", "elapsed_ms", "hero_position", "hero_id", "hero_tile_blocked", "hero_blocking_body_owners", "entrance_actions", "level_runtime", "map_size")}
    if not raw.get("ok"):
        return row
    size = raw["map_size"]
    width, height = size["width"], size["height"]
    objects = raw["objects"]
    by_id = {o["placement_id"]: o for o in objects}
    blocked = set()
    for z, codes in enumerate(raw["terrain"]["terrain"]["levels"]):
        blocked.update((i % width, i // width, z) for i, code in enumerate(codes) if (code & 63) in (8, 9))
    for obj in objects:
        blocked.update(point(p) for p in obj.get("package_body_tiles", []))
    starts = []
    for start in raw["start_contract"]["player_starts"]:
        town = point(start)
        hero = point(start["hero_start_tile"])
        routes = distances(hero, width, height, blocked - {town})
        starts.append({"owner": start["owner"], "slot": start["player_slot"], "town": town, "hero": hero, "manhattan_displacement": abs(hero[0]-town[0])+abs(hero[1]-town[1]), "selection_source": start["hero_start_tile"]["selection_source"], "town_entrance_route_steps": routes.get(town), "town_binding_exists": start["town_placement_id"] in by_id, "town_entrance_body_owners": [o["placement_id"] for o in objects if town in {point(p) for p in o.get("package_body_tiles", [])}], "reachable_cells_with_town_destination_open": len(routes)})
    row.update(starts=starts, object_count=len(objects), object_levels=dict(Counter(o.get("level", 0) for o in objects)), first_step_count=len(raw["unblocked_first_steps"]), runtime_enemy_state_count=len(raw["enemy_states"]), runtime_enemy_factions=[e.get("faction_id") for e in raw["enemy_states"]], expected_enemy_slots=sum(s["owner"] == "enemy" for s in starts), runtime_town_count=len(raw["towns"]))
    hero = point(raw["hero_position"])
    live_routes = distances(hero, width, height, {point(p) for p in raw["runtime_blocked"]})
    row["runtime_reachable_cells"] = len(live_routes)
    row["player_town_routes"] = []
    for town in raw["towns"]:
        if town.get("owner") != "player":
            continue
        entrance = point(town.get("visit_tile") or town)
        routes = distances(hero, width, height, {point(p) for p in raw["runtime_blocked"]} - {entrance})
        row["player_town_routes"].append({"placement_id": town["placement_id"], "town_level_field": town.get("level"), "entrance": entrance, "steps_with_destination_open": routes.get(entrance)})
    return row


def case(case_id, size, levels, water, seed, players=2, strength="weak"):
    names = {36: "small", 72: "medium", 108: "large", 144: "homm3_extra_large"}
    return {"id": case_id, "config": {"seed": str(seed), "size": {"width": size, "height": size, "level_count": levels, "water_mode": water, "size_class_id": names[size]}, "monster_strength": strength, "player_constraints": {"human_count": 1, "computer_count": players-1, "player_count": players, "human_team_count": 1, "computer_team_count": 0}}}


def matrix():
    rows = [case(f"matrix_{size}_{levels}_{water}", size, levels, water, 1) for size in (36, 72, 108, 144) for levels in (1, 2) for water in ("land", "normal_water", "islands")]
    rows += [case("ordinal95", 72, 1, "land", 165429308, 4), case("medium_seed10", 72, 1, "land", 10), case("medium_water_seed10", 72, 1, "normal_water", 10), case("small_seed68", 36, 2, "land", 68), case("xlarge_seed77", 144, 2, "normal_water", 77)]
    rows += [case(f"players_{n}", 72, 1, "land", 10, n) for n in (3, 6, 8)]
    rows += [case(f"strength_{s}", 36, 1, "land", 1, 2, s) for s in ("normal", "strong", "random", "impossible")]
    rows.append(case("medium_seed10_repeat", 72, 1, "land", 10))
    return rows


def entrance_failures(rows):
    failures = []
    for row in rows:
        if not row["ok"]:
            if row.get("error_code") != "native_rmg_monster_strength_unsupported":
                failures.append({"id": row["id"], "reason": "generation_failed"})
            continue
        starts = row["starts"]
        if not starts or any(tuple(s["town"]) != tuple(s["hero"]) or not s["town_binding_exists"] for s in starts):
            failures.append({"id": row["id"], "reason": "native_entrance_contract"})
        primary = next((s for s in starts if s["owner"] == "player"), None)
        if primary is None:
            failures.append({"id": row["id"], "reason": "primary_start_missing"})
            continue
        if point(row["hero_position"]) != tuple(primary["town"]):
            failures.append({"id": row["id"], "reason": "live_entrance_or_level_lost"})
        if any(o["family"] != "towns" for o in row["hero_blocking_body_owners"]):
            failures.append({"id": row["id"], "reason": "non_town_body_on_start"})
        actions = row.get("entrance_actions") or {}
        if not actions.get("town_visual_anchors_match"):
            failures.append({"id": row["id"], "reason": "town_visual_entrance_mismatch"})
        if not (actions.get("initial_town_route") == "town" and actions.get("exit_ok") and actions.get("return_ok") and actions.get("restored_town_route") == "town" and point(actions["restored_position"]) == tuple(primary["town"])):
            failures.append({"id": row["id"], "reason": "live_move_town_save_roundtrip", "actions": actions})
        controls = actions.get("corner_controls", {})
        if not all(controls.get(k) for k in ("doorway_egress", "doorway_ingress", "bodies_preserved", "unrelated_overlap_blocks", "ordinary_corner_blocks")):
            failures.append({"id": row["id"], "reason": "town_corner_contract", "controls": controls})
    return failures


LEVEL_RUNTIME_CHECKS = {
    "rendered_resolution_matches_request",
    "main_map_matches_hero_level", "minimap_matches_hero_level", "hero_is_on_own_map",
    "hero_fog_own_level", "production_save_restore", "saved_position_level",
    "saved_all_fog_levels", "saved_surface_unchanged", "spatial_fixture",
    "placement_id_cannot_bypass_layer", "enemy_arrival_cannot_claim_other_layer",
    "exploration_identity_is_level_aware", "ai_cache_detects_same_xy_layer_change",
    "stationing_rejects_other_layer", "stationing_accepts_own_entrance",
    "missing_terrain_layer_is_blocked", "battle_native_encounter_exists",
    "battle_real_descriptor_handoff", "battle_payload_preserves_level",
    "battle_disk_resume_preserves_level", "battle_completes_after_resume",
    "battle_resume_same_outcome", "battle_outcome_keeps_hero_layer",
    "two_level_end_turns_complete", "two_level_end_turns_deterministic",
    "end_turn_preserves_object_levels",
    "ai_native_town_doorway_egress",
    "ai_objective_proximity_is_layer_local",
    "town_assault_preserves_entrance_level", "resource_defense_preserves_level",
} | {f"stale_{kind}_route_nonmutating" for kind in ("resource", "artifact", "encounter", "town", "hero", "open")}
LEVEL_TOGGLE_CHECKS = {
    "layer_button_accessible", "toggle_selects_other_map", "toggle_selects_other_minimap",
    "other_level_action_shows_hero_focus", "hero_not_projected_to_other_level",
    "toggle_preserves_surface_authority", "view_only_cannot_move_other_level_hero",
    "focus_returns_to_hero_level", "toggle_preserves_fog", "roster_switches_hero_and_layer",
    "roster_keeps_same_xy_distinct", "roster_returns_to_underground_hero",
}


def level_failures(rows):
    failures = []
    for row in rows:
        if not row.get("ok"):
            continue
        checks = row.get("level_runtime")
        checks = checks if isinstance(checks, dict) else {}
        required = LEVEL_RUNTIME_CHECKS | (LEVEL_TOGGLE_CHECKS if row.get("map_size", {}).get("levels", 1) > 1 else set())
        failures.extend({"id": row["id"], "check": key} for key in sorted(required | checks.keys()) if checks.get(key) is not True)
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="matrix")
    parser.add_argument("--case", help="Comma-separated case IDs; default all sampled cases")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--resolution", choices=("1280x720", "1600x900", "2048x1079"), default="1280x720")
    parser.add_argument("--require-level-runtime", action="store_true", help="Render both levels, exercise view/input isolation and production saves; fail on any layer violation")
    parser.add_argument("--require-entrance-starts", action="store_true", help="Exercise live entry/exit/return/save and fail on any entrance/layer violation")
    parser.add_argument("--analyze-only", action="store_true")
    args = parser.parse_args()
    if args.require_level_runtime:
        args.render = True
        args.require_entrance_starts = True
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("label must be a safe single path component")
    out = OUTPUT / args.label
    cases = [r for r in matrix() if not args.case or r["id"] in args.case.split(",")]
    if not cases:
        parser.error("no matching cases")
    revision = "unrecorded_retained_run"
    source_hashes = {}
    if not args.analyze_only:
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        source_paths = sorted(list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "scenes").rglob("*.gd")))
        source_hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in source_paths}
    elif (out / "summary.json").exists():
        retained = json.loads((out / "summary.json").read_text())
        revision = retained.get("revision", revision)
        source_hashes = retained.get("runtime_source_sha256", {})
    if not args.analyze_only:
        out.mkdir(parents=True, exist_ok=False)
        (out / "cases.json").write_text(json.dumps(cases, indent=2) + "\n")
        with tempfile.TemporaryDirectory(prefix="adapter-", dir=OUTPUT) as temp:
            work = Path(temp)
            script = work / "probe.gd"
            script.write_text(PROBE)
            scene = work / "probe.tscn"
            scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Audit" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
            env = dict(os.environ, XDG_DATA_HOME=str(out / "data"), HEROES_RMG_AUDIT_OUTPUT=str(out), HEROES_RMG_AUDIT_RENDER="1" if args.render else "0", HEROES_RMG_AUDIT_ENTRANCE="1" if args.require_entrance_starts else "0", HEROES_RMG_AUDIT_LEVELS="1" if args.require_level_runtime else "0", HEROES_RMG_AUDIT_RESOLUTION=args.resolution, HEROES_PROFILE_LOG="0")
            cmd = [shutil.which("godot4") or "godot", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", "disabled", "--resolution", args.resolution, "res://" + str(scene.relative_to(ROOT))]
            cmd = ["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24"] + cmd if args.render else cmd + ["--headless"]
            with (out / "runtime.log").open("w") as log:
                run = subprocess.run(["timeout", "2400s"] + cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=2420)
            if run.returncode:
                print(f"adapter failed ({run.returncode}); see {out / 'runtime.log'}")
                return 1
    rows = [analyze(json.loads((out / (c["id"] + ".json")).read_text())) for c in cases]
    errors = [line for line in (out / "runtime.log").read_text().splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    report = {"audit_collected": not errors, "runtime_errors": errors, "revision": revision, "runtime_source_sha256": source_hashes, "note": "Diagnostic graphs hold body masks fixed and open the town destination. They do not simulate guard battles, removable objects, transit or legal interaction approach. Not H3MapEd parity or a full town-access proof.", "cases": rows}
    if args.require_entrance_starts:
        report["entrance_failures"] = entrance_failures(rows)
        report["entrance_regression_ok"] = not report["entrance_failures"]
    if args.require_level_runtime:
        report["level_failures"] = level_failures(rows)
        report["level_runtime_ok"] = not report["level_failures"]
    (out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"audit_collected": report["audit_collected"], "cases": len(rows), "generated": sum(bool(r["ok"]) for r in rows), "output": str(out)}))
    return 0 if report["audit_collected"] and report.get("entrance_regression_ok", True) and report.get("level_runtime_ok", True) else 1


if __name__ == "__main__":
    raise SystemExit(main())
