#!/usr/bin/env python3
"""Validate source-owned native transit through package adoption and live rules."""
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
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Transit = preload("res://scripts/core/NativeTransitRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Ai = preload("res://scripts/core/EnemyAdventureRules.gd")
const Turns = preload("res://scripts/core/EnemyTurnRules.gd")
const AutoBattle = preload("res://scripts/core/BattleAutoResolveRules.gd")
const Battles = preload("res://scripts/core/BattleRules.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
const Selection = preload("res://scripts/core/ScenarioSelectRules.gd")
func _ready() -> void:
	call_deferred("run")
func clone(source):
	var result = Store.new_session_data()
	result.from_dict(source.to_dict())
	Rules.normalize_overworld_state(result)
	return result
func place(session, tile: Vector3i) -> void:
	Rules._set_active_hero_position(session, Vector2i(tile.x, tile.y), tile.z)
	session.overworld.movement.current = 20
	Heroes.commit_active_hero(session)
	Rules.normalize_overworld_state(session)
func run() -> void:
	var out := OS.get_environment("HEROES_TRANSIT_OUTPUT")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
	var service = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(config)
	var report := {"generation_ok": generated.get("ok", false), "checks": {}, "trips": []}
	report.checks["native_navigation_field_unit_edges"] = exercise_navigation_field()
	report["native_map_hash"] = generated.get("map_hash", "")
	if bool(report.generation_ok):
		var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": "native_transit_validation"})
		var map_path := "user://transit.amap"
		var scenario_path := "user://transit.ascenario"
		var map_saved: Dictionary = service.save_map_package(generated.map_document, map_path)
		var map_loaded: Dictionary = service.load_map_package(map_path)
		var scenario = generated.scenario_document
		scenario.configure({"scenario_id": scenario.get_scenario_id(), "scenario_hash": scenario.get_scenario_hash(), "map_ref": map_loaded.map_ref, "selection": scenario.get_selection(), "player_slots": scenario.get_player_slots(), "objectives": scenario.get_objectives(), "script_hooks": scenario.get_script_hooks(), "enemy_factions": scenario.get_enemy_factions(), "start_contract": scenario.get_start_contract()})
		var scenario_saved: Dictionary = service.save_scenario_package(scenario, scenario_path)
		var scenario_loaded: Dictionary = service.load_scenario_package(scenario_path)
		var boundary: Dictionary = adoption.session_boundary_record.duplicate(true)
		boundary.merge({"map_package_path": map_path, "scenario_package_path": scenario_path, "map_package_ref": map_loaded.map_ref, "scenario_package_ref": scenario_loaded.scenario_ref}, true)
		var source = Bridge.build_session_from_loaded_packages(map_loaded, scenario_loaded, boundary)
		var persisted := {"map_ref": map_loaded.map_ref, "scenario_ref": scenario_loaded.scenario_ref, "map_path": map_path, "scenario_path": scenario_path}
		source.flags["generated_random_map_provenance"] = Selection._native_random_map_provenance(config, generated, adoption, persisted, {"attempt_count": 1})
		source.flags["generated_random_map_package_paths"] = {"map_path": map_path, "scenario_path": scenario_path}
		report.checks["disk_package_roundtrip"] = bool(map_saved.get("ok", false)) and bool(scenario_saved.get("ok", false))
		Rules.normalize_overworld_state(source)
		var gates: Array = source.overworld.resource_nodes.filter(func(node): return Transit.is_native(node))
		if OS.get_environment("HEROES_TRANSIT_PORTAL_CASE") == "":
			report["legacy"] = exercise_legacy(source, gates)
			report.checks["legacy_exact_anchor_restore"] = bool(report.legacy.get("ok", false))
			report["source_corner"] = exercise_source_corner(source)
			report.checks["cave_source_corner_runtime"] = bool(report.source_corner.get("ok", false))
		var historical_path := OS.get_environment("HEROES_TRANSIT_LEGACY")
		if historical_path != "":
			var historical = Store.new_session_data()
			historical.from_dict(JSON.parse_string(FileAccess.get_file_as_string(historical_path)))
			Rules.normalize_overworld_state(historical)
			report.checks["historical_save_reconstructs_eight_ends"] = int(historical.overworld.get("native_transit_compatibility", {}).get("reconstructed_legacy_cave_ends", 0)) == 8 and Transit.validate(historical.overworld.resource_nodes).is_empty()
		report["gates"] = gates
		report["objects"] = []
		for index in range(generated.map_document.get_object_count()):
			report.objects.append(generated.map_document.get_object_by_index(index))
		report["terrain"] = generated.map_document.get_terrain_layers()
		report["payload_fnv1a32"] = generated.get("final_payload_fnv1a32", "")
		report["payload_bytes"] = generated.get("final_payload_byte_count", 0)
		if OS.get_environment("HEROES_TRANSIT_JOURNEY_ONLY") == "1":
			report["journey"] = exercise_town_journeys(source)
			var journey_file := FileAccess.open(out.path_join("runtime_report.json"), FileAccess.WRITE)
			journey_file.store_string(JSON.stringify(report, "  "))
			journey_file.close()
			service = null
			get_tree().quit()
			return
		if OS.get_environment("HEROES_TRANSIT_PORTAL_CASE") != "":
			report["portals"] = exercise_portals(source, gates)
			if OS.get_environment("HEROES_TRANSIT_RENDER") == "1":
				report["visual"] = await exercise_portal_visual(source, gates, out)
			var portal_file := FileAccess.open(out.path_join("runtime_report.json"), FileAccess.WRITE)
			portal_file.store_string(JSON.stringify(report, "  "))
			portal_file.close()
			service = null
			get_tree().quit()
			return
		report.checks["eight_reciprocal_gate_records"] = gates.size() == 8 and Transit.validate(source.overworld.resource_nodes).is_empty()
		report.checks["native_gates_do_not_use_local_offsets"] = true
		for level in range(2):
			for edge in Rules.active_linked_transit_edges(source, level):
				for gate in gates:
					if edge.get("placement_id") == gate.get("placement_id"):
						report.checks.native_gates_do_not_use_local_offsets = false
		for gate in gates:
			var session = clone(source)
			# Simulate the post-battle state only: keep every native placement and
			# body mask, and mark guards resolved using the existing save field.
			for encounter in session.overworld.encounters:
				session.overworld.resolved_encounters.append(String(encounter.placement_id))
			var node: Dictionary = Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node
			var entry := Transit.point(node.native_transit.entry)
			var exit := Transit.point(node.native_transit.exit)
			place(session, entry)
			var before_resources: Dictionary = session.overworld.resources.duplicate(true)
			var before_node: Dictionary = node.duplicate(true)
			var spent_before := int(session.overworld.movement.current)
			var result: Dictionary = Rules.perform_context_action(session, "collect_resource")
			var trip := {"placement_id": node.placement_id, "result": result, "checks": {}}
			trip.checks["travel_reaches_exact_peer"] = bool(result.get("ok", false)) and Transit.point(session.overworld.hero_position) == exit
			trip.checks["context_travel_spends_one"] = int(session.overworld.movement.current) == spent_before - 1
			trip.checks["all_active_hero_positions_agree"] = Transit.point(Heroes.active_hero(session).get("position")) == exit and Transit.point(session.overworld.hero.get("position")) == exit
			trip.checks["view_and_fog_follow_level"] = Levels.view_level(session) == exit.z and Rules.is_tile_visible(session, exit.x, exit.y, exit.z)
			trip.checks["no_claim_rewards_or_source_mutation"] = session.overworld.resources == before_resources and Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node == before_node
			trip.checks["session_roundtrip_preserves_destination"] = Transit.point(clone(session).overworld.hero_position) == exit
			var save_id := "transit_" + String(node.placement_id)
			var saved: Dictionary = SaveService.save_runtime_file_session(session, save_id)
			var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file(save_id))
			trip.checks["production_save_preserves_transit_and_fog"] = bool(saved.get("ok", false)) and resumed != null and Transit.point(resumed.overworld.hero_position) == exit and resumed.overworld.fog == session.overworld.fog and Transit.validate(resumed.overworld.resource_nodes).is_empty()
			var return_result: Dictionary = Rules.perform_context_action(session, "collect_resource")
			trip.checks["repeatable_return_to_source"] = bool(return_result.get("ok", false)) and Transit.point(session.overworld.hero_position) == entry
			var entrance_tile := Vector2i(entry.x, entry.y)
			var egress := Vector2i(-1, -1)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var tile := entrance_tile + Vector2i(dx, dy)
					if tile != entrance_tile and not Rules.tile_is_blocked(session, tile.x, tile.y) and not Rules.tile_has_route_interaction(session, tile.x, tile.y) and not Rules.tile_step_cuts_blocked_corner(session, entrance_tile, tile):
						egress = tile
			var moved := {}
			var arrived := {}
			if egress.x >= 0:
				moved = Rules.try_move(session, egress.x - entry.x, egress.y - entry.y)
				var before_arrival := int(session.overworld.movement.current)
				arrived = Rules.try_move(session, entry.x - egress.x, entry.y - egress.y)
				trip.checks["arrival_includes_travel_for_one_step"] = bool(arrived.get("ok", false)) and Transit.point(session.overworld.hero_position) == exit and int(session.overworld.movement.current) == before_arrival - 1
			trip["egress"] = {"x": egress.x, "y": egress.y, "move": moved, "arrival": arrived}
			trip.checks["can_leave_gate_body"] = bool(moved.get("ok", false))
			place(session, entry)
			session.overworld.movement.current = 0
			Heroes.commit_active_hero(session)
			var no_moves: Dictionary = Rules.perform_context_action(session, "collect_resource")
			trip.checks["zero_movement_cannot_return"] = not bool(no_moves.get("ok", false)) and Transit.point(session.overworld.hero_position) == entry
			var invalid = clone(source)
			var broken: Dictionary = Rules._find_resource_node_by_placement(invalid, String(gate.placement_id)).node
			broken.native_transit.target_placement_id = "missing_gate"
			trip.checks["missing_peer_fails_validation"] = not Transit.validate(invalid.overworld.resource_nodes).is_empty()
			trip.checks.merge(exercise_exit_safety(source, gate))
			trip["ai"] = exercise_ai(source, gate, egress)
			trip.checks["ai_uses_exact_native_destination"] = bool(trip.ai.get("exact_destination", false))
			trip.checks["ai_transit_preserves_treasury_and_node"] = bool(trip.ai.get("unchanged_rewards", false))
			trip.checks["ai_gate_path_is_reachable"] = bool(trip.ai.get("path_reachable", false))
			trip.checks["full_ai_advance_uses_gate"] = bool(trip.ai.get("full_advance_used_gate", false))
			trip.checks["ai_routes_to_real_target_through_gate"] = bool(trip.ai.get("strategic", {}).get("ok", false))
			report.trips.append(trip)
		if OS.get_environment("HEROES_TRANSIT_RENDER") == "1":
			report["visual"] = await exercise_visual(source, gates[1], out)
	var file := FileAccess.open(out.path_join("runtime_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	service = null
	get_tree().quit()

func exercise_navigation_field() -> bool:
	var size := Vector2i(4, 3)
	var mask := PackedByteArray()
	mask.resize(24)
	mask.fill(0)
	var entry := {"x": 1, "y": 1, "level": 0}
	var exit := {"x": 1, "y": 1, "level": 1}
	var links := [{"source_placement_id": "a", "target_placement_id": "b", "entry": entry, "exit": exit}, {"source_placement_id": "b", "target_placement_id": "a", "entry": exit, "exit": entry}]
	var from := Vector3i(0, 1, 0)
	var entered: Dictionary = Transit.navigation_field(size, 2, mask, links, from)
	var entry_index := Transit.navigation_index(Transit.point(entry), size, 2)
	var exit_index := Transit.navigation_index(Transit.point(exit), size, 2)
	var correct: bool = bool(entered.get("ok", false)) and entered.distances[exit_index] == 1 and entered.first_steps[exit_index] == entry_index and entered.first_links[exit_index] == 0
	var standing: Dictionary = Transit.navigation_field(size, 2, mask, links, Transit.point(entry))
	var returned: Dictionary = Transit.navigation_field(size, 2, mask, links, Transit.point(exit))
	correct = correct and standing.distances[exit_index] == 1 and returned.distances[entry_index] == 1
	var one_way: Dictionary = Transit.navigation_field(size, 2, mask, [links[0]], Transit.point(exit))
	correct = correct and one_way.distances[entry_index] == -1
	var chain := [links[0], {"source_placement_id": "c", "target_placement_id": "d", "entry": {"x": 2, "y": 1, "level": 1}, "exit": {"x": 3, "y": 1, "level": 0}}]
	var chained: Dictionary = Transit.navigation_field(size, 2, mask, chain, from)
	correct = correct and chained.distances[Transit.navigation_index(Vector3i(3, 1, 0), size, 2)] == 2
	mask[entry_index] = 1
	correct = correct and not bool(Transit.navigation_field(size, 2, mask, links, from).get("ok", false))
	mask.fill(0)
	mask[1] = 1
	mask[4] = 1
	var corner: Dictionary = Transit.navigation_field(size, 2, mask, [], Vector3i.ZERO)
	var native_corner: Dictionary = Transit.navigation_field(size, 2, mask, [], Vector3i.ZERO, true)
	return correct and corner.distances[entry_index] == -1 and native_corner.distances[entry_index] == 1 and native_corner.distances[1] == -1 and native_corner.distances[4] == -1

func exercise_source_corner(source) -> Dictionary:
	# Exact original 0x49eb8d predecessor, independently captured from seed 68.
	# This focused step fixture relocates its clone; continuous journeys below
	# still start at the real town and cannot use this helper to bypass travel.
	var session = clone(source)
	var start := Vector2i(10, 12)
	var target := Vector2i(9, 11)
	place(session, Vector3i(start.x, start.y, 1))
	var checks := {}
	checks["source_rock_corner_retained"] = Levels.terrain_id_at(session, 10, 11, 1) == "rock" and Levels.terrain_id_at(session, 9, 12, 1) == "rock" and not Rules.tile_is_blocked(session, target.x, target.y, 1)
	checks["native_adjacency_selected"] = Transit.uses_native_adjacency(session) and not Rules.tile_step_cuts_blocked_corner(session, start, target, 1)
	var authored = clone(session)
	authored.flags.erase("native_random_map_package_session_adoption")
	checks["authored_corner_unchanged"] = Rules.tile_step_cuts_blocked_corner(authored, start, target, 1)
	var context: Dictionary = Ai._path_distance_surface_context(session, String(session.overworld.active_hero_id), String(session.overworld.active_player_id), 1)
	var plan: Dictionary = Ai._native_navigation_plan(context, start, [target], 1)
	checks["ai_uses_same_adjacent_edge"] = int(plan.get("goal_distance", 9999)) == 1 and plan.get("next_step") == target
	var shell = load("res://scenes/overworld/OverworldShell.gd").new()
	shell._session = session
	shell._map_size = Rules.derive_map_size(session)
	var path: Array = shell._build_path(start, target)
	checks["player_route_uses_same_edge"] = path == [start, target]
	shell.free()
	var movement := int(session.overworld.movement.current)
	var rejected: Dictionary = Rules.try_move(session, 0, -1)
	checks["rock_destination_still_rejected"] = not bool(rejected.get("ok", false)) and Rules.hero_position(session) == start and int(session.overworld.movement.current) == movement
	var moved: Dictionary = Rules.try_move(session, -1, -1)
	checks["paid_live_diagonal_step"] = bool(moved.get("ok", false)) and Rules.hero_position(session) == target and int(session.overworld.movement.current) == movement - 1
	var saved: Dictionary = SaveService.save_runtime_file_session(session, "source_corner")
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file("source_corner"))
	var returned: Dictionary = Rules.try_move(resumed, 1, 1) if resumed != null else {}
	checks["save_resume_return_preserves_policy"] = bool(saved.get("ok", false)) and resumed != null and Transit.uses_native_adjacency(resumed) and bool(returned.get("ok", false)) and Rules.hero_position(resumed) == start and int(resumed.overworld.movement.current) == movement - 2
	return {"ok": not checks.values().has(false), "checks": checks, "start": str(start), "target": str(target), "move": moved, "ai_plan": str(plan)}

func exercise_legacy(source, gates: Array) -> Dictionary:
	var old = clone(source)
	old.overworld.erase("native_transit_compatibility")
	for record in old.overworld.package_source_objects_by_id.values():
		record.erase("native_transit")
	for node in old.overworld.resource_nodes:
		node.erase("native_transit")
		node.erase("h3m_type_id")
		node.erase("h3m_subtype")
	# Exercise the old-source decoder before current package rehydration can
	# legitimately restore the newer immutable package's own sidecar instead.
	Transit.normalize_legacy_session(old)
	var initial: Dictionary = old.overworld.get("native_transit_compatibility", {}).duplicate(true)
	Rules.normalize_overworld_state(old)
	var valid := int(old.overworld.get("native_transit_compatibility", {}).get("reconstructed_legacy_cave_ends", 0)) == 8 and Transit.validate(old.overworld.resource_nodes).is_empty()
	var mismatches := []
	for gate in gates:
		var restored: Dictionary = Rules._find_resource_node_by_placement(old, String(gate.placement_id)).node
		# Godot JSON reads schema numbers as float. The runtime contract
		# validates the integer version; do not confuse 1.0 with a lost link.
		var expected: Dictionary = gate.get("native_transit", {}).duplicate(true)
		expected["schema_version"] = int(expected.get("schema_version", 0))
		var actual: Dictionary = restored.get("native_transit", {}).duplicate(true)
		actual["schema_version"] = int(actual.get("schema_version", 0))
		valid = valid and actual == expected
		if actual != expected:
			mismatches.append({"expected": gate.get("native_transit"), "restored": restored.get("native_transit")})
	return {"ok": valid, "initial": initial, "final": old.overworld.get("native_transit_compatibility", {}), "mismatches": mismatches}

func exercise_portals(source, gates: Array) -> Dictionary:
	var old = clone(source)
	old.overworld.erase("native_transit_compatibility")
	for record in old.overworld.package_source_objects_by_id.values():
		record.erase("native_transit")
	for node in old.overworld.resource_nodes:
		node.erase("native_transit")
		node.erase("h3m_type_id")
		node.erase("h3m_subtype")
	Transit.normalize_legacy_session(old)
	var report := {"contract_errors": Transit.validate(source.overworld.resource_nodes), "legacy_errors": Transit.validate(old.overworld.resource_nodes), "ends": [], "representatives": []}
	for gate in gates:
		if Transit.destinations(gate).size() > 1:
			report["multihero_credit"] = exercise_multihero_credit(source, gate, gates)
			break
	var represented := {}
	if OS.get_environment("HEROES_TRANSIT_REPRESENTATIVES_ONLY") == "1":
		report["representatives_only"] = true
		for gate in gates:
			var options := Transit.destinations(gate)
			var shape := str(int(gate.h3m_type_id)) + ":" + str(options.size())
			if not options.is_empty() and not represented.has(shape):
				represented[shape] = true
				report.representatives.append(exercise_portal_representative(source, gate, shape))
		return report
	for gate in gates:
		var session = clone(source)
		for encounter in session.overworld.encounters:
			session.overworld.resolved_encounters.append(String(encounter.placement_id))
		var node: Dictionary = Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node
		var entry := Transit.point(Transit.link_of(node).get("entry"))
		place(session, entry)
		var before: Dictionary = node.duplicate(true)
		var resources: Dictionary = session.overworld.resources.duplicate(true)
		var entry_movement := int(session.overworld.movement.current)
		var options := Transit.destinations(node)
		var restored: Dictionary = Rules._find_resource_node_by_placement(old, String(gate.placement_id)).node
		var end := {"placement_id": gate.placement_id, "type": gate.h3m_type_id, "subtype": gate.h3m_subtype, "checks": {}, "trips": []}
		var restored_link := Transit.link_of(restored).duplicate(true)
		var expected_link := Transit.link_of(node).duplicate(true)
		restored_link["schema_version"] = int(restored_link.get("schema_version", 0))
		expected_link["schema_version"] = int(expected_link.get("schema_version", 0))
		end.checks["legacy_exact_group_restore"] = restored_link == expected_link
		end["legacy_links"] = {"restored": restored_link, "expected": expected_link}
		end.checks["not_authored_local_offset"] = not Rules.active_linked_transit_edges(session, entry.z).any(func(edge): return edge.get("placement_id") == gate.placement_id)
		if options.is_empty():
			var unavailable: Dictionary = Rules.perform_context_action(session, "collect_resource")
			end["unavailable_result"] = unavailable
			end.checks["arrival_only_or_stranded_is_explicit"] = not bool(unavailable.get("ok", false)) and String(unavailable.get("error", "")) == "native_passage_has_no_exit" and Transit.point(session.overworld.hero_position) == entry and int(session.overworld.movement.current) == entry_movement and node == before and session.overworld.resources == resources
			end["inactive_approach"] = exercise_inactive_portal_approach(session, entry)
			end.checks["inactive_portal_approach_is_a_successful_move"] = bool(end.inactive_approach.get("ok", false))
		else:
			var invalid = clone(session)
			var broken: Dictionary = Rules._find_resource_node_by_placement(invalid, String(gate.placement_id)).node
			broken.native_transit.destinations.pop_back()
			end.checks["missing_destination_fails_validation"] = not Transit.validate(invalid.overworld.resource_nodes).is_empty()
			if options.size() > 1:
				var pending: Dictionary = Rules.perform_context_action(session, "collect_resource")
				var actions := Rules.get_context_actions(session)
				end.checks["multiple_destinations_require_explicit_choice"] = bool(pending.get("native_transit_choice_required", false)) and int(session.overworld.movement.current) == entry_movement and Transit.point(session.overworld.hero_position) == entry
				end.checks["every_exit_has_context_action"] = options.all(func(destination): return actions.any(func(action): return action.get("id") == "native_transit:" + String(destination.target_placement_id)))
			for destination in options:
				var trip_session = clone(session)
				var trip_node: Dictionary = Rules._find_resource_node_by_placement(trip_session, String(gate.placement_id)).node
				var exit := Transit.point(destination.exit)
				var action_id := "native_transit:" + String(destination.target_placement_id)
				var before_movement := int(trip_session.overworld.movement.current)
				var before_trip_node := trip_node.duplicate(true)
				var before_trip_resources: Dictionary = trip_session.overworld.resources.duplicate(true)
				var result: Dictionary = Rules.perform_context_action(trip_session, action_id)
				var trip := {"target_placement_id": destination.target_placement_id, "result": result, "checks": {}, "movement_before": before_movement, "movement_after": int(trip_session.overworld.movement.current), "node_unchanged": trip_node == before_trip_node, "resources_unchanged": trip_session.overworld.resources == before_trip_resources}
				trip.checks["context_action_reaches_exact_exit"] = bool(result.get("ok", false)) and Transit.point(trip_session.overworld.hero_position) == exit
				trip.checks["one_movement_no_claim_or_reward"] = int(trip_session.overworld.movement.current) == before_movement - 1 and trip_node == before_trip_node and trip_session.overworld.resources == before_trip_resources
				trip.checks["save_roundtrip_keeps_position_group_and_fog"] = clone(trip_session).to_dict() == trip_session.to_dict()
				var occupied = clone(session)
				var other: Dictionary = occupied.overworld.player_heroes[0].duplicate(true)
				other.id = "portal_occupied_exit_probe"
				other.position = destination.exit.duplicate(true)
				occupied.overworld.player_heroes.append(other)
				var occupied_movement := int(occupied.overworld.movement.current)
				var rejected: Dictionary = Rules.perform_context_action(occupied, action_id)
				trip["occupied_result"] = rejected
				trip.checks["occupied_exit_rejected_without_cost"] = not bool(rejected.get("ok", false)) and Transit.point(occupied.overworld.hero_position) == entry and int(occupied.overworld.movement.current) == occupied_movement
				if options.size() > 1:
					var arrived = clone(session)
					var arrived_node: Dictionary = Rules._find_resource_node_by_placement(arrived, String(gate.placement_id)).node
					var choose: Dictionary = Rules.travel_native_passage(arrived, arrived_node, 0)
					var resumed = clone(arrived)
					var resumed_movement := int(resumed.overworld.movement.current)
					var chosen: Dictionary = Rules.perform_context_action(resumed, action_id)
					trip.checks["paid_arrival_choice_survives_save_without_double_charge"] = bool(choose.get("native_transit_choice_required", false)) and bool(chosen.get("ok", false)) and int(resumed.overworld.movement.current) == resumed_movement and Transit.point(resumed.overworld.hero_position) == exit
					var tomorrow = clone(arrived)
					tomorrow.day += 1
					var tomorrow_movement := int(tomorrow.overworld.movement.current)
					var next_day: Dictionary = Rules.perform_context_action(tomorrow, action_id)
					trip.checks["arrival_credit_does_not_grant_next_day_free_travel"] = bool(next_day.get("ok", false)) and int(tomorrow.overworld.movement.current) == tomorrow_movement - 1
				end.trips.append(trip)
			var shape := str(int(gate.h3m_type_id)) + ":" + str(options.size())
			if not represented.has(shape):
				represented[shape] = true
				report.representatives.append(exercise_portal_representative(source, gate, shape))
		report.ends.append(end)
		print("TRANSIT_PORTAL_END " + String(gate.placement_id) + " destinations=" + str(end.trips.size()))
	return report

func player_journey_context(session) -> Dictionary:
	# AI terminal-object allowances are not a player walking surface. Retain
	# every player-visible body/corner and open only validated native entries.
	var context: Dictionary = Ai._path_distance_surface_context(session, String(session.overworld.active_hero_id), String(session.overworld.active_player_id), Rules.hero_level(session)).duplicate(true)
	var navigation: Dictionary = context.get("native_navigation", {})
	if not bool(navigation.get("ok", false)):
		return context
	var mask := PackedByteArray()
	var size: Vector2i = navigation.map_size
	for level in range(int(navigation.level_count)):
		var blocked: Dictionary = Rules._blocked_tile_index(session, level)
		var terrain: Array = Levels.terrain_rows(session, level)
		for y in range(size.y):
			for x in range(size.x):
				mask.append(1 if blocked.has("%d,%d" % [x, y]) or not Rules.terrain_id_is_passable(String(terrain[y][x])) else 0)
	for link in navigation.links:
		for endpoint in [link.entry, link.exit]:
			var index := Transit.navigation_index(Transit.point(endpoint), size, int(navigation.level_count))
			mask[index] = 0
	navigation["blocked"] = mask
	navigation["fields"] = {}
	return context

func player_journey_plan(session, context: Dictionary, goal: Vector2i, level: int) -> Dictionary:
	var start: Vector2i = Rules.hero_position(session)
	var plan: Dictionary = Ai._native_navigation_plan(context, start, [goal], level)
	if int(plan.get("goal_distance", 9999)) < 9999:
		return plan
	# An interaction can be a necessary intermediate stop, not a permanent
	# wall. Use the actual player's route owner to reach such stops, including
	# its town-doorway corner rule. The AI field ranks destinations only; it
	# never authorizes a player step, removes a body or changes map topology.
	var shell = load("res://scenes/overworld/OverworldShell.gd").new()
	shell._session = session
	shell._map_size = Rules.derive_map_size(session)
	var strategic: Dictionary = Ai._path_distance_surface_context(session, String(session.overworld.active_hero_id), String(session.overworld.active_player_id), Rules.hero_level(session))
	var waypoint_evidence := []
	for node in session.overworld.resource_nodes:
		if Levels.level_of(node) != Rules.hero_level(session):
			continue
		var visit: Vector2i = Ai._resource_interaction_tile(node)
		if visit == start:
			continue
		var path: Array = shell._build_path(start, visit)
		if path.size() < 2:
			continue
		var remaining: Dictionary = Ai._native_navigation_plan(strategic, visit, [goal], level)
		waypoint_evidence.append({"site_id": node.placement_id, "visit": str(visit), "walk_steps": path.size() - 1, "remaining_distance": remaining.get("goal_distance", 9999)})
		var cost := path.size() - 1 + int(remaining.get("goal_distance", 9999))
		if cost >= int(plan.get("goal_distance", 9999)):
			continue
		plan = {"goal_distance": cost, "next_goal_distance": cost - 1, "next_step": path[1], "intermediate_site_id": String(node.placement_id)}
		var link: Dictionary = remaining.get("native_transit", {})
		if path.size() == 2 and String(link.get("source_placement_id", "")) == String(node.placement_id):
			plan["native_transit"] = link
	shell.free()
	if int(plan.get("goal_distance", 9999)) >= 9999:
		print("TRANSIT_WAYPOINT_QUERY " + JSON.stringify({"goal": str(goal), "goal_level": level, "hero_level": Rules.hero_level(session), "view_level": Levels.view_level(session), "native_links": strategic.get("native_navigation", {}).get("links", []).size(), "candidates": waypoint_evidence}))
	return plan

func exercise_town_journeys(source) -> Dictionary:
	# A post-guard traversal fixture, not a battle/balance playthrough. Keep
	# native terrain, masks, towns, source links and the real starting hero.
	# Every step/turn/save below goes through the production action owner.
	var journeys := []
	var home := Transit.point(source.overworld.hero_position)
	var home_id := ""
	for town in source.overworld.towns:
		if Transit.point(Levels.town_entrance(town)) == home:
			home_id = String(town.placement_id)
			continue
		var session = clone(source)
		for encounter in session.overworld.encounters:
			session.overworld.resolved_encounters.append(String(encounter.placement_id))
		Rules.invalidate_spatial_lookup(session)
		Rules._refresh_blocked_tile_index(session)
		var entrance := Transit.point(Levels.town_entrance(town))
		var context := player_journey_context(session)
		var goal := Vector3i(-1, -1, entrance.z)
		var best := 9999
		# Stop on a clear adjacent tile; town assault/capture is a separate rule.
		for delta in Ai.PATH_MOVEMENT_DELTAS:
			var tile := Vector2i(entrance.x + delta.x, entrance.y + delta.y)
			if Rules.tile_is_blocked(session, tile.x, tile.y, entrance.z) or Rules.tile_has_route_interaction(session, tile.x, tile.y, entrance.z):
				continue
			var plan := player_journey_plan(session, context, tile, entrance.z)
			if int(plan.get("goal_distance", 9999)) < best:
				best = int(plan.goal_distance)
				goal = Vector3i(tile.x, tile.y, entrance.z)
		var row := {"town_id": town.placement_id, "start": Levels.position(home), "goal": Levels.position(goal), "initial_distance": best, "steps": [], "turns": [], "passages": [], "battles": [], "ok": false}
		var visits := {}
		for step in range(400):
			var position := Transit.point(session.overworld.hero_position)
			if position == goal:
				row["ok"] = true
				break
			if goal.x < 0:
				row["error"] = "no_reachable_town_approach"
				break
			if int(session.overworld.movement.current) <= 0:
				var before_day: int = session.day
				var turn: Dictionary = Rules.end_turn(session)
				row.turns.append({"before": before_day, "after": session.day, "result": turn})
				if session.day != before_day + 1 or int(session.overworld.movement.current) <= 0:
					row["error"] = "end_turn_did_not_restore_movement"
					break
			context = player_journey_context(session)
			var plan := player_journey_plan(session, context, Vector2i(goal.x, goal.y), goal.z)
			# The corrected adjacency can route around the first raid. Keep the
			# previously exposed battle handoff covered by deliberately pursuing
			# a real, turn-spawned enemy on the first Islands journey. No army,
			# position, target or battle state is injected into the live fixture.
			if OS.get_environment("HEROES_TRANSIT_PORTAL_CASE") == "small_islands" and journeys.is_empty() and row.battles.is_empty() and not row.turns.is_empty():
				var contact_plan := player_journey_enemy_contact_plan(session, context)
				if int(contact_plan.get("goal_distance", 9999)) < 9999:
					plan = contact_plan
					row["deliberate_field_contact"] = true
			if int(plan.get("goal_distance", 9999)) >= 9999:
				# A real enemy turn can occupy the previously selected approach.
				# Keep the town intent and choose another legal adjacent tile.
				for delta in Ai.PATH_MOVEMENT_DELTAS:
					var tile := Vector2i(entrance.x + delta.x, entrance.y + delta.y)
					if Rules.tile_is_blocked(session, tile.x, tile.y, entrance.z) or Rules.tile_has_route_interaction(session, tile.x, tile.y, entrance.z):
						continue
					var alternative := player_journey_plan(session, context, tile, entrance.z)
					if int(alternative.get("goal_distance", 9999)) < int(plan.get("goal_distance", 9999)):
						goal = Vector3i(tile.x, tile.y, entrance.z)
						row["goal"] = Levels.position(goal)
						plan = alternative
				if int(plan.get("goal_distance", 9999)) >= 9999:
					# Do not erase a newly spawned army to make a route pass. Walk
					# to real contact and run the battle if it blocks this journey.
					for encounter in session.overworld.encounters:
						if Rules.is_encounter_resolved(session, encounter) or Levels.level_of(encounter) != position.z:
							continue
						var enemy := Vector2i(int(encounter.x), int(encounter.y))
						for delta in Ai.PATH_MOVEMENT_DELTAS:
							var adjacent: Vector2i = enemy + delta
							if Rules.tile_is_blocked(session, adjacent.x, adjacent.y, position.z) or Rules.tile_has_route_interaction(session, adjacent.x, adjacent.y, position.z) or Rules.tile_step_cuts_blocked_corner(session, adjacent, enemy, position.z):
								continue
							var approach: Dictionary = Ai._native_navigation_plan(context, Vector2i(position.x, position.y), [adjacent], position.z)
							if int(approach.get("goal_distance", 9999)) + 1 < int(plan.get("goal_distance", 9999)):
								plan = approach
								if int(plan.goal_distance) == 0:
									plan["next_step"] = enemy
								plan["goal_distance"] = int(plan.goal_distance) + 1
					if int(plan.get("goal_distance", 9999)) >= 9999:
						row["error"] = "journey_became_unreachable"
						row["live_encounters"] = session.overworld.encounters.filter(func(encounter): return String(encounter.placement_id) not in session.overworld.resolved_encounters)
						break
			var next: Vector2i = plan.next_step
			var link: Dictionary = plan.get("native_transit", {})
			var before_moves := int(session.overworld.movement.current)
			var moved := {}
			if next != Vector2i(position.x, position.y):
				moved = Rules.try_move(session, next.x - position.x, next.y - position.y)
			elif not link.is_empty():
				moved = Rules.perform_context_action(session, "native_transit:" + String(link.target_placement_id))
			if bool(moved.get("native_transit_choice_required", false)) and not link.is_empty():
				moved = Rules.perform_context_action(session, "native_transit:" + String(link.target_placement_id))
			var after := Transit.point(session.overworld.hero_position)
			row.steps.append({"from": Levels.position(position), "to": Levels.position(after), "plan": plan, "result": moved, "cost": before_moves - int(session.overworld.movement.current)})
			if not bool(moved.get("ok", false)) or before_moves - int(session.overworld.movement.current) != 1:
				row["error"] = "planned_step_failed_or_wrong_cost"
				break
			if String(moved.get("route", "")) == "battle":
				# Production JSON saves deserialize numbers as floats. Compare
				# both complete town trees through that same representation.
				var towns_before: Array = JSON.parse_string(JSON.stringify(session.overworld.towns))
				var context_check := String(session.battle.get("context", {}).get("type", "")) == "encounter" and String(session.battle.get("player_commander_state", {}).get("id", "")) == String(session.overworld.active_hero_id)
				if not context_check:
					row["error"] = "field_contact_used_remote_battle_context"
					break
				# Exercise both implicit contact and explicit real siege contexts
				# without changing the live raid or its strategic target.
				var raid: Dictionary = Ai._find_encounter_by_placement(session, String(session.battle.resolved_key)).get("encounter", {})
				if String(raid.get("target_kind", "")) == "town":
					var target_town: Dictionary = Rules._find_town_by_placement(session, String(raid.target_placement_id)).get("town", {})
					var contact := raid.duplicate(true)
					contact.merge(Levels.town_entrance(target_town), true)
					var at_town: Dictionary = Battles._normalized_battle_context_fields(session, contact)
					contact["level"] = 1 - Levels.level_of(target_town)
					var other_level: Dictionary = Battles._normalized_battle_context_fields(session, contact)
					contact["battle_context"] = at_town.duplicate(true)
					var explicit_siege: Dictionary = Battles._normalized_battle_context_fields(session, contact)
					if String(at_town.get("type", "")) != "town_defense" or String(other_level.get("type", "")) != "encounter" or explicit_siege != at_town:
						row["error"] = "town_contact_context_boundary_failed"
						break
				session.game_state = "battle"
				var saved: Dictionary = SaveService.save_runtime_file_session(session, "journey_battle")
				var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file("journey_battle"))
				if not bool(saved.get("ok", false)) or resumed == null or resumed.battle.is_empty():
					row["error"] = "journey_battle_save_failed"
					break
				session = resumed
				var battle: Dictionary = AutoBattle.resolve_active_battle(session)
				var towns_after: Array = JSON.parse_string(JSON.stringify(session.overworld.towns))
				battle["remote_towns_unchanged"] = towns_after == towns_before
				battle["town_changes"] = []
				for previous in towns_before:
					var matches: Array = towns_after.filter(func(town_state): return town_state.placement_id == previous.placement_id)
					var current: Dictionary = matches[0] if not matches.is_empty() else {}
					for key in previous.merged(current).keys():
						if previous.get(key) != current.get(key):
							battle.town_changes.append({"town_id": previous.placement_id, "field": key, "before": previous.get(key), "after": current.get(key)})
				row.battles.append(battle)
				if not bool(battle.get("completed", false)) or String(battle.get("state", "")) != "victory" or not bool(battle.remote_towns_unchanged):
					row["error"] = "journey_battle_not_won"
					break
				SessionState.active_session = session
				var checkpoint: Dictionary = AppRouter.checkpoint_battle_resolution_for_overworld(false)
				battle["overworld_checkpoint"] = bool(checkpoint.get("ok", false)) and session.game_state == "overworld"
				if not bool(battle.overworld_checkpoint):
					row["error"] = "battle_return_checkpoint_failed"
					break
			if moved.has("native_transit"):
				row.passages.append(moved.native_transit)
				var save_id := "journey_" + str(journeys.size()) + "_" + str(row.passages.size())
				var saved: Dictionary = SaveService.save_runtime_file_session(session, save_id)
				var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file(save_id))
				if not bool(saved.get("ok", false)) or resumed == null or Transit.point(resumed.overworld.hero_position) != after or resumed.overworld.fog != session.overworld.fog:
					row["error"] = "journey_save_failed"
					break
				session = resumed
			var key := str(after)
			visits[key] = int(visits.get(key, 0)) + 1
			if int(visits[key]) > 3:
				row["error"] = "route_cycle"
				break
		row["finish"] = Levels.position(Transit.point(session.overworld.hero_position))
		journeys.append(row)
		print("TRANSIT_JOURNEY " + String(town.placement_id) + " ok=" + str(row.ok) + " steps=" + str(row.steps.size()) + " passages=" + str(row.passages.size()))
	SessionState.active_session = null
	return {"ok": not journeys.is_empty() and journeys.all(func(row): return bool(row.ok)), "fixture": "post_guard_starting_town_to_other_town_approaches", "starting_town_id": home_id, "journeys": journeys}

func player_journey_enemy_contact_plan(session, context: Dictionary) -> Dictionary:
	var position := Transit.point(session.overworld.hero_position)
	var best := {"goal_distance": 9999}
	for encounter in session.overworld.encounters:
		if Rules.is_encounter_resolved(session, encounter) or Levels.level_of(encounter) != position.z or String(encounter.get("spawned_by_faction_id", "")) == "":
			continue
		var enemy := Vector2i(int(encounter.x), int(encounter.y))
		for delta in Ai.PATH_MOVEMENT_DELTAS:
			var adjacent: Vector2i = enemy + delta
			if Rules.tile_is_blocked(session, adjacent.x, adjacent.y, position.z) or Rules.tile_has_route_interaction(session, adjacent.x, adjacent.y, position.z) or Rules.tile_step_cuts_blocked_corner(session, adjacent, enemy, position.z):
				continue
			var approach: Dictionary = Ai._native_navigation_plan(context, Vector2i(position.x, position.y), [adjacent], position.z)
			if int(approach.get("goal_distance", 9999)) + 1 < int(best.goal_distance):
				best = approach
				if int(best.goal_distance) == 0:
					best["next_step"] = enemy
				best["goal_distance"] = int(best.goal_distance) + 1
	return best

func exercise_multihero_credit(source, gate: Dictionary, gates: Array) -> Dictionary:
	var session = clone(source)
	for encounter in session.overworld.encounters:
		session.overworld.resolved_encounters.append(String(encounter.placement_id))
	var first_id := String(session.overworld.active_hero_id)
	var entry := Transit.point(Transit.link_of(gate).entry)
	place(session, entry)
	var first_arrival := {}
	for delta in Ai.PATH_MOVEMENT_DELTAS:
		var tile := Vector2i(entry.x + delta.x, entry.y + delta.y)
		if Rules.tile_is_blocked(session, tile.x, tile.y, entry.z) or Rules.tile_has_route_interaction(session, tile.x, tile.y, entry.z) or Rules.tile_step_cuts_blocked_corner(session, Vector2i(entry.x, entry.y), tile):
			continue
		var left: Dictionary = Rules.try_move(session, delta.x, delta.y)
		if bool(left.get("ok", false)):
			first_arrival = Rules.try_move(session, -delta.x, -delta.y)
		break
	var first_movement := int(session.overworld.movement.current)
	var second_gate := {}
	var second_exit := {}
	var first_exit: Dictionary = Transit.destinations(gate)[0]
	for candidate in gates:
		if String(candidate.placement_id) == String(gate.placement_id):
			continue
		for destination in Transit.destinations(candidate):
			if String(destination.target_placement_id) not in [String(gate.placement_id), String(first_exit.target_placement_id)]:
				second_gate = candidate
				second_exit = destination
				break
		if not second_gate.is_empty():
			break
	if second_gate.is_empty():
		return {"ok": false, "error": "no_independent_second_hero_trip"}
	# A second real hero template with a controlled starting army; recruitment
	# pricing is outside this movement-credit fixture. Switching/saving/travel
	# all use the production roster and action owners.
	var second_id := "hero_vaska" if first_id != "hero_vaska" else "hero_veilmourn_orso_nightchart"
	var second: Dictionary = Heroes._normalize_player_hero({"id": second_id, "is_primary": false}, session, Transit.link_of(second_gate).entry, session.overworld.army, {"current": 14, "max": 14})
	session.overworld.player_heroes.append(second)
	var pending_before: Dictionary = session.overworld.get("native_transit_pending_arrival", {}).duplicate(true)
	var switched: Dictionary = Heroes.set_active_hero(session, second_id)
	Rules.invalidate_spatial_lookup(session)
	var second_arrival := {}
	if Transit.destinations(second_gate).size() > 1:
		second_arrival = exercise_inactive_portal_approach(session, Transit.point(Transit.link_of(second_gate).entry))
		if not bool(second_arrival.get("ok", false)):
			return {"ok": false, "error": "second_hero_approach_failed", "second_arrival": second_arrival}
	var pending_both: Dictionary = session.overworld.get("native_transit_pending_arrival", {}).duplicate(true)
	var both_saved: Dictionary = SaveService.save_runtime_file_session(session, "multihero_both_pending")
	session = SaveService.restore_session_from_summary(SaveService.inspect_save_file("multihero_both_pending"))
	if session == null:
		return {"ok": false, "error": "two_hero_pending_save_failed"}
	var second_trip: Dictionary = Rules.perform_context_action(session, "native_transit:" + String(second_exit.target_placement_id))
	var pending_after: Dictionary = session.overworld.get("native_transit_pending_arrival", {}).duplicate(true)
	var saved: Dictionary = SaveService.save_runtime_file_session(session, "multihero_portal_credit")
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file("multihero_portal_credit"))
	var switched_back: Dictionary = Heroes.set_active_hero(resumed, first_id) if resumed != null else {}
	var first_trip: Dictionary = Rules.perform_context_action(resumed, "native_transit:" + String(first_exit.target_placement_id)) if bool(switched_back.get("ok", false)) else {}
	var after := int(resumed.overworld.movement.current) if resumed != null else -1
	return {"ok": bool(first_arrival.get("native_transit_choice_required", false)) and bool(switched.get("ok", false)) and bool(both_saved.get("ok", false)) and bool(second_trip.get("ok", false)) and bool(saved.get("ok", false)) and bool(first_trip.get("ok", false)) and after == first_movement, "first_movement_before": first_movement, "first_movement_after": after, "first_arrival": first_arrival, "second_arrival": second_arrival, "second_trip": second_trip, "first_trip": first_trip, "pending_before_other_hero": pending_before, "pending_with_both_heroes": pending_both, "pending_after_other_hero": pending_after}

func exercise_inactive_portal_approach(session, entry: Vector3i) -> Dictionary:
	var local := Vector2i(entry.x, entry.y)
	for delta in Ai.PATH_MOVEMENT_DELTAS:
		var tile: Vector2i = local + delta
		if Rules.tile_is_blocked(session, tile.x, tile.y, entry.z) or Rules.tile_has_route_interaction(session, tile.x, tile.y, entry.z) or Rules.tile_step_cuts_blocked_corner(session, local, tile):
			continue
		var left: Dictionary = Rules.try_move(session, delta.x, delta.y)
		var before := int(session.overworld.movement.current)
		var returned: Dictionary = Rules.try_move(session, -delta.x, -delta.y) if bool(left.get("ok", false)) else {}
		return {"ok": bool(left.get("ok", false)) and bool(returned.get("ok", false)) and int(session.overworld.movement.current) == before - 1 and Transit.point(session.overworld.hero_position) == entry, "left": left, "returned": returned}
	return {"ok": false, "error": "no_legal_approach"}

func exercise_portal_representative(source, gate: Dictionary, shape: String) -> Dictionary:
	var session = clone(source)
	for encounter in session.overworld.encounters:
		session.overworld.resolved_encounters.append(String(encounter.placement_id))
	var node: Dictionary = Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node
	var entry := Transit.point(Transit.link_of(node).get("entry"))
	place(session, entry)
	var approach := Vector2i(-1, -1)
	var local := Vector2i(entry.x, entry.y)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tile := local + Vector2i(dx, dy)
			if tile != local and not Rules.tile_is_blocked(session, tile.x, tile.y) and not Rules.tile_has_route_interaction(session, tile.x, tile.y) and not Rules.tile_step_cuts_blocked_corner(session, local, tile):
				approach = tile
	var options := Transit.destinations(node)
	var destination: Dictionary = options[0]
	var expected_exit := Transit.point(destination.exit)
	var evidence_gate := gate.duplicate(true)
	evidence_gate.native_transit["exit"] = destination.exit.duplicate(true)
	evidence_gate.native_transit["target_placement_id"] = destination.target_placement_id
	var ai := exercise_ai(source, evidence_gate, approach, String(destination.target_placement_id))
	var checks := {"ai_exact_selected_destination": bool(ai.get("exact_destination", false)), "ai_no_claim_rewards": bool(ai.get("unchanged_rewards", false)), "ai_real_approach_path": bool(ai.get("path_reachable", false)), "ai_full_advance_uses_gate": bool(ai.get("full_advance_used_gate", false))}
	checks["ai_routes_to_real_target_through_gate"] = bool(ai.get("strategic", {}).get("ok", false))
	var left: Dictionary = Rules.try_move(session, approach.x - entry.x, approach.y - entry.y) if approach.x >= 0 else {}
	var movement_before := int(session.overworld.movement.current)
	var arrived: Dictionary = Rules.try_move(session, entry.x - approach.x, entry.y - approach.y) if bool(left.get("ok", false)) else {}
	var before_save_position := Transit.point(session.overworld.hero_position)
	var save_id := "portal_route_" + shape.replace(":", "_")
	var saved: Dictionary = SaveService.save_runtime_file_session(session, save_id)
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file(save_id))
	checks["production_save_keeps_position_contracts_and_fog"] = bool(saved.get("ok", false)) and resumed != null and Transit.point(resumed.overworld.hero_position) == before_save_position and resumed.overworld.fog == session.overworld.fog and Transit.validate(resumed.overworld.resource_nodes).is_empty()
	var chosen := {}
	if resumed != null and options.size() > 1:
		chosen = Rules.perform_context_action(resumed, "native_transit:" + String(destination.target_placement_id))
	checks["real_approach_then_saved_choice_spends_one_total"] = bool(left.get("ok", false)) and bool(arrived.get("ok", false)) and resumed != null and Transit.point(resumed.overworld.hero_position) == expected_exit and int(resumed.overworld.movement.current) == movement_before - 1
	return {"shape": shape, "placement_id": gate.placement_id, "checks": checks, "ai": ai, "left": left, "arrived": arrived, "chosen": chosen}

func exercise_portal_visual(source, gates: Array, out: String) -> Dictionary:
	var gate: Dictionary = gates[0]
	for candidate in gates:
		if Transit.destinations(candidate).size() > 1:
			gate = candidate
			break
	var session = clone(source)
	for encounter in session.overworld.encounters:
		session.overworld.resolved_encounters.append(String(encounter.placement_id))
	place(session, Transit.point(Transit.link_of(gate).get("entry")))
	SessionState.active_session = session
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	var size := OS.get_environment("HEROES_TRANSIT_RESOLUTION").split("x")
	get_window().size = Vector2i(int(size[0]), int(size[1]))
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("portal_before.png"))
	var options := Transit.destinations(gate)
	var actions := Rules.get_context_actions(session)
	var controls_inside := true
	var control_rects := []
	# Control rectangles are in the stretched logical viewport, not physical
	# window pixels. Compare like coordinates; assert raster size separately.
	var viewport: Rect2 = shell.get_viewport_rect()
	for control in shell._context_actions.get_children() + [shell._primary_action_button]:
		if control is Button and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			controls_inside = controls_inside and viewport.encloses(rect)
			control_rects.append({"label": control.text, "position": str(rect.position), "size": str(rect.size)})
	var action_id := "native_transit:" + String(options[0].target_placement_id) if options.size() > 1 else "collect_resource"
	var action_exists := actions.any(func(action): return action.get("id") == action_id)
	var choice_dialog_ok := true
	var cancel_preserves_state := true
	var dialog_bounds_ok := true
	var dialog_rects := {}
	if options.size() > 1:
		var before_choice_position := Transit.point(session.overworld.hero_position)
		var before_choice_movement := int(session.overworld.movement.current)
		shell._on_context_action_pressed("collect_resource")
		for frame in range(4):
			await get_tree().process_frame
		choice_dialog_ok = shell._native_destination_dialog != null and shell._native_destination_dialog.visible and shell._native_destination_picker.item_count == options.size() and shell._overworld_gameplay_movement_blocked_reason() == "native_destination_dialog_open"
		var dialog: ConfirmationDialog = shell._native_destination_dialog
		var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
		dialog_bounds_ok = shell.get_viewport_rect().encloses(dialog_rect)
		var dialog_local := Rect2(Vector2.ZERO, Vector2(dialog.size))
		for control in [shell._native_destination_picker, dialog.get_ok_button(), dialog.get_cancel_button()]:
			dialog_bounds_ok = dialog_bounds_ok and dialog_local.encloses(control.get_global_rect())
		dialog_rects = {"position": str(dialog.position), "size": str(dialog.size), "parent_viewport": str(shell.get_viewport_rect()), "ok_button": str(dialog.get_ok_button().get_global_rect()), "cancel_button": str(dialog.get_cancel_button().get_global_rect())}
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("portal_choices.png"))
		shell._on_native_destination_canceled()
		cancel_preserves_state = Transit.point(session.overworld.hero_position) == before_choice_position and int(session.overworld.movement.current) == before_choice_movement and not shell._native_destination_dialog.visible and shell._overworld_gameplay_movement_blocked_reason() == ""
		shell._on_context_action_pressed("collect_resource")
		for frame in range(4):
			await get_tree().process_frame
		shell._native_destination_picker.select(0)
		shell._native_destination_dialog.get_ok_button().pressed.emit()
	else:
		shell._on_context_action_pressed(action_id)
	for frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("portal_after.png"))
	var exit := Transit.point(options[0].exit)
	var checks := {"context_action_exists": action_exists, "controls_inside_viewport": controls_inside, "context_action_reaches_visible_exact_exit": Transit.point(session.overworld.hero_position) == exit and shell._map_view._has_hero_at(Vector2i(exit.x, exit.y)), "main_and_minimap_follow_destination": shell._map_view._level == exit.z and shell._minimap.validation_snapshot().level == exit.z, "no_teleport_walk_animation": shell._hero_movement_presentation.is_empty(), "resolution_matches": get_viewport().get_texture().get_image().get_size() == Vector2i(int(size[0]), int(size[1])), "control_rects": control_rects, "choice_dialog_has_all_exits_and_owns_input": choice_dialog_ok, "choice_cancel_does_not_move_or_spend": cancel_preserves_state, "choice_dialog_and_buttons_inside_viewport": dialog_bounds_ok, "dialog_rects": dialog_rects}
	shell.queue_free()
	await get_tree().process_frame
	return checks

func exercise_exit_safety(source, gate: Dictionary) -> Dictionary:
	var checks := {}
	for blocker_kind in ["body", "hero", "army"]:
		var session = clone(source)
		for encounter in session.overworld.encounters:
			session.overworld.resolved_encounters.append(String(encounter.placement_id))
		var node: Dictionary = Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node
		var exit: Dictionary = gate.native_transit.exit.duplicate(true)
		if blocker_kind == "body":
			session.overworld.map_objects.append({"placement_id": "transit_exit_overlap_probe", "kind": "decorative_obstacle", "x": int(exit.x), "y": int(exit.y), "level": int(exit.level), "blocking_body": true, "package_block_tiles": [exit]})
		elif blocker_kind == "hero":
			var hero: Dictionary = session.overworld.player_heroes[0].duplicate(true)
			hero.id = "transit_exit_hero_probe"
			hero.position = exit
			session.overworld.player_heroes.append(hero)
		else:
			session.overworld.encounters.append({"placement_id": "transit_exit_army_probe", "encounter_id": "encounter_mire_raid", "x": int(exit.x), "y": int(exit.y), "level": int(exit.level), "blocking_body": false})
		place(session, Transit.point(gate.native_transit.entry))
		var before := int(session.overworld.movement.current)
		var result: Dictionary = Rules.perform_context_action(session, "collect_resource")
		checks["exit_%s_blocks_without_spending" % blocker_kind] = not bool(result.get("ok", false)) and int(session.overworld.movement.current) == before and Transit.point(session.overworld.hero_position) == Transit.point(gate.native_transit.entry)
	return checks

func exercise_ai(source, gate: Dictionary, approach: Vector2i, target_exit_id: String = "") -> Dictionary:
	var session = clone(source)
	for encounter in session.overworld.encounters:
		session.overworld.resolved_encounters.append(String(encounter.placement_id))
	var config: Dictionary = Turns._enemy_faction_configs_for_session(session)[0]
	var id := Players.controller_id(config)
	var state: Dictionary = Turns._find_state(session.overworld.enemy_states, id)
	state.pressure = 999
	var spawn: Dictionary = Turns._spawn_raid(session, config, state)
	var raid: Dictionary = Ai._find_encounter_by_placement(session, String(spawn.get("placement_id", ""))).get("encounter", {})
	var entry := Transit.point(gate.native_transit.entry)
	var exit := Transit.point(gate.native_transit.exit)
	# Move a real spawned commander beside a real gate, not an invented route.
	raid.merge({"x": approach.x, "y": approach.y, "level": entry.z}, true)
	Rules.normalize_overworld_state(session)
	var strategic := exercise_strategic_ai(session, gate, approach, raid, config, state)
	var plan: Dictionary = Ai._path_plan_toward(session, approach, [Vector2i(entry.x, entry.y)], String(raid.placement_id), id)
	raid.merge({"target_kind": "resource", "target_placement_id": String(gate.placement_id), "target_x": entry.x, "target_y": entry.y, "goal_x": entry.x, "goal_y": entry.y, "goal_distance": 1}, true)
	if target_exit_id != "":
		raid["native_transit_target_exit_id"] = target_exit_id
	var marching = clone(session)
	var marched: Dictionary = Ai.advance_raids(marching, config, id, state.duplicate(true), {"only_placement_ids": [String(raid.placement_id)]})
	var marched_raid: Dictionary = Ai._find_encounter_by_placement(marching, String(raid.placement_id)).get("encounter", {})
	raid.merge({"x": entry.x, "y": entry.y, "target_kind": "resource", "target_placement_id": String(gate.placement_id), "target_x": entry.x, "target_y": entry.y, "arrived": true}, true)
	Rules.invalidate_spatial_lookup(session)
	Rules._refresh_blocked_tile_index(session)
	var before_treasury: Dictionary = state.get("treasury", {}).duplicate(true)
	var before_node: Dictionary = Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node.duplicate(true)
	var result: Dictionary = Ai._resolve_arrived_target(session, raid, state, id, config)
	var updated: Dictionary = result.get("encounter", {})
	return {"exact_destination": result.has("native_transit") and Transit.point(updated) == exit, "unchanged_rewards": result.get("state", {}).get("treasury", {}) == before_treasury and Rules._find_resource_node_by_placement(session, String(gate.placement_id)).node == before_node, "path_reachable": int(plan.get("goal_distance", 9999)) == 1, "result": result, "plan": plan, "full_advance_used_gate": String(marched_raid.get("native_transit_last_exit_id", "")) == String(gate.native_transit.target_placement_id), "full_advance_raid": marched_raid, "full_advance": marched, "strategic": strategic}

func exercise_strategic_ai(source, gate: Dictionary, approach: Vector2i, source_raid: Dictionary, config: Dictionary, source_state: Dictionary) -> Dictionary:
	var session = clone(source)
	var raid: Dictionary = Ai._find_encounter_by_placement(session, String(source_raid.placement_id)).encounter
	var id := Players.controller_id(config)
	var context: Dictionary = Ai._path_distance_surface_context(session, String(raid.placement_id), id, Levels.level_of(raid))
	var exit := Transit.point(gate.native_transit.exit)
	var chosen := {}
	var chosen_kind := "resource"
	var plan := {}
	# Keep real package targets, coordinates and terrain. Select an actual
	# contestable objective whose shortest route starts through this endpoint.
	for node in session.overworld.resource_nodes:
		if Transit.is_native(node) or Levels.level_of(node) != exit.z:
			continue
		var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id", "")))
		if not Ai._resource_node_contestable_by_faction(node, site, id, session):
			continue
		var goal: Vector2i = Ai._resource_interaction_tile(node)
		var candidate: Dictionary = Ai._native_navigation_plan(context, approach, [goal], exit.z)
		var link: Dictionary = candidate.get("native_transit", {})
		if int(candidate.get("goal_distance", 9999)) > 1 and int(candidate.get("goal_distance", 9999)) < 9999 and String(link.get("source_placement_id", "")) == String(gate.placement_id) and String(link.get("target_placement_id", "")) == String(gate.native_transit.target_placement_id):
			chosen = node
			plan = candidate
			break
	if chosen.is_empty():
		for node in session.overworld.artifact_nodes:
			if bool(node.get("collected", false)) or Levels.level_of(node) != exit.z:
				continue
			var goal := Vector2i(int(node.x), int(node.y))
			var candidate: Dictionary = Ai._native_navigation_plan(context, approach, [goal], exit.z)
			var link: Dictionary = candidate.get("native_transit", {})
			if int(candidate.get("goal_distance", 9999)) > 1 and String(link.get("source_placement_id", "")) == String(gate.placement_id) and String(link.get("target_placement_id", "")) == String(gate.native_transit.target_placement_id):
				chosen = node
				chosen_kind = "artifact"
				plan = candidate
				break
	if chosen.is_empty():
		# A redundant gate need not be the optimal route to an existing reward.
		# Exercise a real, passable exploration goal beyond it instead; never
		# relocate content or force the planner to select a worse route.
		for delta in Ai.PATH_MOVEMENT_DELTAS:
			var goal := Vector2i(exit.x + delta.x, exit.y + delta.y)
			var candidate: Dictionary = Ai._native_navigation_plan(context, approach, [goal], exit.z)
			var link: Dictionary = candidate.get("native_transit", {})
			if int(candidate.get("goal_distance", 9999)) > 1 and String(link.get("source_placement_id", "")) == String(gate.placement_id) and String(link.get("target_placement_id", "")) == String(gate.native_transit.target_placement_id) and not Rules.tile_is_blocked(session, goal.x, goal.y, exit.z) and not Rules.tile_has_route_interaction(session, goal.x, goal.y, exit.z):
				chosen = {"placement_id": "explore:%d:%d:%d" % [goal.x, goal.y, exit.z], "x": goal.x, "y": goal.y, "level": exit.z}
				chosen_kind = "explore"
				plan = candidate
				break
	if chosen.is_empty():
		return {"ok": false, "error": "no_real_distal_object_or_exploration_target", "context_ok": bool(context.get("native_navigation", {}).get("ok", false)), "link_count": context.get("native_navigation", {}).get("links", []).size()}
	var goal: Vector2i = Ai._resource_interaction_tile(chosen)
	raid.merge({"target_kind": chosen_kind, "target_placement_id": String(chosen.placement_id), "target_x": goal.x, "target_y": goal.y, "goal_x": goal.x, "goal_y": goal.y, "goal_distance": int(plan.goal_distance)}, true)
	var valid: bool = Ai._raid_target_valid(session, raid)
	var refreshed: Dictionary = Ai._refresh_target(session, raid.duplicate(true), id)
	var save_id := "strategic_" + String(gate.placement_id)
	var saved: Dictionary = SaveService.save_runtime_file_session(session, save_id)
	var resumed = SaveService.restore_session_from_summary(SaveService.inspect_save_file(save_id))
	var resumed_raid: Dictionary = Ai._find_encounter_by_placement(resumed, String(raid.placement_id)).encounter if resumed != null else {}
	var saved_target: bool = bool(saved.get("ok", false)) and String(resumed_raid.get("target_placement_id", "")) == String(chosen.placement_id) and Levels.level_of(resumed_raid) == Levels.level_of(raid)
	var advanced: Dictionary = Ai.advance_raids(resumed, config, id, source_state.duplicate(true), {"only_placement_ids": [String(raid.placement_id)]}) if resumed != null else {}
	var moved: Dictionary = Ai._find_encounter_by_placement(resumed, String(raid.placement_id)).get("encounter", {}) if resumed != null else {}
	var used: bool = String(moved.get("native_transit_last_exit_id", "")) == String(gate.native_transit.target_placement_id)
	var at_entry := raid.duplicate(true)
	var entry := Transit.point(gate.native_transit.entry)
	at_entry.merge({"x": entry.x, "y": entry.y, "level": entry.z, "native_transit_target_exit_id": String(gate.native_transit.target_placement_id)}, true)
	var preserved: Dictionary = Ai._secure_native_passage_target(session, at_entry, source_state.duplicate(true), id, gate, true)
	var retains: bool = preserved.has("native_transit") and String(preserved.get("encounter", {}).get("target_placement_id", "")) == String(chosen.placement_id)
	return {"ok": valid and int(refreshed.get("goal_distance", 9999)) == int(plan.goal_distance) and saved_target and used and retains, "target_id": chosen.placement_id, "target_kind": chosen_kind, "target_level": Levels.level_of(chosen), "plan": plan, "valid": valid, "refreshed_distance": refreshed.get("goal_distance"), "save_keeps_target": saved_target, "advance_uses_selected_gate": used, "waypoint_retains_goal": retains, "moved_raid": moved, "advance": advanced}

func exercise_visual(source, gate: Dictionary, out: String) -> Dictionary:
	var session = clone(source)
	for encounter in session.overworld.encounters:
		session.overworld.resolved_encounters.append(String(encounter.placement_id))
	place(session, Transit.point(gate.native_transit.entry))
	session.overworld.view_level = Levels.hero_level(session)
	SessionState.active_session = session
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	var size := OS.get_environment("HEROES_TRANSIT_RESOLUTION").split("x")
	get_window().size = Vector2i(int(size[0]), int(size[1]))
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("transit_surface.png"))
	var checks := {"before_main_and_minimap_level": shell._map_view._level == 0 and shell._minimap.validation_snapshot().level == 0}
	shell._on_context_action_pressed("collect_resource")
	for frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("transit_underground.png"))
	checks["context_action_changes_main_and_minimap"] = shell._map_view._level == 1 and shell._minimap.validation_snapshot().level == 1 and shell._map_data == Levels.terrain_rows(session, 1)
	checks["hero_visible_at_actual_exit"] = shell._map_view._has_hero_at(Rules.hero_position(session)) and Transit.point(session.overworld.hero_position) == Transit.point(gate.native_transit.exit)
	checks["no_cross_layer_movement_animation"] = shell._hero_movement_presentation.is_empty()
	checks["resolution_matches"] = get_viewport().get_texture().get_image().get_size() == Vector2i(int(size[0]), int(size[1]))
	shell.queue_free()
	await get_tree().process_frame
	return checks
'''

GLOBAL_CHECKS = ("eight_reciprocal_gate_records", "native_gates_do_not_use_local_offsets", "legacy_exact_anchor_restore", "disk_package_roundtrip", "native_navigation_field_unit_edges", "cave_source_corner_runtime")
TRIP_CHECKS = (
    "travel_reaches_exact_peer", "context_travel_spends_one",
    "all_active_hero_positions_agree", "view_and_fog_follow_level",
    "no_claim_rewards_or_source_mutation", "session_roundtrip_preserves_destination",
    "repeatable_return_to_source", "can_leave_gate_body",
    "arrival_includes_travel_for_one_step", "zero_movement_cannot_return",
    "missing_peer_fails_validation",
    "production_save_preserves_transit_and_fog",
    "ai_routes_to_real_target_through_gate",
    "exit_body_blocks_without_spending", "exit_hero_blocks_without_spending",
    "exit_army_blocks_without_spending", "ai_uses_exact_native_destination",
    "ai_transit_preserves_treasury_and_node", "ai_gate_path_is_reachable",
    "full_ai_advance_uses_gate",
)


def failures(report):
    failed = []
    for check in GLOBAL_CHECKS:
        if report.get("checks", {}).get(check) is not True:
            failed.append(check)
    trips = report.get("trips", [])
    if len(trips) != 8:
        failed.append("missing_trip_evidence")
    if len({trip.get("placement_id") for trip in trips if trip.get("placement_id")}) != 8:
        failed.append("missing_unique_gate_evidence")
    for trip in trips:
        for check in TRIP_CHECKS:
            if trip.get("checks", {}).get(check) is not True:
                failed.append(f"{trip.get('placement_id')}: {check}")
    return failed


PORTAL_CASES = {
    "medium_seed10": (72, "medium", 10, 2, "land", 2),
    "large_seed1": (108, "large", 1, 2, "land", 50),
    "players_6": (72, "medium", 10, 6, "land", 9),
    "small_islands": (36, "small", 1, 2, "islands", 14),
    "large_profile": (108, "large", 1166246304, 4, "land", 24),
}


def portal_failures(report, expected_ends, representatives_only=False):
    failed = []

    if report.get("checks", {}).get("native_navigation_field_unit_edges") is not True:
        failed.append("native_navigation_field_unit_edges")
    if report.get("checks", {}).get("disk_package_roundtrip") is not True:
        failed.append("disk_package_roundtrip")
    portals = report.get("portals", {})
    for key in ("contract_errors", "legacy_errors"):
        if portals.get(key) != []:
            failed.append(key)
    ends = portals.get("ends", [])
    source_ends = {gate.get("placement_id"): gate for gate in report.get("gates", []) if gate.get("h3m_type_id") in (43, 44, 45)}
    if not representatives_only and (len(ends) != expected_ends or len({e.get("placement_id") for e in ends if e.get("placement_id")}) != expected_ends):
        failed.append("missing_unique_portal_evidence")
    if len(source_ends) != expected_ends or (not representatives_only and set(source_ends) != {e.get("placement_id") for e in ends}):
        failed.append("portal_source_identity_coverage")
    if representatives_only and portals.get("representatives_only") is not True:
        failed.append("representative_only_coverage_not_declared")
    for end in ends:
        required = ["legacy_exact_group_restore", "not_authored_local_offset"]
        trips = end.get("trips", [])
        expected_targets = {d.get("target_placement_id") for d in source_ends.get(end.get("placement_id"), {}).get("native_transit", {}).get("destinations", [])}
        actual_targets = [trip.get("target_placement_id") for trip in trips]
        if len(actual_targets) != len(expected_targets) or set(actual_targets) != expected_targets:
            failed.append(f"{end.get('placement_id')}: destination_coverage")
        required += ["missing_destination_fails_validation"] if trips else ["arrival_only_or_stranded_is_explicit", "inactive_portal_approach_is_a_successful_move"]
        if len(trips) > 1:
            required += ["multiple_destinations_require_explicit_choice", "every_exit_has_context_action"]
        for key in required:
            if end.get("checks", {}).get(key) is not True:
                failed.append(f"{end.get('placement_id')}: {key}")
        for trip in trips:
            keys = ["context_action_reaches_exact_exit", "one_movement_no_claim_or_reward", "save_roundtrip_keeps_position_group_and_fog", "occupied_exit_rejected_without_cost"]
            if len(trips) > 1:
                keys += ["paid_arrival_choice_survives_save_without_double_charge", "arrival_credit_does_not_grant_next_day_free_travel"]
            for key in keys:
                if trip.get("checks", {}).get(key) is not True:
                    failed.append(f"{end.get('placement_id')} -> {trip.get('target_placement_id')}: {key}")
    expected_shapes = {f"{int(gate['h3m_type_id'])}:{len(gate['native_transit'].get('destinations', []))}" for gate in source_ends.values() if gate.get("native_transit", {}).get("destinations")}
    if any(len(gate.get("native_transit", {}).get("destinations", [])) > 1 for gate in source_ends.values()) and portals.get("multihero_credit", {}).get("ok") is not True:
        failed.append("multihero_pending_credit_not_preserved")
    representatives = portals.get("representatives", [])
    if len(representatives) != len(expected_shapes) or {r.get("shape") for r in representatives} != expected_shapes:
        failed.append("missing_portal_shape_gameplay_evidence")
    for representative in representatives:
        for key in ("ai_exact_selected_destination", "ai_no_claim_rewards", "ai_real_approach_path", "ai_full_advance_uses_gate", "ai_routes_to_real_target_through_gate", "production_save_keeps_position_contracts_and_fog", "real_approach_then_saved_choice_spends_one_total"):
            if representative.get("checks", {}).get(key) is not True:
                failed.append(f"{representative.get('shape')}: {key}")
    return failed


def journey_failures(report, require_islands_chain=False):
    failed = [key for key in ("disk_package_roundtrip", "native_navigation_field_unit_edges") if report.get("checks", {}).get(key) is not True]
    if any(gate.get("h3m_type_id") == 103 for gate in report.get("gates", [])) and report.get("checks", {}).get("cave_source_corner_runtime") is not True:
        failed.append("cave_source_corner_runtime")
    evidence = report.get("journey", {})
    rows = evidence.get("journeys", [])
    towns = {obj.get("placement_id") for obj in report.get("objects", []) if obj.get("kind") == "town"}
    home = evidence.get("starting_town_id")
    actual = [row.get("town_id") for row in rows]
    if home not in towns or not rows or len(actual) != len(towns) - 1 or set(actual) != towns - {home}:
        failed.append("journey_source_town_coverage")
    if evidence.get("ok") is not True or any(row.get("ok") is not True or row.get("error") for row in rows):
        failed.append("continuous_town_journey")
    for row in rows:
        if not row.get("steps") or any(step.get("result", {}).get("ok") is not True or step.get("cost") != 1 for step in row.get("steps", [])):
            failed.append(f"{row.get('town_id')}: paid_live_steps")
    if require_islands_chain:
        if not any(len(row.get("passages", [])) >= 2 for row in rows) or not any(row.get("turns") for row in rows):
            failed.append("islands_multi_passage_and_turn_evidence")
        battles = [battle for row in rows for battle in row.get("battles", [])]
        if not battles or any(battle.get("completed") is not True or battle.get("state") != "victory" or battle.get("remote_towns_unchanged") is not True or battle.get("overworld_checkpoint") is not True for battle in battles):
            failed.append("islands_field_battle_preserves_remote_towns")
    return failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--legacy-session", type=Path)
    parser.add_argument("--baseline-case", type=Path, help="Retained start-audit case for exact source objects, terrain and payload comparison")
    parser.add_argument("--baseline-session", type=Path, help="Compare immutable source objects, terrain and native hash to a retained performance save")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--portal-case", choices=tuple(PORTAL_CASES))
    parser.add_argument("--representatives-only", action="store_true", help="Only portal-shape AI/real-approach/production-save checks, explicitly not every endpoint trip")
    parser.add_argument("--journey-only", action="store_true", help="Continuous post-guard walks from the actual starting town through turns, passages and production saves; not endpoint or battle coverage")
    parser.add_argument("--resolution", choices=("1280x720", "2048x1079"), default="1280x720")
    args = parser.parse_args()
    if args.journey_only and (args.render or args.representatives_only or args.legacy_session):
        parser.error("journey-only cannot claim endpoint, historical-save or rendered coverage")
    if args.representatives_only and not args.portal_case:
        parser.error("--representatives-only requires --portal-case")
    if args.baseline_case and args.baseline_session:
        parser.error("choose one native case or retained-session baseline")
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("label must be a safe path component")
    out = ROOT / ".artifacts/rmg_start_audit_20260905" / args.label
    out.mkdir(parents=True, exist_ok=False)
    config = {"seed": "68", "size": {"width": 36, "height": 36, "level_count": 2, "water_mode": "land", "size_class_id": "small"}, "monster_strength": "weak", "player_constraints": {"human_count": 1, "computer_count": 1, "player_count": 2, "human_team_count": 1, "computer_team_count": 0}}
    if args.portal_case:
        size, size_class, seed, players, water, expected_ends = PORTAL_CASES[args.portal_case]
        config["seed"] = str(seed)
        config["size"] = {"width": size, "height": size, "level_count": 1, "water_mode": water, "size_class_id": size_class}
        config["player_constraints"].update(computer_count=players-1, player_count=players)
        if args.portal_case == "large_profile":
            config["monster_strength"] = "random"
            config["player_setup"] = {"faction_id": "faction_veilmourn", "hero_id": "hero_veilmourn_orso_nightchart", "selection_mode": "player_selected"}
            config["profile"] = {"id": "", "template_id": "", "guard_strength_profile": "normal", "faction_ids": ["faction_veilmourn", "faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow"]}
    (out / "config.json").write_text(json.dumps(config, indent=2) + "\n")
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted((ROOT / "scripts").rglob("*.gd"))}
    for relative in ("scenes/overworld/OverworldShell.gd", "src/gdextension/include/h3maped_rmg_core.hpp", "src/gdextension/src/h3maped_rmg_core.cpp", "src/gdextension/src/map_package_service.cpp", "src/gdextension/src/h3maped_rmg_core_selftest.cpp", "bin/libaurelion_map_persistence.linux.template_debug.x86_64.so", "tools/rmg_native_transit_validation.py"):
        hashes[relative] = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="transit-adapter-", dir=out.parent) as temp:
        script = Path(temp) / "probe.gd"
        script.write_text(PROBE)
        scene = Path(temp) / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out / "data"), HEROES_TRANSIT_OUTPUT=str(out), HEROES_PROFILE_LOG="0", HEROES_TRANSIT_LEGACY=str(args.legacy_session.resolve()) if args.legacy_session else "", HEROES_TRANSIT_RENDER="1" if args.render else "0", HEROES_TRANSIT_RESOLUTION=args.resolution, HEROES_TRANSIT_PORTAL_CASE=args.portal_case or "", HEROES_TRANSIT_REPRESENTATIVES_ONLY="1" if args.representatives_only else "0")
        env["HEROES_TRANSIT_JOURNEY_ONLY"] = "1" if args.journey_only else "0"
        cmd = [shutil.which("godot4") or "godot", "--path", str(ROOT), "--accessibility", "disabled", "--audio-driver", "Dummy", "--resolution", args.resolution, "res://" + str(scene.relative_to(ROOT))]
        cmd = ["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24"] + cmd if args.render else cmd + ["--headless"]
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
    raw = json.loads((out / "runtime_report.json").read_text()) if (out / "runtime_report.json").exists() else {}
    errors = [line for line in (out / "runtime.log").read_text().splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    failed = portal_failures(raw, expected_ends, args.representatives_only) if args.portal_case else failures(raw)
    if args.journey_only:
        failed = journey_failures(raw, args.portal_case == "small_islands")
    source_changes = [relative for relative, digest in hashes.items()
                      if not (ROOT / relative).is_file() or hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() != digest]
    if source_changes:
        failed.append("source_changed_during_validation")
    controls = {}
    if args.baseline_case:
        previous = json.loads(args.baseline_case.read_text())
        current_objects = [{k: v for k, v in obj.items() if k != "native_transit"} for obj in raw.get("objects", [])]
        controls = {"source_objects_unchanged_except_transit_sidecar": current_objects == previous.get("objects"),
                    "terrain_unchanged": raw.get("terrain") == previous.get("terrain"),
                    "payload_hash_unchanged": raw.get("payload_fnv1a32") == previous.get("payload_fnv1a32"),
                    "payload_size_unchanged": raw.get("payload_bytes") == previous.get("payload_bytes")}
        failed.extend(key for key, value in controls.items() if not value)
        hashes["baseline_case:" + str(args.baseline_case)] = hashlib.sha256(args.baseline_case.read_bytes()).hexdigest()
    if args.baseline_session:
        previous = json.loads(args.baseline_session.read_text())
        overworld = previous.get("overworld", {})
        provenance = previous.get("flags", {}).get("generated_random_map_provenance", {})
        old_objects = overworld.get("package_source_objects_by_id", {})
        # The retained performance save predates the completed player/team
        # child. Its source rows lack those two additive ownership fields.
        # No faction, object id, placement, mask or source field is ignored.
        current_objects = {obj["placement_id"]: {k: v for k, v in obj.items() if k != "native_transit" and not (k in ("controlling_player_id", "team_id") and k not in old_objects.get(obj["placement_id"], {}))} for obj in raw.get("objects", [])}
        controls = {"source_objects_unchanged_except_identity_and_transit_sidecars": bool(old_objects) and current_objects == old_objects,
                    "terrain_unchanged": raw.get("terrain") == overworld.get("terrain_layers"),
                    "native_map_and_player_identity_unchanged": raw.get("native_map_hash") == provenance.get("map_ref", {}).get("map_hash")}
        failed.extend(key for key, value in controls.items() if not value)
        hashes["baseline_session:" + str(args.baseline_session)] = hashlib.sha256(args.baseline_session.read_bytes()).hexdigest()
    if args.render:
        visual_checks = ("context_action_exists", "controls_inside_viewport", "context_action_reaches_visible_exact_exit", "main_and_minimap_follow_destination", "no_teleport_walk_animation", "resolution_matches", "choice_dialog_has_all_exits_and_owns_input", "choice_cancel_does_not_move_or_spend", "choice_dialog_and_buttons_inside_viewport") if args.portal_case else ("before_main_and_minimap_level", "context_action_changes_main_and_minimap", "hero_visible_at_actual_exit", "no_cross_layer_movement_animation", "resolution_matches")
        for key in visual_checks:
            if raw.get("visual", {}).get(key) is not True:
                failed.append("visual: " + key)
    if args.legacy_session:
        hashes["historical_session:" + str(args.legacy_session)] = hashlib.sha256(args.legacy_session.read_bytes()).hexdigest()
        if raw.get("checks", {}).get("historical_save_reconstructs_eight_ends") is not True:
            failed.append("historical_save_reconstructs_eight_ends")
    report = {"ok": run.returncode == 0 and raw.get("generation_ok") is True and not errors and not failed, "returncode": run.returncode, "failures": failed, "runtime_errors": errors, "runtime_source_sha256": hashes, "source_changes_during_run": source_changes, "native_controls": controls, "runtime": raw}
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"ok": report["ok"], "failures": failed, "errors": errors, "output": str(out)}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
