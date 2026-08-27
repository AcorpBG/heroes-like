extends Node

const REPORT_ID := "AI_KNOWN_WORLD_MEMORY_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var preservation_case := _known_world_memory_survives_normalization()
	if preservation_case.is_empty():
		return
	var objective_anchor_case := _objective_anchor_catalog_reuse_parity()
	if objective_anchor_case.is_empty():
		return
	var catalog_projection_case := _known_world_target_catalog_projection_parity()
	if catalog_projection_case.is_empty():
		return
	var sighting_case := _hero_targets_require_ai_sighting()
	if sighting_case.is_empty():
		return
	var empty_fallback_case := _empty_target_fallback_does_not_hunt_hidden_hero()
	if empty_fallback_case.is_empty():
		return
	var nonhero_case := _nonhero_targets_require_visibility_or_memory()
	if nonhero_case.is_empty():
		return
	var delivery_case := _convoy_interception_requires_known_route_and_hero()
	if delivery_case.is_empty():
		return
	var ordinary_scouting_case := _ordinary_scouting_records_nonhero_memory()
	if ordinary_scouting_case.is_empty():
		return
	var neutral_town_case := _neutral_towns_require_visibility_or_memory()
	if neutral_town_case.is_empty():
		return
	var persistent_exploration_case := _persistent_exploration_tasks_launch_and_complete()
	if persistent_exploration_case.is_empty():
		return
	var exclusive_frontier_case := _exclusive_frontier_reservations_diversify_live_hosts()
	if exclusive_frontier_case.is_empty():
		return
	var rebuild_relaunch_case := _rebuild_relaunch_preserves_frontier_history()
	if rebuild_relaunch_case.is_empty():
		return
	var exploration_case := _exploration_arrival_reassigns_visible_resource()
	if exploration_case.is_empty():
		return
	var post_move_scouting_case := _moving_exploration_refreshes_memory_before_same_turn_retarget()
	if post_move_scouting_case.is_empty():
		return
	var hero_route_occupancy_case := _nonhero_route_avoids_player_hero_occupied_tile()
	if hero_route_occupancy_case.is_empty():
		return
	var faction_scoped_route_case := _hero_route_occupancy_uses_moving_faction_sight()
	if faction_scoped_route_case.is_empty():
		return
	var assignment_route_case := _target_assignment_respects_faction_scoped_route_occupancy()
	if assignment_route_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "strategic_ai_known_world_memory_live_behavior",
		"behavior_policy": "enemy_pressure_uses_current_or_recent_ai_sightings_known_world_memory_post_move_scouting_and_faction_scoped_player_hero_route_occupancy_for_movement_and_assignment",
		"save_policy": "known_world_memory_live_persist_no_save_migration",
		"cases": [preservation_case, objective_anchor_case, catalog_projection_case, sighting_case, empty_fallback_case, nonhero_case, delivery_case, ordinary_scouting_case, neutral_town_case, persistent_exploration_case, exclusive_frontier_case, rebuild_relaunch_case, exploration_case, post_move_scouting_case, hero_route_occupancy_case, faction_scoped_route_case, assignment_route_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _known_world_memory_survives_normalization() -> Dictionary:
	var session = _base_session()
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [
				{
					"hero_id": "hero_lyra",
					"hero_label": "Lyra",
					"x": 0,
					"y": 4,
					"army_strength": 96,
					"seen_day": int(session.day),
					"expires_day": int(session.day) + 2,
					"source_kind": "town",
					"source_id": "duskfen_bastion",
				}
			],
		}
	)
	EnemyTurnRules.normalize_enemy_states(session)
	var memory := _enemy_memory(session)
	var scouted: Array = memory.get("scouted_targets", []) if memory.get("scouted_targets", []) is Array else []
	var sightings: Array = memory.get("player_hero_sightings", []) if memory.get("player_hero_sightings", []) is Array else []
	if scouted.is_empty() or sightings.is_empty():
		_fail("Enemy state normalization dropped known_world_memory: %s" % JSON.stringify(memory))
		return {}
	return {
		"case_id": "known_world_memory_survives_normalization",
		"scouted_target_count": scouted.size(),
		"hero_sighting_count": sightings.size(),
		"hero_sighting_position": {"x": int(sightings[0].get("x", -1)), "y": int(sightings[0].get("y", -1))},
	}

func _objective_anchor_catalog_reuse_parity() -> Dictionary:
	var session = _base_session()
	var authority_before: Dictionary = session.to_dict()
	var legacy_surface := _legacy_objective_anchor_surface_control(session)
	var current_surface: Dictionary = EnemyAdventureRules._objective_anchor_surface(session)
	if current_surface != legacy_surface:
		_fail("Objective-anchor surface differs from the independent legacy control: current=%s control=%s" % [JSON.stringify(current_surface), JSON.stringify(legacy_surface)])
		return {}
	var anchor_tiles: Array = current_surface.get("tiles", []) if current_surface.get("tiles", []) is Array else []
	if anchor_tiles.is_empty():
		_fail("Objective-anchor fixture did not produce a live anchor tile.")
		return {}
	var probe_tiles := [anchor_tiles[0], Vector2i(anchor_tiles[0].x + 1, anchor_tiles[0].y), Vector2i(anchor_tiles[0].x + 3, anchor_tiles[0].y), Vector2i(anchor_tiles[0].x + 5, anchor_tiles[0].y), Vector2i(anchor_tiles[0].x + 6, anchor_tiles[0].y)]
	for probe_value in probe_tiles:
		var probe: Vector2i = probe_value
		var direct_bonus := _legacy_objective_proximity_bonus_control(session, probe.x, probe.y)
		var preloaded_bonus := EnemyAdventureRules._objective_proximity_bonus_from_tiles(anchor_tiles, probe.x, probe.y)
		if preloaded_bonus != direct_bonus:
			_fail("Preloaded objective proximity differs at %s: current=%s control=%s" % [probe, preloaded_bonus, direct_bonus])
			return {}
	for artifact_value in session.overworld.get("artifact_nodes", []):
		if not (artifact_value is Dictionary) or bool(artifact_value.get("collected", false)):
			continue
		if EnemyAdventureRules._artifact_target_priority(session, artifact_value, anchor_tiles) != EnemyAdventureRules._artifact_target_priority(session, artifact_value):
			_fail("Preloaded artifact priority differs from the direct legacy helper.")
			return {}
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		if EnemyAdventureRules._encounter_target_priority(session, encounter_value, anchor_tiles, current_surface) != EnemyAdventureRules._encounter_target_priority(session, encounter_value):
			_fail("Preloaded encounter priority differs from the direct legacy helper.")
			return {}
	var raw_surface: Dictionary = EnemyAdventureRules._objective_anchor_surface(session)
	var raw_town_ids: Array = raw_surface.get("town_placement_ids", [])
	var raw_tiles: Array = raw_surface.get("tiles", [])
	if raw_town_ids.is_empty() or raw_tiles.is_empty():
		_fail("Raw objective-anchor surface is not fail-closed nonempty for detach proof.")
		return {}
	raw_town_ids[0] = "mutated_detached_town"
	raw_tiles[0] = Vector2i(99, 99)
	if session.to_dict() != authority_before or EnemyAdventureRules._objective_anchor_surface(session) != legacy_surface:
		_fail("Detached objective-anchor surface mutation aliased the session or next invocation.")
		return {}
	var moved_town_id := String(legacy_surface.get("town_placement_ids", [])[0])
	var towns: Array = session.overworld.get("towns", [])
	var moved := false
	for index in range(towns.size()):
		if not (towns[index] is Dictionary) or String(towns[index].get("placement_id", "")) != moved_town_id:
			continue
		var town: Dictionary = towns[index]
		town["x"] = int(town.get("x", 0)) + 1
		towns[index] = town
		moved = true
		break
	if not moved:
		_fail("Objective-anchor fixture could not move its live town anchor.")
		return {}
	session.overworld["towns"] = towns
	var moved_control := _legacy_objective_anchor_surface_control(session)
	var moved_current: Dictionary = EnemyAdventureRules._objective_anchor_surface(session)
	if moved_current != moved_control or moved_current == legacy_surface:
		_fail("Objective-anchor surface did not rebuild exactly after live movement.")
		return {}
	var duplicate_scenario := {
		"objectives": {
			"victory": [
				{"type": "town_owned_by_player", "placement_id": moved_town_id},
				{"type": "town_not_owned_by_player", "placement_id": moved_town_id},
			],
			"defeat": [{"type": "town_owned_by_player", "placement_id": moved_town_id}],
		}
	}
	var duplicate_surface: Dictionary = EnemyAdventureRules._objective_anchor_surface(session, duplicate_scenario)
	if duplicate_surface.get("town_placement_ids", []) != [moved_town_id] or duplicate_surface.get("tiles", []).size() != 1:
		_fail("Objective-anchor duplicate objectives changed first-seen unique semantics: %s" % JSON.stringify(duplicate_surface))
		return {}
	var no_anchor_surface: Dictionary = EnemyAdventureRules._objective_anchor_surface(session, {"objectives": {"victory": [], "defeat": []}})
	if not no_anchor_surface.get("town_placement_ids", []).is_empty() or not no_anchor_surface.get("flag_ids", []).is_empty() or not no_anchor_surface.get("tiles", []).is_empty():
		_fail("No-objective scenario produced objective anchors: %s" % JSON.stringify(no_anchor_surface))
		return {}
	return {
		"case_id": "objective_anchor_catalog_reuse_parity",
		"town_anchor_count": legacy_surface.get("town_placement_ids", []).size(),
		"flag_anchor_count": legacy_surface.get("flag_ids", []).size(),
		"tile_count": anchor_tiles.size(),
		"proximity_bands_exact": true,
		"artifact_priority_exact": true,
		"encounter_priority_exact": true,
		"detach_exact": true,
		"movement_rebuild_exact": true,
		"duplicate_first_seen_exact": true,
		"no_anchor_exact": true,
	}

func _known_world_target_catalog_projection_parity() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_configure_known_world_catalog_fixture(session)
	var save_version_before := int(SessionStateStore.SAVE_VERSION)
	var initial_authority := _known_world_nonmemory_authority(session)
	var initial_control := _legacy_known_world_projection_control(session, config, MIRECLAW)
	var initial_current := _current_known_world_projection_snapshot(session, config, MIRECLAW)
	if initial_current != initial_control:
		_fail("Known-world catalog/projection differs from the independent legacy control at initial refresh: current=%s control=%s" % [JSON.stringify(initial_current), JSON.stringify(initial_control)])
		return {}
	var expected_source_ids := [
		"catalog_enemy_town_a",
		"catalog_enemy_town_b",
		"catalog_commander_source",
		"catalog_resource_source",
	]
	var expected_catalog_keys := [
		"town:catalog_player_town",
		"town:catalog_neutral_town",
		"resource:catalog_resource_target",
		"artifact:catalog_artifact_target",
		"encounter:catalog_encounter_target",
	]
	if _known_world_source_ids(initial_current.get("sources", [])) != expected_source_ids:
		_fail("Known-world sight source order changed: %s" % JSON.stringify(initial_current.get("sources", [])))
		return {}
	if _known_world_catalog_keys(initial_current.get("catalog", [])) != expected_catalog_keys:
		_fail("Known-world target catalog family/order changed: %s" % JSON.stringify(initial_current.get("catalog", [])))
		return {}
	var excluded_catalog_keys := [
		"town:catalog_inactive_town",
		"resource:catalog_resource_source",
		"resource:catalog_resource_collected",
		"artifact:catalog_artifact_collected",
		"encounter:catalog_commander_source",
		"encounter:catalog_encounter_resolved",
	]
	for excluded_key in excluded_catalog_keys:
		if excluded_key in _known_world_catalog_keys(initial_current.get("catalog", [])):
			_fail("Known-world catalog admitted an excluded inactive/controlled/collected/pressure/resolved target: %s" % excluded_key)
			return {}
	if _known_world_record_source(initial_current.get("hero_records", []), "hero_lyra") != "catalog_enemy_town_a":
		_fail("Equal-distance hero source tie no longer preserves the first source.")
		return {}
	if _known_world_record_source(initial_current.get("target_records", []), "catalog_player_town") != "catalog_enemy_town_a":
		_fail("Equal-distance/equal-priority target tie no longer preserves the first source.")
		return {}
	if not _known_world_target_source_tie_exact(initial_current.get("visible_by_source", []), "catalog_player_town"):
		_fail("Known-world overlap fixture did not establish the exact equal-distance/equal-priority source tie.")
		return {}

	var fixture_authority_before_detach: Dictionary = session.to_dict()
	var raw_detached_sources: Array = EnemyAdventureRules._enemy_hero_sighting_sources(session, config, MIRECLAW)
	var raw_detached_catalog: Array = EnemyAdventureRules._enemy_visible_target_catalog(session, config, MIRECLAW)
	if raw_detached_sources.is_empty() or raw_detached_sources != initial_control.get("sources", []):
		_fail("Raw known-world source detach surface was empty or differed from the independent control.")
		return {}
	if raw_detached_catalog.is_empty() or raw_detached_catalog != initial_control.get("catalog", []):
		_fail("Raw known-world catalog detach surface was empty or differed from the independent control.")
		return {}
	raw_detached_sources[0]["x"] = 99
	raw_detached_sources[0]["radius"] = 0
	raw_detached_catalog[0]["target_label"] = "mutated detached catalog"
	raw_detached_catalog[0]["target_tile"] = Vector2i(99, 99)
	if session.to_dict() != fixture_authority_before_detach:
		_fail("Detached known-world source/catalog mutation aliased the live session.")
		return {}
	if _current_known_world_projection_snapshot(session, config, MIRECLAW) != initial_control:
		_fail("Known-world source/catalog mutation leaked into a fresh invocation.")
		return {}

	var expected_memory := _legacy_known_world_expected_memory_control(
		{},
		initial_control.get("hero_records", []),
		initial_control.get("target_records", []),
		int(session.day)
	)
	var initial_refresh := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	if not _known_world_refresh_exact(session, initial_refresh, expected_memory, initial_authority, initial_control):
		return {}

	_move_known_world_catalog_fixture(session)
	var moved_authority := _known_world_nonmemory_authority(session)
	var moved_control := _legacy_known_world_projection_control(session, config, MIRECLAW)
	var moved_current := _current_known_world_projection_snapshot(session, config, MIRECLAW)
	if moved_current != moved_control or moved_current == initial_control:
		_fail("Known-world live source/target movement did not rebuild the exact independent projection: current=%s control=%s" % [JSON.stringify(moved_current), JSON.stringify(moved_control)])
		return {}
	expected_memory = _legacy_known_world_expected_memory_control(
		expected_memory,
		moved_control.get("hero_records", []),
		moved_control.get("target_records", []),
		int(session.day)
	)
	var moved_refresh := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	if not _known_world_refresh_exact(session, moved_refresh, expected_memory, moved_authority, moved_control):
		return {}

	_remove_known_world_catalog_fixture_entries(session)
	var removed_authority := _known_world_nonmemory_authority(session)
	var removed_control := _legacy_known_world_projection_control(session, config, MIRECLAW)
	var removed_current := _current_known_world_projection_snapshot(session, config, MIRECLAW)
	if removed_current != removed_control:
		_fail("Known-world source/catalog removal differs from the independent control: current=%s control=%s" % [JSON.stringify(removed_current), JSON.stringify(removed_control)])
		return {}
	if "catalog_enemy_town_a" in _known_world_source_ids(removed_current.get("sources", [])) or "town:catalog_neutral_town" in _known_world_catalog_keys(removed_current.get("catalog", [])):
		_fail("Known-world removed source/catalog entries survived the next invocation.")
		return {}
	expected_memory = _legacy_known_world_expected_memory_control(
		expected_memory,
		removed_control.get("hero_records", []),
		removed_control.get("target_records", []),
		int(session.day)
	)
	var removed_refresh := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	if not _known_world_refresh_exact(session, removed_refresh, expected_memory, removed_authority, removed_control):
		return {}

	_disable_known_world_catalog_sources(session)
	session.day = int(session.day) + 8
	var expiry_authority := _known_world_nonmemory_authority(session)
	var expiry_control := _legacy_known_world_projection_control(session, config, MIRECLAW)
	expected_memory = _legacy_known_world_expected_memory_control(
		expected_memory,
		expiry_control.get("hero_records", []),
		expiry_control.get("target_records", []),
		int(session.day)
	)
	var expiry_refresh := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	if not expected_memory.is_empty() or not _known_world_refresh_exact(session, expiry_refresh, expected_memory, expiry_authority, expiry_control):
		if not expected_memory.is_empty():
			_fail("Known-world independent expiry control retained stale records: %s" % JSON.stringify(expected_memory))
		return {}
	if int(SessionStateStore.SAVE_VERSION) != save_version_before:
		_fail("Known-world catalog/projection reuse changed the save version.")
		return {}
	return {
		"case_id": "known_world_target_catalog_projection_parity",
		"source_order": expected_source_ids,
		"catalog_order": expected_catalog_keys,
		"excluded_catalog_keys": excluded_catalog_keys,
		"initial_profile": initial_refresh.get("target_catalog_profile", {}).duplicate(true),
		"moved_profile": moved_refresh.get("target_catalog_profile", {}).duplicate(true),
		"removed_profile": removed_refresh.get("target_catalog_profile", {}).duplicate(true),
		"expiry_profile": expiry_refresh.get("target_catalog_profile", {}).duplicate(true),
		"deep_detach_exact": true,
		"movement_rebuild_exact": true,
		"removal_rebuild_exact": true,
		"day_expiry_exact": true,
		"enemy_state_authority_exact": true,
		"save_version_exact": true,
	}

func _hero_targets_require_ai_sighting() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 4)
	var hidden_candidates: Array = _hero_target_candidates_for_origin(session, Vector2i(7, 2), config)
	if not hidden_candidates.is_empty():
		_fail("Hidden player hero should not become a hero target without AI sighting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	_set_primary_hero_position(session, 5, 2)
	var memory_result := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	_update_enemy_state(session, memory_result.get("state", _enemy_state(session)))
	var visible_candidates: Array = _hero_target_candidates_for_origin(session, Vector2i(7, 2), config)
	if visible_candidates.is_empty():
		_fail("Currently sighted player hero did not become eligible for hero pressure.")
		return {}
	_set_primary_hero_position(session, 0, 4)
	var remembered_candidates: Array = _hero_target_candidates_for_origin(session, Vector2i(7, 2), config)
	if remembered_candidates.is_empty():
		_fail("Recent remembered player hero sighting did not remain eligible for hero pressure.")
		return {}
	var remembered: Dictionary = remembered_candidates[0]
	if int(remembered.get("target_x", -1)) != 5 or int(remembered.get("target_y", -1)) != 2:
		_fail("Remembered hero target used live hidden position instead of remembered sighting: %s" % JSON.stringify(remembered))
		return {}
	return {
		"case_id": "hero_targets_require_ai_sighting",
		"hidden_candidate_count": hidden_candidates.size(),
		"visible_candidate_count": visible_candidates.size(),
		"remembered_target": {
			"target_id": String(remembered.get("target_placement_id", "")),
			"x": int(remembered.get("target_x", -1)),
			"y": int(remembered.get("target_y", -1)),
		},
		"sighting_count": int(memory_result.get("sighting_count", 0)),
	}

func _hero_target_candidates_for_origin(session, origin_pos: Vector2i, config: Dictionary) -> Array:
	var hero_candidates: Array = []
	var candidates: Array = EnemyAdventureRules._target_candidates(session, config, origin_pos, false)
	for candidate in candidates:
		if not (candidate is Dictionary) or String(candidate.get("target_kind", "")) != "hero":
			continue
		hero_candidates.append(candidate.duplicate(true))
	return hero_candidates

func _empty_target_fallback_does_not_hunt_hidden_hero() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var origin := {"x": 7, "y": 2}
	var chosen := EnemyAdventureRules.choose_target(session, config, origin, {})
	if chosen.is_empty():
		_fail("No-candidate target fallback should produce an exploration or regroup plan.")
		return {}
	if String(chosen.get("target_kind", "")) == "hero":
		_fail("No-candidate target fallback used hidden active hero coordinates: %s" % JSON.stringify(chosen))
		return {}
	if String(chosen.get("target_kind", "")) != "explore":
		_fail("No-candidate target fallback should scout reachable frontier before passive regroup, got %s" % JSON.stringify(chosen))
		return {}
	if "no_known_targets" not in _normalize_string_array(chosen.get("target_reason_codes", [])):
		_fail("No-candidate exploration fallback did not explain no_known_targets: %s" % JSON.stringify(chosen))
		return {}
	var state := _enemy_state(session)
	state["pressure"] = 999
	_update_enemy_state(session, state)
	if not EnemyTurnRules._can_launch_raid(session, config, state, MIRECLAW):
		_fail("Fresh pressure should launch an exploration commander when no legitimate target candidates exist.")
		return {}
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var exploration_raid := _first_enemy_raid_for_kind(session, "explore")
	if exploration_raid.is_empty():
		_fail("Live enemy turn did not dispatch an exploration raid with no known targets: %s" % JSON.stringify(turn_result))
		return {}
	return {
		"case_id": "empty_target_fallback_does_not_hunt_hidden_hero",
		"fallback_target_kind": String(chosen.get("target_kind", "")),
		"fallback_target_id": String(chosen.get("target_placement_id", "")),
		"fallback_goal_distance": int(chosen.get("goal_distance", -1)),
		"pressure_launch_allowed_without_target": true,
		"live_exploration_raid_id": String(exploration_raid.get("placement_id", "")),
	}

func _nonhero_targets_require_visibility_or_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_resource_target_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "resource", "river_free_company"):
		_fail("Hidden resource should not be targetable before current visibility or scouting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	var scoutable := EnemyAdventureRules._scoutable_target_candidates(session, config, MIRECLAW, origin, 20)
	if not _candidate_has_target(scoutable, "resource", "river_free_company"):
		_fail("Scouting discovery path should still see unknown nearby resources: %s" % JSON.stringify(scoutable))
		return {}
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(known_candidates, "resource", "river_free_company"):
		_fail("Scouted resource memory did not make resource targetable: %s" % JSON.stringify(known_candidates))
		return {}
	return {
		"case_id": "nonhero_targets_require_visibility_or_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scoutable_unknown_resource": true,
		"known_resource_candidate": true,
		"known_world_target_id": "river_free_company",
	}

func _convoy_interception_requires_known_route_and_hero() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	var hero_id := String(session.overworld.get("active_hero_id", "hero_lyra"))
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_hero_delivery_session(session, hero_id)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _first_delivery_candidate(hidden_candidates, "hero", hero_id).is_empty():
		_fail("Hidden convoy route should not be targetable before route source memory: %s" % JSON.stringify(hidden_candidates))
		return {}

	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [],
		}
	)
	var source_only_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _first_delivery_candidate(source_only_candidates, "hero", hero_id).is_empty():
		_fail("Known convoy source should not reveal a hidden hero endpoint: %s" % JSON.stringify(source_only_candidates))
		return {}

	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [
				{
					"hero_id": hero_id,
					"hero_label": "Lyra",
					"x": 5,
					"y": 2,
					"army_strength": 96,
					"seen_day": int(session.day),
					"expires_day": int(session.day) + 2,
					"source_kind": "town",
					"source_id": "duskfen_bastion",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	var delivery_candidate := _first_delivery_candidate(known_candidates, "hero", hero_id)
	if delivery_candidate.is_empty():
		_fail("Known convoy source plus remembered hero endpoint did not create delivery interception: %s" % JSON.stringify(known_candidates))
		return {}
	if int(delivery_candidate.get("target_x", -1)) != 5 or int(delivery_candidate.get("target_y", -1)) != 2:
		_fail("Hero-bound convoy interception used live hidden position instead of remembered hero sighting: %s" % JSON.stringify(delivery_candidate))
		return {}
	return {
		"case_id": "convoy_interception_requires_known_route_and_hero",
		"hidden_delivery_candidate": false,
		"source_only_delivery_candidate": false,
		"known_delivery_target": {
			"target_kind": String(delivery_candidate.get("target_kind", "")),
			"target_id": String(delivery_candidate.get("target_placement_id", "")),
			"x": int(delivery_candidate.get("target_x", -1)),
			"y": int(delivery_candidate.get("target_y", -1)),
		},
	}

func _ordinary_scouting_records_nonhero_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_resource_target_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "resource", "river_free_company"):
		_fail("Hidden resource should not be targetable before ordinary scout sight: %s" % JSON.stringify(hidden_candidates))
		return {}
	_add_exploration_raid(session, 0, 4)
	var memory_result := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	_update_enemy_state(session, memory_result.get("state", _enemy_state(session)))
	var record := _memory_target_record(session, "resource", "river_free_company")
	if record.is_empty():
		_fail("Ordinary commander sight did not record visible resource target memory: %s" % JSON.stringify(_enemy_memory(session)))
		return {}
	if String(record.get("source_kind", "")) != "commander":
		_fail("Ordinary scout record should preserve commander source kind: %s" % JSON.stringify(record))
		return {}
	if String(record.get("source_spell_id", "")) != "":
		_fail("Ordinary scout record should not masquerade as spell scouting: %s" % JSON.stringify(record))
		return {}
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	var remembered_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(remembered_candidates, "resource", "river_free_company"):
		_fail("Ordinary scout memory did not keep the resource targetable after the scout moved away: %s" % JSON.stringify(remembered_candidates))
		return {}
	return {
		"case_id": "ordinary_scouting_records_nonhero_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scouted_target_count": int(memory_result.get("scouted_target_count", 0)),
		"source_kind": String(record.get("source_kind", "")),
		"source_id": String(record.get("source_id", "")),
		"remembered_resource_candidate": true,
	}

func _neutral_towns_require_visibility_or_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_neutral_town_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "town", "hidden_neutral_hold"):
		_fail("Hidden neutral town should not be targetable before current visibility or scouting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	var scoutable := EnemyAdventureRules._scoutable_target_candidates(session, config, MIRECLAW, origin, 20)
	if not _candidate_has_target(scoutable, "town", "hidden_neutral_hold"):
		_fail("Scouting discovery path should still see unknown neutral towns: %s" % JSON.stringify(scoutable))
		return {}
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "town",
					"target_id": "hidden_neutral_hold",
					"target_label": "Hidden Neutral Hold",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(known_candidates, "town", "hidden_neutral_hold"):
		_fail("Scouted neutral-town memory did not make the town targetable: %s" % JSON.stringify(known_candidates))
		return {}
	return {
		"case_id": "neutral_towns_require_visibility_or_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scoutable_unknown_neutral_town": true,
		"known_neutral_town_candidate": true,
		"known_world_target_id": "hidden_neutral_hold",
	}

func _persistent_exploration_tasks_launch_and_complete() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var state := _enemy_state(session)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	_update_enemy_state(session, plan_result.get("state", _enemy_state(session)))
	var scout_task := _first_task_for_kind(session, "explore")
	if scout_task.is_empty():
		_fail("No-known-target strategic planner should create a persistent exploration task: %s" % JSON.stringify(plan_result))
		return {}
	if String(scout_task.get("task_class", "")) != "scout_frontier":
		_fail("Exploration task should use scout_frontier class: %s" % JSON.stringify(scout_task))
		return {}
	var task_target_id := String(scout_task.get("target_id", ""))
	state = _enemy_state(session)
	state["pressure"] = 999
	_update_enemy_state(session, state)
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var exploration_raid := _first_enemy_raid_for_kind(session, "explore")
	if exploration_raid.is_empty():
		_fail("Saved exploration task did not launch an exploration raid: %s" % JSON.stringify(turn_result))
		return {}
	var launched_task := _first_task_for_target(session, "explore", String(exploration_raid.get("target_placement_id", "")))
	if launched_task.is_empty() or String(launched_task.get("task_class", "")) != "scout_frontier":
		_fail("Exploration raid did not launch from a saved scout task: planned=%s raid=%s" % [JSON.stringify(_task_state(session)), JSON.stringify(exploration_raid)])
		return {}
	task_target_id = String(exploration_raid.get("target_placement_id", ""))
	var target_tile := _explore_target_tile(task_target_id)
	if target_tile.is_empty():
		_fail("Exploration task target id did not encode a tile: %s" % task_target_id)
		return {}
	if int(exploration_raid.get("target_x", -1)) != int(target_tile.get("x", -2)) or int(exploration_raid.get("target_y", -1)) != int(target_tile.get("y", -2)):
		_fail("Exploration raid lost saved target coordinates during spawn: %s" % JSON.stringify(exploration_raid))
		return {}
	_move_raid_to_target(session, String(exploration_raid.get("placement_id", "")), int(target_tile.get("x", 0)), int(target_tile.get("y", 0)))
	var arrival_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, arrival_result.get("state", _enemy_state(session)))
	var completed_task := _task_by_id(session, String(launched_task.get("task_id", "")))
	if String(completed_task.get("task_status", "")) != "completed":
		_fail("Exploration arrival did not complete the saved scout task: %s" % JSON.stringify(completed_task))
		return {}
	var reservation: Dictionary = completed_task.get("reservation", {}) if completed_task.get("reservation", {}) is Dictionary else {}
	if String(reservation.get("reservation_status", "")) != "released":
		_fail("Completed exploration task did not release its reservation: %s" % JSON.stringify(completed_task))
		return {}
	var continued_raid := _encounter_by_id(session, String(exploration_raid.get("placement_id", "")))
	if continued_raid.is_empty():
		_fail("Exploration commander disappeared after completing an empty scout tile: %s" % JSON.stringify(session.overworld.get("encounters", [])))
		return {}
	if String(continued_raid.get("target_kind", "")) == "explore" and String(continued_raid.get("target_placement_id", "")) == task_target_id:
		_fail("Exploration commander stayed on the completed scout tile instead of continuing: %s" % JSON.stringify(continued_raid))
		return {}
	var recent_exploration_target_ids: Array = continued_raid.get("recent_exploration_target_ids", []) if continued_raid.get("recent_exploration_target_ids", []) is Array else []
	if task_target_id not in recent_exploration_target_ids:
		_fail("Exploration host did not retain its completed frontier target: %s" % JSON.stringify(continued_raid))
		return {}

	var planner_session = _base_session()
	_set_primary_hero_position(planner_session, 0, 12)
	_make_no_known_targets_session(planner_session)
	var planner_origin := Vector2i(7, 2)
	var first_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(planner_session, config, planner_origin)
	var first_plan_id := String(first_plan.get("target_placement_id", ""))
	var second_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(
		planner_session,
		config,
		planner_origin,
		{"recent_exploration_target_ids": [first_plan_id]}
	)
	var second_plan_id := String(second_plan.get("target_placement_id", ""))
	if first_plan.is_empty() or second_plan.is_empty() or second_plan_id == first_plan_id:
		_fail("Frontier planner did not advance beyond its most recent completed target: first=%s second=%s" % [JSON.stringify(first_plan), JSON.stringify(second_plan)])
		return {}
	var third_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(
		planner_session,
		config,
		planner_origin,
		{"recent_exploration_target_ids": [first_plan_id, second_plan_id]}
	)
	var third_plan_id := String(third_plan.get("target_placement_id", ""))
	if not third_plan.is_empty() and third_plan_id in [first_plan_id, second_plan_id]:
		_fail("Frontier planner alternated back to a completed target: first=%s second=%s third=%s" % [first_plan_id, second_plan_id, third_plan_id])
		return {}
	return {
		"case_id": "persistent_exploration_tasks_launch_and_complete",
		"planned_count": int(plan_result.get("planned_count", 0)),
		"task_class": String(launched_task.get("task_class", "")),
		"task_target_id": task_target_id,
		"spawned_raid_id": String(exploration_raid.get("placement_id", "")),
		"spawned_target_x": int(exploration_raid.get("target_x", -1)),
		"spawned_target_y": int(exploration_raid.get("target_y", -1)),
		"completed_task_status": String(completed_task.get("task_status", "")),
		"continued_target_id": String(continued_raid.get("target_placement_id", "")),
		"recent_exploration_target_ids": recent_exploration_target_ids,
		"planner_target_sequence": [first_plan_id, second_plan_id, third_plan_id],
		"event_types": _event_types(arrival_result.get("events", [])),
	}

func _exclusive_frontier_reservations_diversify_live_hosts() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var first_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(session, config, Vector2i(7, 2))
	if first_plan.is_empty():
		_fail("Exclusive frontier fixture could not produce its first reachable target.")
		return {}
	var first_raid := _frontier_reservation_raid(session, "frontier_reservation_host_1", "hero_vaska", 7, 2, first_plan)
	var second_raid := _frontier_reservation_raid(session, "frontier_reservation_host_2", "hero_zhorra", 8, 2, {})
	session.overworld["encounters"] = [first_raid, second_raid]
	var same_origin_frontier_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(
		session,
		config,
		Vector2i(7, 2),
		second_raid
	)
	if same_origin_frontier_plan.is_empty() or String(same_origin_frontier_plan.get("target_placement_id", "")) == String(first_plan.get("target_placement_id", "")):
		_fail("Frontier fallback reused another live host's exclusive target: first=%s second=%s" % [JSON.stringify(first_plan), JSON.stringify(same_origin_frontier_plan)])
		return {}
	second_raid = EnemyAdventureRules.assign_target(session, config, second_raid)
	if String(second_raid.get("target_kind", "")) != "explore":
		_fail("Second no-objective host did not receive a frontier assignment: %s" % JSON.stringify(second_raid))
		return {}
	if String(second_raid.get("target_placement_id", "")) == String(first_raid.get("target_placement_id", "")):
		_fail("Live frontier hosts received the same exclusive target: %s" % JSON.stringify([first_raid, second_raid]))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters[1] = second_raid
	session.overworld["encounters"] = encounters
	var starts := {
		String(first_raid.get("placement_id", "")): Vector2i(int(first_raid.get("x", 0)), int(first_raid.get("y", 0))),
		String(second_raid.get("placement_id", "")): Vector2i(int(second_raid.get("x", 0)), int(second_raid.get("y", 0))),
	}
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var first_after := _encounter_by_id(session, String(first_raid.get("placement_id", "")))
	var second_after := _encounter_by_id(session, String(second_raid.get("placement_id", "")))
	for moved_raid in [first_after, second_after]:
		var placement_id := String(moved_raid.get("placement_id", ""))
		var start: Vector2i = starts.get(placement_id, Vector2i(-1, -1))
		var finish := Vector2i(int(moved_raid.get("x", -1)), int(moved_raid.get("y", -1)))
		if moved_raid.is_empty() or finish == start:
			_fail("Exclusive frontier host did not advance toward its distinct target: %s" % JSON.stringify(moved_raid))
			return {}
	return {
		"case_id": "exclusive_frontier_reservations_diversify_live_hosts",
		"first_target_id": String(first_raid.get("target_placement_id", "")),
		"second_target_id": String(second_raid.get("target_placement_id", "")),
		"first_after": {"x": int(first_after.get("x", -1)), "y": int(first_after.get("y", -1))},
		"second_after": {"x": int(second_after.get("x", -1)), "y": int(second_after.get("y", -1))},
		"event_types": _event_types(result.get("events", [])),
	}

func _rebuild_relaunch_preserves_frontier_history() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var spawn_point := {"placement_id": "rebuild_frontier_origin", "x": 7, "y": 2}
	var first_plan := EnemyTurnRules._rebuild_pressure_exploration_plan(
		session,
		config,
		MIRECLAW,
		spawn_point
	)
	var first_target_id := String(first_plan.get("target_placement_id", ""))
	if first_plan.is_empty() or not first_target_id.begins_with("explore:"):
		_fail("Rebuild relaunch fixture did not produce an initial frontier target: %s" % JSON.stringify(first_plan))
		return {}
	var state := _enemy_state(session)
	state["recent_rebuild_exploration_target_ids"] = [first_target_id]
	state["rebuild_pressure_request"] = {
		"requested_day": int(session.day),
		"origin_town_id": "duskfen_bastion",
		"commander_id": "hero_vaska",
		"reason": "no_spare_garrison_after_regroup",
		"recent_exploration_target_ids": [],
	}
	_update_enemy_state(session, state)
	var second_plan := EnemyTurnRules._rebuild_pressure_exploration_plan(
		session,
		config,
		MIRECLAW,
		spawn_point
	)
	var second_target_id := String(second_plan.get("target_placement_id", ""))
	if second_plan.is_empty() or second_target_id == first_target_id:
		_fail("Rebuild relaunch repeated the exhausted faction frontier target: first=%s second=%s" % [JSON.stringify(first_plan), JSON.stringify(second_plan)])
		return {}
	var carried_history := _normalize_string_array(second_plan.get("recent_exploration_target_ids", []))
	if first_target_id not in carried_history:
		_fail("Rebuild relaunch plan dropped faction frontier history: %s" % JSON.stringify(second_plan))
		return {}
	var candidate := EnemyTurnRules._spawn_point_candidate_from_plan(
		spawn_point,
		second_plan,
		"hero_vaska",
		"rebuild_pressure_recon",
		0
	)
	if first_target_id not in _normalize_string_array(candidate.get("recent_exploration_target_ids", [])):
		_fail("Rebuild spawn candidate dropped faction frontier history: %s" % JSON.stringify(candidate))
		return {}
	return {
		"case_id": "rebuild_relaunch_preserves_faction_frontier_history",
		"first_target_id": first_target_id,
		"second_target_id": second_target_id,
		"carried_history": carried_history,
	}

func _exploration_arrival_reassigns_visible_resource() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_resource_target_session(session)
	_add_exploration_raid(session, 5, 4)
	var state := _enemy_state(session)
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var reassigned := _first_enemy_raid_for_kind(session, "resource")
	if reassigned.is_empty():
		_fail("Exploration arrival did not reassign to newly visible resource: %s" % JSON.stringify(result))
		return {}
	if String(reassigned.get("target_placement_id", "")) != "river_free_company":
		_fail("Exploration arrival reassigned to wrong resource: %s" % JSON.stringify(reassigned))
		return {}
	return {
		"case_id": "exploration_arrival_reassigns_visible_resource",
		"exploration_origin": {"x": 5, "y": 4},
		"reassigned_target_kind": String(reassigned.get("target_kind", "")),
		"reassigned_target_id": String(reassigned.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
	}

func _moving_exploration_refreshes_memory_before_same_turn_retarget() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_resource_target_session(session)
	_add_moving_exploration_raid(session, 6, 4, 5, 4)
	if not _memory_target_record(session, "resource", "river_free_company").is_empty():
		_fail("Post-move scouting fixture should start without resource memory: %s" % JSON.stringify(_enemy_memory(session)))
		return {}
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var record := _memory_target_record(session, "resource", "river_free_company")
	if record.is_empty():
		_fail("Moving exploration commander did not refresh newly reached sight line before same-turn retarget: %s" % JSON.stringify(result))
		return {}
	if String(record.get("source_kind", "")) != "commander":
		_fail("Post-move scout memory should use commander source kind: %s" % JSON.stringify(record))
		return {}
	if String(record.get("source_id", "")) != "known_world_moving_exploration_probe":
		_fail("Post-move scout memory should use the moved commander source id: %s" % JSON.stringify(record))
		return {}
	var reassigned := _first_enemy_raid_for_kind(session, "resource")
	if reassigned.is_empty():
		_fail("Moving exploration commander did not retarget newly visible resource in the same advance: %s" % JSON.stringify(session.overworld.get("encounters", [])))
		return {}
	if String(reassigned.get("target_placement_id", "")) != "river_free_company":
		_fail("Moving exploration commander retargeted the wrong post-move sight target: %s" % JSON.stringify(reassigned))
		return {}
	return {
		"case_id": "moving_exploration_refreshes_memory_before_same_turn_retarget",
		"start": {"x": 6, "y": 4},
		"post_move": {"x": int(reassigned.get("x", -1)), "y": int(reassigned.get("y", -1))},
		"memory_source_kind": String(record.get("source_kind", "")),
		"memory_source_id": String(record.get("source_id", "")),
		"reassigned_target_kind": String(reassigned.get("target_kind", "")),
		"reassigned_target_id": String(reassigned.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
	}

func _nonhero_route_avoids_player_hero_occupied_tile() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_make_hidden_resource_target_session(session)
	_set_primary_hero_position(session, 5, 4)
	_add_resource_route_raid(session, 6, 4, "river_free_company")
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var raid := _encounter_by_id(session, "known_world_resource_route_probe")
	if raid.is_empty():
		_fail("Resource route occupancy fixture lost the route probe: %s" % JSON.stringify(result))
		return {}
	if int(raid.get("x", -1)) == 5 and int(raid.get("y", -1)) == 4:
		_fail("Non-hero AI route stepped onto a live player hero tile: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Route occupancy fixture should stay on protected resource objective, got %s" % JSON.stringify(raid))
		return {}
	return {
		"case_id": "nonhero_route_avoids_player_hero_occupied_tile",
		"start": {"x": 6, "y": 4},
		"blocked_hero_tile": {"x": 5, "y": 4},
		"after_move": {"x": int(raid.get("x", -1)), "y": int(raid.get("y", -1))},
		"target_kind": String(raid.get("target_kind", "")),
		"target_id": String(raid.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
	}

func _hero_route_occupancy_uses_moving_faction_sight() -> Dictionary:
	var session = _base_session()
	_make_faction_scoped_route_corridor(session)
	var start := Vector2i(12, 4)
	var goal := [Vector2i(0, 4)]
	var mire_distance := EnemyAdventureRules._path_distance(session, start, goal, "", MIRECLAW)
	var ember_distance := EnemyAdventureRules._path_distance(session, start, goal, "", EMBERCOURT)
	if mire_distance >= 9999:
		_fail("Mireclaw should not route around a player hero only visible to another faction. distances mire=%d ember=%d" % [mire_distance, ember_distance])
		return {}
	if ember_distance < 9999:
		_fail("Same-faction sighted player hero should block the one-lane route for Embercourt. distances mire=%d ember=%d" % [mire_distance, ember_distance])
		return {}
	return {
		"case_id": "hero_route_occupancy_uses_moving_faction_sight",
		"hero_tile": {"x": 6, "y": 4},
		"route_start": {"x": start.x, "y": start.y},
		"route_goal": {"x": 0, "y": 4},
		"mireclaw_distance": mire_distance,
		"embercourt_distance": ember_distance,
	}

func _target_assignment_respects_faction_scoped_route_occupancy() -> Dictionary:
	var session = _base_session()
	_make_faction_scoped_route_corridor(session)
	_add_corridor_resource_target(session)
	var mire_config := _priority_target_config(MIRECLAW, "river_free_company")
	var ember_config := _priority_target_config(EMBERCOURT, "river_free_company")
	var mire_plan := EnemyAdventureRules.choose_target(
		session,
		mire_config,
		{"x": 12, "y": 4},
		{}
	)
	var ember_plan := EnemyAdventureRules.choose_target(
		session,
		ember_config,
		{"x": 12, "y": 4},
		{}
	)
	if String(mire_plan.get("target_kind", "")) != "resource" or String(mire_plan.get("target_placement_id", "")) != "river_free_company":
		_fail("Mireclaw assignment should keep the resource target when its faction cannot see the route-blocking hero: %s" % JSON.stringify(mire_plan))
		return {}
	if String(ember_plan.get("target_kind", "")) == "resource" and String(ember_plan.get("target_placement_id", "")) == "river_free_company":
		_fail("Embercourt assignment should not select a non-hero objective behind its visible hero blocker: %s" % JSON.stringify(ember_plan))
		return {}
	return {
		"case_id": "target_assignment_respects_faction_scoped_route_occupancy",
		"blocked_resource_id": "river_free_company",
		"mireclaw_target": "%s:%s" % [String(mire_plan.get("target_kind", "")), String(mire_plan.get("target_placement_id", ""))],
		"embercourt_target": "%s:%s" % [String(ember_plan.get("target_kind", "")), String(ember_plan.get("target_placement_id", ""))],
		"mireclaw_goal_distance": int(mire_plan.get("goal_distance", -1)),
		"embercourt_goal_distance": int(ember_plan.get("goal_distance", -1)),
	}

func _base_session():
	var session = ScenarioFactory.create_session(
		RIVER_PASS,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _set_primary_hero_position(session, x: int, y: int) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = String(session.overworld.get("active_hero_id", "hero_lyra"))
	hero["name"] = String(hero.get("name", "Lyra"))
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = {"x": x, "y": y}
	session.overworld["active_hero_id"] = String(hero.get("id", "hero_lyra"))
	session.overworld["player_heroes"] = [hero]

func _make_no_known_targets_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	session.overworld["towns"] = towns

	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _make_hidden_resource_target_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	session.overworld["towns"] = towns

	var resources := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["x"] = 0
		node["y"] = 4
		node["collected"] = true
		node["collected_by_faction_id"] = "player"
		node["response_until_day"] = 0
		node["response_security_rating"] = 0
		node["delivery_manifest"] = {}
		resources.append(node)
	session.overworld["resource_nodes"] = resources
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _make_faction_scoped_route_corridor(session) -> void:
	var map := []
	for y in range(9):
		var row := []
		for x in range(13):
			row.append("grass" if y == 4 else "rock")
		map.append(row)
	session.overworld["map"] = map
	session.overworld["map_size"] = {"width": 13, "height": 9}
	_set_primary_hero_position(session, 6, 4)
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	var towns := []
	towns.append({
		"placement_id": "mire_far_watch",
		"town_id": "town_duskfen",
		"name": "Mire Far Watch",
		"x": 12,
		"y": 8,
		"owner": "enemy",
		"controlling_faction_id": MIRECLAW,
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	towns.append({
		"placement_id": "ember_near_watch",
		"town_id": "town_embercourt",
		"name": "Ember Near Watch",
		"x": 6,
		"y": 2,
		"owner": "enemy",
		"controlling_faction_id": EMBERCOURT,
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns

func _add_corridor_resource_target(session) -> void:
	session.overworld["resource_nodes"] = [{
		"placement_id": "river_free_company",
		"site_id": "site_riverwatch_free_company_yard",
		"x": 0,
		"y": 4,
		"collected": true,
		"collected_by_faction_id": "player",
		"response_until_day": 0,
		"response_security_rating": 0,
		"delivery_manifest": {},
	}]

func _make_hidden_hero_delivery_session(session, hero_id: String) -> void:
	_make_hidden_resource_target_session(session)
	var resources: Array = session.overworld.get("resource_nodes", [])
	for index in range(resources.size()):
		if not (resources[index] is Dictionary):
			continue
		var node: Dictionary = resources[index]
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["delivery_controller_id"] = "player"
		node["delivery_origin_town_id"] = "riverwatch_hold"
		node["delivery_arrival_day"] = int(session.day) + 2
		node["delivery_target_kind"] = "hero"
		node["delivery_target_id"] = hero_id
		node["delivery_target_label"] = "Lyra"
		node["delivery_manifest"] = {"unit_river_guard": 4}
		resources[index] = node
		session.overworld["resource_nodes"] = resources
		return
	_fail("Could not configure hidden hero delivery route.")

func _make_hidden_neutral_town_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	towns.append({
		"placement_id": "hidden_neutral_hold",
		"town_id": "town_duskfen",
		"name": "Hidden Neutral Hold",
		"x": 0,
		"y": 4,
		"owner": "neutral",
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _add_exploration_raid(session, x: int, y: int) -> void:
	var raid := {
		"placement_id": "known_world_exploration_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": true,
		"target_kind": "explore",
		"target_placement_id": "explore:%d:%d" % [x, y],
		"target_label": "Frontier scout %d,%d" % [x, y],
		"target_x": x,
		"target_y": y,
		"goal_x": x,
		"goal_y": y,
		"goal_distance": 0,
		"target_reason_codes": ["no_known_targets", "frontier_scouting", "search_contact"],
		"target_public_reason": "scouting the frontier",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _frontier_reservation_raid(
	session,
	placement_id: String,
	hero_id: String,
	x: int,
	y: int,
	target_plan: Dictionary
) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
	}
	if not target_plan.is_empty():
		raid.merge(target_plan, true)
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		hero_id,
		MIRECLAW,
		session
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _add_moving_exploration_raid(session, x: int, y: int, target_x: int, target_y: int) -> void:
	var raid := {
		"placement_id": "known_world_moving_exploration_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"target_kind": "explore",
		"target_placement_id": "explore:%d:%d" % [target_x, target_y],
		"target_label": "Frontier scout %d,%d" % [target_x, target_y],
		"target_x": target_x,
		"target_y": target_y,
		"goal_x": target_x,
		"goal_y": target_y,
		"goal_distance": abs(x - target_x) + abs(y - target_y),
		"target_reason_codes": ["no_known_targets", "frontier_scouting", "search_contact"],
		"target_public_reason": "scouting the frontier",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _add_resource_route_raid(session, x: int, y: int, target_id: String) -> void:
	var target := _resource_node(session, target_id)
	if target.is_empty():
		_fail("Could not find resource route target %s" % target_id)
		return
	var raid := {
		"placement_id": "known_world_resource_route_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"target_kind": "resource",
		"target_placement_id": target_id,
		"target_label": "Route Occupancy Resource",
		"target_x": int(target.get("x", 0)),
		"target_y": int(target.get("y", 0)),
		"goal_x": int(target.get("x", 0)),
		"goal_y": int(target.get("y", 0)),
		"goal_distance": abs(x - int(target.get("x", 0))) + abs(y - int(target.get("y", 0))),
		"target_reason_codes": ["active_front_support", "route_occupancy_fixture"],
		"target_public_reason": "holding protected route",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _candidate_has_target(candidates: Array, target_kind: String, target_id: String) -> bool:
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("target_kind", "")) == target_kind and String(candidate.get("target_placement_id", "")) == target_id:
			return true
	return false

func _first_delivery_candidate(candidates: Array, target_kind: String, target_id: String) -> Dictionary:
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("delivery_intercept_node_placement_id", "")) == "":
			continue
		if String(candidate.get("target_kind", "")) != target_kind:
			continue
		if String(candidate.get("target_placement_id", "")) != target_id:
			continue
		return candidate
	return {}

func _first_enemy_raid_for_kind(session, target_kind: String) -> Dictionary:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW and String(encounter.get("target_kind", "")) == target_kind:
			return encounter
	return {}

func _encounter_by_id(session, placement_id: String) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == placement_id:
			return encounter_value
	return {}

func _resource_node(session, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _first_task_for_kind(session, target_kind: String) -> Dictionary:
	for task_value in _task_state(session).get("tasks", []):
		if task_value is Dictionary and String(task_value.get("target_kind", "")) == target_kind:
			return task_value
	return {}

func _first_task_for_target(session, target_kind: String, target_id: String) -> Dictionary:
	for task_value in _task_state(session).get("tasks", []):
		if task_value is Dictionary \
				and String(task_value.get("target_kind", "")) == target_kind \
				and String(task_value.get("target_id", "")) == target_id:
			return task_value
	return {}

func _task_by_id(session, task_id: String) -> Dictionary:
	for task_value in _task_state(session).get("tasks", []):
		if task_value is Dictionary and String(task_value.get("task_id", "")) == task_id:
			return task_value
	return {}

func _task_state(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}

func _memory_target_record(session, target_kind: String, target_id: String) -> Dictionary:
	var memory := _enemy_memory(session)
	for record_value in memory.get("scouted_targets", []):
		if record_value is Dictionary \
				and String(record_value.get("target_kind", "")) == target_kind \
				and String(record_value.get("target_id", "")) == target_id:
			return record_value
	return {}

func _explore_target_tile(target_id: String) -> Dictionary:
	var parts := target_id.split(":")
	if parts.size() != 3 or String(parts[0]) != "explore":
		return {}
	return {"x": int(parts[1]), "y": int(parts[2])}

func _move_raid_to_target(session, placement_id: String, x: int, y: int) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		if not (encounters[index] is Dictionary):
			continue
		var encounter: Dictionary = encounters[index]
		if String(encounter.get("placement_id", "")) != placement_id:
			continue
		encounter["x"] = x
		encounter["y"] = y
		encounter["goal_x"] = x
		encounter["goal_y"] = y
		encounter["goal_distance"] = 0
		encounter["arrived"] = true
		encounters[index] = encounter
		session.overworld["encounters"] = encounters
		return

func _event_types(events: Variant) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event_value in events:
		if event_value is Dictionary:
			var event_type := String(event_value.get("event_type", ""))
			if event_type != "" and event_type not in output:
				output.append(event_type)
	return output

func _normalize_string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "":
			output.append(text)
	return output

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _ordinary_target_config() -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["priority_target_placement_ids"] = []
	config["priority_target_bonus"] = 0
	return config

func _priority_target_config(faction_id: String, placement_id: String) -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["faction_id"] = faction_id
	config["label"] = String(ContentService.get_faction(faction_id).get("name", faction_id))
	config["priority_target_placement_ids"] = [placement_id]
	config["priority_target_bonus"] = 400
	return config

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW:
			return state
	_fail("Could not find Mireclaw enemy state.")
	return {}

func _enemy_memory(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("known_world_memory", {}) if state.get("known_world_memory", {}) is Dictionary else {}

func _patch_enemy_memory(session, memory: Dictionary) -> void:
	var state := _enemy_state(session)
	state["known_world_memory"] = memory
	_update_enemy_state(session, state)

func _update_enemy_state(session, updated_state: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if states[index] is Dictionary and String(states[index].get("faction_id", "")) == MIRECLAW:
			states[index] = updated_state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update Mireclaw enemy state.")

func _configure_known_world_catalog_fixture(session) -> void:
	_set_primary_hero_position(session, 6, 4)
	session.overworld["towns"] = [
		{
			"placement_id": "catalog_enemy_town_a",
			"town_id": "town_duskfen",
			"name": "Catalog Enemy Town A",
			"x": 4,
			"y": 4,
			"owner": "enemy",
			"controlling_faction_id": MIRECLAW,
			"garrison": [],
			"available_recruits": {},
			"buildings": [],
		},
		{
			"placement_id": "catalog_enemy_town_b",
			"town_id": "town_duskfen",
			"name": "Catalog Enemy Town B",
			"x": 8,
			"y": 4,
			"owner": "enemy",
			"controlling_faction_id": MIRECLAW,
			"garrison": [],
			"available_recruits": {},
			"buildings": [],
		},
		{
			"placement_id": "catalog_player_town",
			"town_id": "town_riverwatch",
			"name": "Catalog Player Town",
			"x": 6,
			"y": 4,
			"owner": "player",
			"controlling_faction_id": "player",
			"garrison": [],
			"available_recruits": {},
			"buildings": [],
		},
		{
			"placement_id": "catalog_neutral_town",
			"town_id": "town_riverwatch",
			"name": "Catalog Neutral Town",
			"x": 6,
			"y": 5,
			"owner": "neutral",
			"controlling_faction_id": "",
			"garrison": [],
			"available_recruits": {},
			"buildings": [],
		},
		{
			"placement_id": "catalog_inactive_town",
			"town_id": "town_riverwatch",
			"name": "Catalog Inactive Town",
			"x": 6,
			"y": 6,
			"owner": "inactive",
			"controlling_faction_id": "",
			"garrison": [],
			"available_recruits": {},
			"buildings": [],
		},
	]
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "catalog_resource_target",
			"site_id": "site_wood_wagon",
			"x": 6,
			"y": 3,
			"collected": true,
			"collected_by_faction_id": "player",
		},
		{
			"placement_id": "catalog_resource_source",
			"site_id": "site_ember_signal_post",
			"x": 6,
			"y": 7,
			"collected": true,
			"collected_by_faction_id": MIRECLAW,
		},
		{
			"placement_id": "catalog_resource_collected",
			"site_id": "site_waystone_cache",
			"x": 5,
			"y": 5,
			"collected": true,
			"collected_by_faction_id": "player",
		},
	]
	session.overworld["artifact_nodes"] = [
		{
			"placement_id": "catalog_artifact_target",
			"artifact_id": "artifact_trailsinger_boots",
			"x": 5,
			"y": 4,
			"collected": false,
		},
		{
			"placement_id": "catalog_artifact_collected",
			"artifact_id": "artifact_quarry_tally_rod",
			"x": 7,
			"y": 4,
			"collected": true,
		},
	]
	session.overworld["encounters"] = [
		{
			"placement_id": "catalog_commander_source",
			"encounter_id": "encounter_mire_raid",
			"label": "Catalog Commander Source",
			"x": 6,
			"y": 2,
			"spawned_by_faction_id": MIRECLAW,
			"difficulty": "pressure",
			"days_active": 0,
		},
		{
			"placement_id": "catalog_encounter_target",
			"encounter_id": "encounter_ghoul_grove",
			"label": "Catalog Encounter Target",
			"x": 6,
			"y": 6,
		},
		{
			"placement_id": "catalog_encounter_resolved",
			"encounter_id": "encounter_hollow_mire",
			"label": "Catalog Resolved Encounter",
			"x": 7,
			"y": 5,
		},
	]
	session.overworld["resolved_encounters"] = ["catalog_encounter_resolved"]
	_patch_enemy_memory(session, {})

func _move_known_world_catalog_fixture(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "catalog_enemy_town_a":
			town["x"] = 0
			town["y"] = 0
			towns[index] = town
	session.overworld["towns"] = towns
	var resources: Array = session.overworld.get("resource_nodes", [])
	for index in range(resources.size()):
		if not (resources[index] is Dictionary):
			continue
		var node: Dictionary = resources[index]
		if String(node.get("placement_id", "")) == "catalog_resource_target":
			node["x"] = 8
			node["y"] = 3
			resources[index] = node
	session.overworld["resource_nodes"] = resources

func _remove_known_world_catalog_fixture_entries(session) -> void:
	var kept_towns := []
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) in ["catalog_enemy_town_a", "catalog_neutral_town"]:
			continue
		kept_towns.append(town_value)
	session.overworld["towns"] = kept_towns

func _disable_known_world_catalog_sources(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("owner", "")) == "enemy":
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
			towns[index] = town
	session.overworld["towns"] = towns
	var resources: Array = session.overworld.get("resource_nodes", [])
	for index in range(resources.size()):
		if not (resources[index] is Dictionary):
			continue
		var node: Dictionary = resources[index]
		if String(node.get("placement_id", "")) == "catalog_resource_source":
			node["collected_by_faction_id"] = "player"
			resources[index] = node
	session.overworld["resource_nodes"] = resources
	var encounters := []
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == "catalog_commander_source":
			continue
		encounters.append(encounter_value)
	session.overworld["encounters"] = encounters

func _known_world_nonmemory_authority(session) -> Dictionary:
	var payload: Dictionary = session.to_dict()
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	var states: Array = overworld.get("enemy_states", []) if overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		if not (states[index] is Dictionary) or String(states[index].get("faction_id", "")) != MIRECLAW:
			continue
		var state: Dictionary = states[index]
		state.erase("known_world_memory")
		states[index] = state
	overworld["enemy_states"] = states
	payload["overworld"] = overworld
	return payload

func _current_known_world_projection_snapshot(session, config: Dictionary, faction_id: String) -> Dictionary:
	var sources: Array = EnemyAdventureRules._enemy_hero_sighting_sources(session, config, faction_id).duplicate(true)
	var catalog: Array = EnemyAdventureRules._enemy_visible_target_catalog(session, config, faction_id).duplicate(true)
	var visible_by_source := []
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		visible_by_source.append({
			"source_id": String(source_value.get("id", "")),
			"records": EnemyAdventureRules._current_enemy_visible_target_records_for_source(session, config, faction_id, source_value, catalog).duplicate(true),
		})
	return {
		"sources": sources,
		"catalog": catalog,
		"visible_by_source": visible_by_source,
		"hero_records": EnemyAdventureRules._current_enemy_player_hero_sighting_records(session, config, faction_id, sources).duplicate(true),
		"target_records": EnemyAdventureRules._current_enemy_scouted_target_records(session, config, faction_id, sources, catalog).duplicate(true),
	}

func _known_world_source_ids(sources_value: Variant) -> Array:
	var ids := []
	if not (sources_value is Array):
		return ids
	for source_value in sources_value:
		if source_value is Dictionary:
			ids.append(String(source_value.get("id", "")))
	return ids

func _known_world_catalog_keys(catalog_value: Variant) -> Array:
	var keys := []
	if not (catalog_value is Array):
		return keys
	for target_value in catalog_value:
		if target_value is Dictionary:
			keys.append("%s:%s" % [String(target_value.get("target_kind", "")), String(target_value.get("target_id", ""))])
	return keys

func _known_world_record_source(records_value: Variant, target_id: String) -> String:
	if not (records_value is Array):
		return ""
	for record_value in records_value:
		if not (record_value is Dictionary):
			continue
		if String(record_value.get("target_id", record_value.get("hero_id", ""))) == target_id:
			return String(record_value.get("source_id", ""))
	return ""

func _known_world_target_source_tie_exact(visible_value: Variant, target_id: String) -> bool:
	if not (visible_value is Array):
		return false
	var tied_rows := []
	for row_value in visible_value:
		if not (row_value is Dictionary) or String(row_value.get("source_id", "")) not in ["catalog_enemy_town_a", "catalog_enemy_town_b"]:
			continue
		for record_value in row_value.get("records", []):
			if record_value is Dictionary and String(record_value.get("target_id", "")) == target_id:
				tied_rows.append(record_value)
	return (
		tied_rows.size() == 2
		and int(tied_rows[0].get("_source_distance", -1)) == 2
		and int(tied_rows[1].get("_source_distance", -1)) == 2
		and int(tied_rows[0].get("_source_priority", -1)) == int(tied_rows[1].get("_source_priority", -2))
	)

func _known_world_refresh_exact(session, refresh_result: Dictionary, expected_memory: Dictionary, expected_authority: Dictionary, control: Dictionary) -> bool:
	var updated_state: Dictionary = refresh_result.get("state", {}) if refresh_result.get("state", {}) is Dictionary else {}
	var actual_memory: Dictionary = updated_state.get("known_world_memory", {}) if updated_state.get("known_world_memory", {}) is Dictionary else {}
	var live_state := _enemy_state(session)
	var live_memory: Dictionary = live_state.get("known_world_memory", {}) if live_state.get("known_world_memory", {}) is Dictionary else {}
	var profile: Dictionary = refresh_result.get("target_catalog_profile", {}) if refresh_result.get("target_catalog_profile", {}) is Dictionary else {}
	var source_count: int = control.get("sources", []).size()
	var catalog_count: int = control.get("catalog", []).size()
	var hero_input_count := _legacy_known_world_player_hero_input_count_control(session)
	var exact_checks := {
		"updated_memory_exact": actual_memory == expected_memory,
		"live_memory_exact": live_memory == expected_memory,
		"returned_state_exact": updated_state == live_state,
		"nonmemory_authority_exact": _known_world_nonmemory_authority(session) == expected_authority,
		"sighting_count_exact": int(refresh_result.get("sighting_count", -1)) == control.get("hero_records", []).size(),
		"scouted_target_count_exact": int(refresh_result.get("scouted_target_count", -1)) == control.get("target_records", []).size(),
		"source_enumeration_once": int(profile.get("sight_source_enumeration_count", 0)) == 1,
		"catalog_enumeration_once": int(profile.get("target_catalog_enumeration_count", 0)) == 1,
		"source_count_exact": int(profile.get("sight_source_count", -1)) == source_count,
		"catalog_count_exact": int(profile.get("target_catalog_count", -1)) == catalog_count,
		"hero_projection_fresh_exact": int(profile.get("hero_source_projection_count", 0)) == source_count,
		"hero_comparison_fresh_exact": int(profile.get("hero_source_comparison_count", 0)) == source_count * hero_input_count,
		"target_projection_fresh_exact": int(profile.get("target_source_projection_count", 0)) == source_count,
		"catalog_projection_fresh_exact": int(profile.get("target_catalog_projection_count", 0)) == source_count * catalog_count,
	}
	for check_name in exact_checks.keys():
		if bool(exact_checks.get(check_name, false)):
			continue
		_fail("Known-world refresh exact check failed %s: expected_memory=%s actual_memory=%s profile=%s" % [check_name, JSON.stringify(expected_memory), JSON.stringify(actual_memory), JSON.stringify(profile)])
		return false
	return true

func _legacy_known_world_projection_control(session, config: Dictionary, faction_id: String) -> Dictionary:
	var sources := _legacy_known_world_sight_sources_control(session, config, faction_id)
	var catalog := _legacy_known_world_target_catalog_control(session, config, faction_id)
	var visible_by_source := []
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		visible_by_source.append({
			"source_id": String(source_value.get("id", "")),
			"records": _legacy_known_world_visible_records_for_source_control(session, config, faction_id, source_value),
		})
	return {
		"sources": sources.duplicate(true),
		"catalog": catalog.duplicate(true),
		"visible_by_source": visible_by_source,
		"hero_records": _legacy_known_world_hero_records_control(session, sources),
		"target_records": _legacy_known_world_target_records_control(session, config, faction_id, sources),
	}

func _legacy_objective_anchor_surface_control(session) -> Dictionary:
	var scenario: Dictionary = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	var town_placement_ids := []
	var flag_ids := []
	if objectives is Dictionary:
		for bucket in ["victory", "defeat"]:
			for objective_value in objectives.get(bucket, []):
				if not (objective_value is Dictionary):
					continue
				var placement_id := String(objective_value.get("placement_id", ""))
				if placement_id != "" and placement_id not in town_placement_ids:
					town_placement_ids.append(placement_id)
				if String(objective_value.get("type", "")) == "flag_true":
					var flag_id := String(objective_value.get("flag", ""))
					if flag_id != "" and flag_id not in flag_ids:
						flag_ids.append(flag_id)
	var tiles := []
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var placement_id := String(town_value.get("placement_id", ""))
		if placement_id != "" and _legacy_town_objective_anchor_control(session, placement_id):
			tiles.append(Vector2i(int(town_value.get("x", 0)), int(town_value.get("y", 0))))
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and _legacy_encounter_objective_anchor_control(session, encounter_value):
			tiles.append(Vector2i(int(encounter_value.get("x", 0)), int(encounter_value.get("y", 0))))
	return {
		"town_placement_ids": town_placement_ids,
		"flag_ids": flag_ids,
		"tiles": tiles,
	}

func _legacy_town_objective_anchor_control(session, placement_id: String) -> bool:
	var scenario: Dictionary = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective_value in objectives.get(bucket, []):
			if objective_value is Dictionary and String(objective_value.get("placement_id", "")) == placement_id:
				return true
	return false

func _legacy_encounter_objective_anchor_control(session, encounter: Dictionary) -> bool:
	var encounter_template: Dictionary = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var victory_flags: Array = encounter_template.get("victory_flags", []) if encounter_template.get("victory_flags", []) is Array else []
	if victory_flags.is_empty():
		return false
	var scenario: Dictionary = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective_value in objectives.get(bucket, []):
			if not (objective_value is Dictionary) or String(objective_value.get("type", "")) != "flag_true":
				continue
			if String(objective_value.get("flag", "")) in victory_flags:
				return true
	return false

func _legacy_objective_proximity_bonus_control(session, x: int, y: int) -> int:
	var best_distance := 9999
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var placement_id := String(town_value.get("placement_id", ""))
		if placement_id == "" or not _legacy_town_objective_anchor_control(session, placement_id):
			continue
		best_distance = min(best_distance, abs(x - int(town_value.get("x", 0))) + abs(y - int(town_value.get("y", 0))))
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary) or not _legacy_encounter_objective_anchor_control(session, encounter_value):
			continue
		best_distance = min(best_distance, abs(x - int(encounter_value.get("x", 0))) + abs(y - int(encounter_value.get("y", 0))))
	if best_distance == 9999:
		return 0
	if best_distance <= 1:
		return 45
	if best_distance <= 3:
		return 25
	if best_distance <= 5:
		return 10
	return 0

func _legacy_known_world_sight_sources_control(session, config: Dictionary, faction_id: String) -> Array:
	var sources := []
	if session == null or faction_id == "":
		return sources
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy" or EnemyAdventureRules._town_faction_id(town) != faction_id:
			continue
		var radius := EnemyAdventureRules.AI_HERO_TOWN_SIGHT_RADIUS
		if OverworldRules.town_strategic_role(town) in ["capital", "stronghold"]:
			radius += 1
		sources.append({
			"kind": "town",
			"id": String(town.get("placement_id", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"radius": radius,
		})
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not _legacy_known_world_active_raid_control(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		sources.append({
			"kind": "commander",
			"id": String(encounter.get("placement_id", "")),
			"x": int(encounter.get("x", 0)),
			"y": int(encounter.get("y", 0)),
			"radius": EnemyAdventureRules.AI_HERO_RAID_SIGHT_RADIUS,
		})
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("collected_by_faction_id", "")) != faction_id:
			continue
		var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id", "")))
		var site_radius: int = max(0, int(site.get("vision_radius", 0)))
		if site_radius <= 0:
			continue
		sources.append({
			"kind": "resource_site",
			"id": String(node.get("placement_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"radius": max(EnemyAdventureRules.AI_HERO_RESOURCE_SITE_MIN_SIGHT_RADIUS, site_radius),
		})
	return sources

func _legacy_known_world_active_raid_control(encounter_value: Variant, faction_id: String, resolved_encounters: Variant) -> bool:
	if not (encounter_value is Dictionary):
		return false
	var encounter: Dictionary = encounter_value
	if bool(encounter.get("raid_retired_to_rebuild", false)):
		return false
	var raid_faction := String(encounter.get("spawned_by_faction_id", ""))
	if faction_id == "":
		if raid_faction == "":
			return false
	elif raid_faction != faction_id:
		return false
	var placement_id := String(encounter.get("placement_id", ""))
	return not (resolved_encounters is Array and placement_id in resolved_encounters)

func _legacy_known_world_target_catalog_control(session, config: Dictionary, faction_id: String) -> Array:
	var catalog := []
	if session == null or faction_id == "":
		return catalog
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var owner := String(town.get("owner", "neutral"))
		if owner not in ["player", "neutral"]:
			continue
		catalog.append({
			"target_kind": "town",
			"target_id": String(town.get("placement_id", "")),
			"target_label": EnemyAdventureRules._town_name(town),
			"target_tile": Vector2i(int(town.get("x", 0)), int(town.get("y", 0))),
			"priority": 180 if owner == "player" else 145,
		})
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id", "")))
		if not EnemyAdventureRules._resource_node_contestable_by_faction(node, site, faction_id):
			continue
		catalog.append({
			"target_kind": "resource",
			"target_id": String(node.get("placement_id", "")),
			"target_label": String(site.get("name", "Resource Site")),
			"target_tile": Vector2i(int(node.get("x", 0)), int(node.get("y", 0))),
			"priority": 120 + EnemyAdventureRules._resource_route_pressure_value(site),
		})
	for node_value in session.overworld.get("artifact_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if bool(node.get("collected", false)):
			continue
		catalog.append({
			"target_kind": "artifact",
			"target_id": String(node.get("placement_id", "")),
			"target_label": ArtifactRules.describe_artifact(String(node.get("artifact_id", ""))),
			"target_tile": Vector2i(int(node.get("x", 0)), int(node.get("y", 0))),
			"priority": EnemyAdventureRules._artifact_target_priority(session, node),
		})
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if EnemyAdventureRules._encounter_is_pressure_host_candidate(encounter, faction_id, resolved_encounters):
			continue
		if OverworldRules.is_encounter_resolved(session, encounter):
			continue
		catalog.append({
			"target_kind": "encounter",
			"target_id": String(encounter.get("placement_id", "")),
			"target_label": EnemyAdventureRules._encounter_target_label(session, encounter, "Frontier Camp"),
			"target_tile": Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0))),
			"priority": EnemyAdventureRules._encounter_target_priority(session, encounter),
		})
	return catalog

func _legacy_known_world_visible_records_for_source_control(session, config: Dictionary, faction_id: String, source: Dictionary) -> Array:
	var records := []
	var radius: int = max(0, int(source.get("radius", 0)))
	if session == null or faction_id == "" or radius <= 0:
		return records
	var origin := Vector2i(int(source.get("x", 0)), int(source.get("y", 0)))
	for target_value in _legacy_known_world_target_catalog_control(session, config, faction_id):
		if not (target_value is Dictionary):
			continue
		var target: Dictionary = target_value
		_legacy_known_world_append_visible_record_control(
			records,
			source,
			String(target.get("target_kind", "")),
			String(target.get("target_id", "")),
			String(target.get("target_label", target.get("target_id", ""))),
			target.get("target_tile", Vector2i.ZERO),
			int(target.get("priority", 0)),
			origin,
			radius,
			int(session.day)
		)
	return records

func _legacy_known_world_append_visible_record_control(records: Array, source: Dictionary, target_kind: String, target_id: String, target_label: String, target_tile: Vector2i, priority: int, origin: Vector2i, radius: int, current_day: int) -> void:
	if target_kind == "" or target_id == "":
		return
	var distance: int = abs(origin.x - target_tile.x) + abs(origin.y - target_tile.y)
	if distance > radius:
		return
	records.append({
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"x": target_tile.x,
		"y": target_tile.y,
		"scouted_day": current_day,
		"expires_day": current_day + EnemyAdventureRules.RAID_ADVENTURE_SCOUTING_MEMORY_DAYS,
		"source_kind": String(source.get("kind", "")),
		"source_id": String(source.get("id", "")),
		"source_raid_id": String(source.get("id", "")) if String(source.get("kind", "")) == "commander" else "",
		"state_policy": "ai_known_world_memory",
		"_source_distance": distance,
		"_source_priority": priority,
	})

func _legacy_known_world_target_records_control(session, config: Dictionary, faction_id: String, sources: Array) -> Array:
	var best_by_key := {}
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		for record_value in _legacy_known_world_visible_records_for_source_control(session, config, faction_id, source_value):
			if not (record_value is Dictionary):
				continue
			var record: Dictionary = record_value
			var key := "%s:%s" % [String(record.get("target_kind", "")), String(record.get("target_id", ""))]
			if (
				not best_by_key.has(key)
				or int(record.get("_source_distance", 9999)) < int(best_by_key[key].get("_source_distance", 9999))
				or (
					int(record.get("_source_distance", 9999)) == int(best_by_key[key].get("_source_distance", 9999))
					and int(record.get("_source_priority", 0)) > int(best_by_key[key].get("_source_priority", 0))
				)
			):
				best_by_key[key] = record
	var records := []
	for key in best_by_key.keys():
		var record: Dictionary = best_by_key[key]
		record.erase("_source_distance")
		record.erase("_source_priority")
		records.append(record)
	return _legacy_known_world_normalize_target_records_control(records, int(session.day))

func _legacy_known_world_hero_records_control(session, sources: Array) -> Array:
	var records := []
	if sources.is_empty():
		return records
	for hero_value in EnemyAdventureRules._player_hero_snapshots_for_intercept(session):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var hero_id := String(hero.get("id", ""))
		if hero_id == "":
			continue
		var hero_tile := EnemyAdventureRules._player_hero_goal_tile(hero)
		var best_source := {}
		var best_distance := 9999
		for source_value in sources:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var distance: int = abs(hero_tile.x - int(source.get("x", 0))) + abs(hero_tile.y - int(source.get("y", 0)))
			if distance > int(source.get("radius", 0)):
				continue
			if best_source.is_empty() or distance < best_distance:
				best_source = source
				best_distance = distance
		if best_source.is_empty():
			continue
		records.append({
			"hero_id": hero_id,
			"hero_label": String(hero.get("name", hero_id)),
			"x": hero_tile.x,
			"y": hero_tile.y,
			"army_strength": EnemyAdventureRules._known_player_hero_strength(hero),
			"seen_day": int(session.day),
			"expires_day": int(session.day) + EnemyAdventureRules.AI_HERO_SIGHTING_MEMORY_DAYS,
			"source_kind": String(best_source.get("kind", "")),
			"source_id": String(best_source.get("id", "")),
			"confidence": "current",
			"state_policy": "ai_known_world_memory",
		})
	return records

func _legacy_known_world_player_hero_input_count_control(session) -> int:
	var count := 0
	for hero_value in EnemyAdventureRules._player_hero_snapshots_for_intercept(session):
		if hero_value is Dictionary and String(hero_value.get("id", "")) != "":
			count += 1
	return count

func _legacy_known_world_expected_memory_control(previous_value: Variant, hero_records: Array, target_records: Array, current_day: int) -> Dictionary:
	var previous: Dictionary = previous_value if previous_value is Dictionary else {}
	var merged_heroes := _legacy_known_world_merge_hero_records_control(previous.get("player_hero_sightings", []), hero_records, current_day)
	var merged_targets := _legacy_known_world_merge_target_records_control(previous.get("scouted_targets", []), target_records, current_day)
	if merged_heroes.is_empty() and merged_targets.is_empty():
		return {}
	var memory := {"schema_version": 1}
	if not merged_heroes.is_empty():
		memory["player_hero_sightings"] = merged_heroes
		memory["last_hero_sighting_day"] = int(merged_heroes[0].get("seen_day", current_day))
	if not merged_targets.is_empty():
		memory["scouted_targets"] = merged_targets
		memory["last_scouted_day"] = int(merged_targets[0].get("scouted_day", current_day))
	return memory

func _legacy_known_world_merge_hero_records_control(existing_value: Variant, current_value: Variant, current_day: int) -> Array:
	var by_id := {}
	for record in _legacy_known_world_normalize_hero_records_control(existing_value, current_day):
		by_id[String(record.get("hero_id", ""))] = record
	for record in _legacy_known_world_normalize_hero_records_control(current_value, current_day):
		var hero_id := String(record.get("hero_id", ""))
		if hero_id != "" and (not by_id.has(hero_id) or int(record.get("seen_day", 0)) >= int(by_id[hero_id].get("seen_day", 0))):
			by_id[hero_id] = record
	var merged := []
	for hero_id in by_id.keys():
		merged.append(by_id[hero_id])
	return _legacy_known_world_normalize_hero_records_control(merged, current_day)

func _legacy_known_world_merge_target_records_control(existing_value: Variant, current_value: Variant, current_day: int) -> Array:
	var by_key := {}
	for record in _legacy_known_world_normalize_target_records_control(existing_value, current_day):
		by_key["%s:%s" % [String(record.get("target_kind", "")), String(record.get("target_id", ""))]] = record
	for record in _legacy_known_world_normalize_target_records_control(current_value, current_day):
		var key := "%s:%s" % [String(record.get("target_kind", "")), String(record.get("target_id", ""))]
		if key != ":":
			by_key[key] = record
	var merged := []
	for key in by_key.keys():
		merged.append(by_key[key])
	return _legacy_known_world_normalize_target_records_control(merged, current_day)

func _legacy_known_world_normalize_hero_records_control(value: Variant, current_day: int) -> Array:
	var normalized := []
	if not (value is Array):
		return normalized
	for record_value in value:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var hero_id := String(record.get("hero_id", ""))
		if hero_id == "":
			continue
		var seen_day: int = max(0, int(record.get("seen_day", 0)))
		var expires_day: int = max(seen_day, int(record.get("expires_day", seen_day + EnemyAdventureRules.AI_HERO_SIGHTING_MEMORY_DAYS)))
		if current_day > 0 and expires_day < current_day:
			continue
		normalized.append({
			"hero_id": hero_id,
			"hero_label": String(record.get("hero_label", hero_id)),
			"x": int(record.get("x", 0)),
			"y": int(record.get("y", 0)),
			"army_strength": max(0, int(record.get("army_strength", 0))),
			"seen_day": seen_day,
			"expires_day": expires_day,
			"source_kind": String(record.get("source_kind", "")),
			"source_id": String(record.get("source_id", "")),
			"confidence": String(record.get("confidence", "recent")),
			"state_policy": "ai_known_world_memory",
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("seen_day", 0)) == int(b.get("seen_day", 0)):
			return String(a.get("hero_id", "")) < String(b.get("hero_id", ""))
		return int(a.get("seen_day", 0)) > int(b.get("seen_day", 0))
	)
	while normalized.size() > EnemyAdventureRules.AI_HERO_SIGHTING_MAX_RECORDS:
		normalized.pop_back()
	return normalized

func _legacy_known_world_normalize_target_records_control(value: Variant, current_day: int) -> Array:
	var normalized := []
	if not (value is Array):
		return normalized
	for record_value in value:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var target_kind := String(record.get("target_kind", ""))
		var target_id := String(record.get("target_id", ""))
		if target_kind == "" or target_id == "":
			continue
		var scouted_day: int = max(0, int(record.get("scouted_day", 0)))
		var expires_day: int = max(scouted_day, int(record.get("expires_day", scouted_day + EnemyAdventureRules.RAID_ADVENTURE_SCOUTING_MEMORY_DAYS)))
		if current_day > 0 and expires_day < current_day:
			continue
		normalized.append({
			"target_kind": target_kind,
			"target_id": target_id,
			"target_label": String(record.get("target_label", target_id)),
			"x": int(record.get("x", 0)),
			"y": int(record.get("y", 0)),
			"scouted_day": scouted_day,
			"expires_day": expires_day,
			"source_spell_id": String(record.get("source_spell_id", "")),
			"source_spell_name": String(record.get("source_spell_name", "")),
			"source_kind": String(record.get("source_kind", "")),
			"source_id": String(record.get("source_id", "")),
			"source_raid_id": String(record.get("source_raid_id", "")),
			"state_policy": "ai_known_world_memory",
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("scouted_day", 0)) == int(b.get("scouted_day", 0)):
			return String(a.get("target_label", "")) < String(b.get("target_label", ""))
		return int(a.get("scouted_day", 0)) > int(b.get("scouted_day", 0))
	)
	while normalized.size() > EnemyAdventureRules.RAID_ADVENTURE_SCOUTING_MAX_TARGET_RECORDS:
		normalized.pop_back()
	return normalized

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
