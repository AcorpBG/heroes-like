extends Node

const REPORT_ID := "AI_HERO_TASK_STRATEGIC_PLANNER_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var descriptor_projection_case := _target_descriptor_projection_parity_case()
	if descriptor_projection_case.is_empty():
		return
	var planner_case := _planner_seeds_distinct_tasks_before_spawn()
	if planner_case.is_empty():
		return
	var multi_origin_case := _planner_uses_local_origin_for_remote_front()
	if multi_origin_case.is_empty():
		return
	var personality_case := _planner_uses_commander_personality_fit()
	if personality_case.is_empty():
		return
	var global_fit_case := _planner_assigns_specialized_target_globally()
	if global_fit_case.is_empty():
		return
	var fit_context_case := _planner_fit_context_preserves_candidate_scores()
	if fit_context_case.is_empty():
		return
	var adaptive_case := _planner_uses_commander_outcome_memory()
	if adaptive_case.is_empty():
		return
	var role_adoption_case := _planner_adopts_live_commander_role_state()
	if role_adoption_case.is_empty():
		return
	var duplicate_recovery_case := _planner_recovers_duplicate_reservation_with_alternate_task()
	if duplicate_recovery_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "coordinated_task_planner_live_behavior",
		"behavior_policy": "enemy_turn_planner_seeds_distinct_commander_tasks_scores_targets_by_global_commander_identity_adaptive_outcome_memory_live_role_continuity_and_duplicate_reservation_recovery",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"descriptor_projection_case": descriptor_projection_case,
		"case": planner_case,
		"multi_origin_case": multi_origin_case,
		"personality_case": personality_case,
		"global_fit_case": global_fit_case,
		"fit_context_case": fit_context_case,
		"adaptive_case": adaptive_case,
		"role_adoption_case": role_adoption_case,
		"duplicate_recovery_case": duplicate_recovery_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _target_descriptor_projection_parity_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config().duplicate(true)
	var origins := [
		{"kind": "town", "id": "duskfen_bastion", "x": 7, "y": 2},
		{"kind": "front", "id": "remote_front", "x": 1, "y": 4},
	]
	var towns: Array = session.overworld.get("towns", []).duplicate(true)
	for index in range(towns.size()):
		var town: Dictionary = towns[index] if towns[index] is Dictionary else {}
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "neutral"
			town["controlling_faction_id"] = ""
			towns[index] = town
	session.overworld["towns"] = towns
	var resources: Array = session.overworld.get("resource_nodes", []).duplicate(true)
	var delivery_source_position := Vector2i(-1, -1)
	for index in range(resources.size()):
		var node: Dictionary = resources[index] if resources[index] is Dictionary else {}
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["collected_by_faction_id"] = "player"
		node["delivery_controller_id"] = "player"
		node["delivery_arrival_day"] = int(session.day) + 2
		node["delivery_target_kind"] = "town"
		node["delivery_target_id"] = "riverwatch_hold"
		node["delivery_target_label"] = "Riverwatch Hold"
		node["delivery_origin_town_id"] = "riverwatch_hold"
		node["delivery_manifest"] = {"unit_river_guard": 2}
		delivery_source_position = Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		resources[index] = node
	session.overworld["resource_nodes"] = resources
	if delivery_source_position == Vector2i(-1, -1):
		_fail("Descriptor fixture could not derive river_free_company live coordinates.")
		return {}
	var artifact_nodes: Array = session.overworld.get("artifact_nodes", []).duplicate(true)
	var artifact_template: Dictionary = artifact_nodes[0].duplicate(true) if not artifact_nodes.is_empty() and artifact_nodes[0] is Dictionary else {}
	artifact_template["placement_id"] = "descriptor_hidden_unreachable_artifact"
	artifact_template["x"] = 0
	artifact_template["y"] = 0
	artifact_template["collected"] = false
	artifact_nodes.append(artifact_template)
	var unreachable_artifact := artifact_template.duplicate(true)
	unreachable_artifact["placement_id"] = "descriptor_unreachable_artifact"
	unreachable_artifact["x"] = 5
	unreachable_artifact["y"] = 0
	artifact_nodes.append(unreachable_artifact)
	session.overworld["artifact_nodes"] = artifact_nodes
	var unreachable_goal := Vector2i(5, 0)
	var fixture_map: Array = session.overworld.get("map", []).duplicate(true)
	var sealed_neighbors := []
	for delta in EnemyAdventureRules.PATH_MOVEMENT_DELTAS:
		var neighbor: Vector2i = unreachable_goal + delta
		if neighbor.y < 0 or neighbor.y >= fixture_map.size():
			continue
		var map_row: Array = fixture_map[neighbor.y].duplicate(true) if fixture_map[neighbor.y] is Array else []
		if neighbor.x < 0 or neighbor.x >= map_row.size():
			continue
		map_row[neighbor.x] = "rock"
		fixture_map[neighbor.y] = map_row
		sealed_neighbors.append(neighbor)
	if sealed_neighbors.is_empty():
		_fail("Unreachable artifact fixture did not find any in-bounds movement neighbors.")
		return {}
	for neighbor in sealed_neighbors:
		var terrain_id := String(fixture_map[neighbor.y][neighbor.x])
		if OverworldRules.terrain_id_is_passable(terrain_id):
			_fail("Unreachable artifact neighbor remained passable at %s: %s" % [neighbor, terrain_id])
			return {}
	session.overworld["map"] = fixture_map
	var fixture_state := _enemy_state(session)
	var known_world_memory: Dictionary = fixture_state.get("known_world_memory", {}).duplicate(true) if fixture_state.get("known_world_memory", {}) is Dictionary else {}
	known_world_memory["schema_version"] = 1
	known_world_memory["scouted_targets"] = [{
		"target_kind": "resource",
		"target_id": "river_free_company",
		"target_label": "River Free Company Yard",
		"x": delivery_source_position.x,
		"y": delivery_source_position.y,
		"scouted_day": int(session.day),
		"expires_day": int(session.day) + 3,
		"source_kind": "descriptor_fixture",
		"source_id": "descriptor_fixture",
		"source_raid_id": "",
		"state_policy": "ai_known_world_memory",
	}]
	known_world_memory["player_hero_sightings"] = [{
		"hero_id": String(session.overworld.get("active_hero_id", "hero_lyra")),
		"hero_label": "Lyra",
		"x": int(session.overworld.get("hero_position", {}).get("x", 0)),
		"y": int(session.overworld.get("hero_position", {}).get("y", 0)),
		"army_strength": 100,
		"seen_day": int(session.day),
		"expires_day": int(session.day) + 2,
		"source_kind": "descriptor_fixture",
		"source_id": "descriptor_fixture",
	}]
	fixture_state["known_world_memory"] = known_world_memory
	_update_enemy_state(session, fixture_state)
	if not EnemyAdventureRules._enemy_target_scouted(session, MIRECLAW, "resource", "river_free_company"):
		_fail("Descriptor fixture did not establish method-matched river_free_company scouting memory.")
		return {}
	var path_context := EnemyAdventureRules._path_distance_surface_context(session, "", MIRECLAW)
	for origin_value in origins:
		var origin: Dictionary = origin_value
		var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
		if EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, [unreachable_goal]) != 9999:
			_fail("Enclosed artifact goal was reachable from origin %s." % JSON.stringify(origin))
			return {}

	var known_descriptors: Array = EnemyAdventureRules._target_candidate_descriptors(session, config, false)
	var all_descriptors: Array = EnemyAdventureRules._target_candidate_descriptors(session, config, true)
	var source_bucket_identities := _legacy_source_bucket_identities(session, config)
	var expected_source_bucket_identities := {
		"01_siege_target": ["riverwatch_hold"],
		"02_defeat_objective_towns": ["riverwatch_hold"],
		"03_victory_objective_towns": ["duskfen_bastion"],
		"04_player_towns": ["riverwatch_hold"],
		"05_neutral_towns": ["duskfen_bastion"],
		"06_resource_nodes": ["north_wood", "midway_shrine", "southern_ore", "eastern_cache", "river_signal_post", "river_free_company", "river_sanctum", "riverwatch_embergrain_granary", "duskfen_bastion_peatwax_front", "river_pass_riverwatch_hold_rare_exchange", "river_pass_duskfen_bastion_rare_exchange", "duskfen_bastion_development_source_support"],
		"07_artifact_nodes": ["trailsinger_cache", "warcrest_ruin", "quarry_tally_cache", "bastion_vault", "descriptor_hidden_unreachable_artifact", "descriptor_unreachable_artifact"],
		"08_encounters": ["river_pass_ghoul_grove", "river_pass_hollow_mire", "river_pass_reed_totemists"],
		"09_delivery_interceptions": ["river_free_company"],
		"10_known_player_heroes": ["hero_lyra"],
	}
	if JSON.stringify(source_bucket_identities) != JSON.stringify(expected_source_bucket_identities):
		_fail("Legacy source-bucket identity/order changed: actual=%s expected=%s" % [JSON.stringify(source_bucket_identities), JSON.stringify(expected_source_bucket_identities)])
		return {}
	var known_ids := _descriptor_identities(known_descriptors)
	var all_ids := _descriptor_identities(all_descriptors)
	if "artifact:descriptor_hidden_unreachable_artifact" in known_ids \
			or "artifact:descriptor_hidden_unreachable_artifact" not in all_ids:
		_fail("Descriptor known/unscouted boundary changed: known=%s all=%s" % [JSON.stringify(known_ids), JSON.stringify(all_ids)])
		return {}
	for family in ["town", "resource", "artifact", "encounter", "delivery", "hero"]:
		if not _descriptors_contain_family(all_descriptors, family):
			_fail("Descriptor fixture is missing ordered family %s: %s" % [family, JSON.stringify(all_ids)])
			return {}
	var siege_descriptor := _descriptor_for_identity(all_descriptors, "town", "riverwatch_hold")
	var victory_descriptor := _descriptor_for_identity(all_descriptors, "town", "duskfen_bastion")
	if int(siege_descriptor.get("priority", -1)) != 320 or int(victory_descriptor.get("priority", -1)) != 220:
		_fail("Earlier siege/victory discovery did not retain duplicate-seen priority: siege=%s victory=%s" % [JSON.stringify(siege_descriptor), JSON.stringify(victory_descriptor)])
		return {}
	var defeat_config := config.duplicate(true)
	defeat_config["siege_target_placement_id"] = ""
	var defeat_descriptors: Array = EnemyAdventureRules._target_candidate_descriptors(session, defeat_config, true)
	if int(_descriptor_for_identity(defeat_descriptors, "town", "riverwatch_hold").get("priority", -1)) != 260:
		_fail("Defeat-objective town did not claim the player-town duplicate at discovery time.")
		return {}

	for include_unscouted in [false, true]:
		var descriptors: Array = known_descriptors if not include_unscouted else all_descriptors
		for origin_value in origins:
			var origin: Dictionary = origin_value
			var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
			var wrapper: Array = _legacy_target_candidates_control(session, config, origin_pos, include_unscouted, path_context)
			var projected: Array = EnemyAdventureRules._target_candidates_from_descriptors(session, config, origin_pos, descriptors, path_context)
			if JSON.stringify(wrapper) != JSON.stringify(projected):
				_fail("Descriptor projection changed ordered candidate payload at %s include_unscouted=%s: wrapper=%s projected=%s" % [JSON.stringify(origin), include_unscouted, JSON.stringify(wrapper), JSON.stringify(projected)])
				return {}
	if _descriptor_for_identity(all_descriptors, "artifact", "descriptor_unreachable_artifact").is_empty():
		_fail("Enclosed artifact was incorrectly filtered from descriptor discovery.")
		return {}
	for origin_value in origins:
		var origin: Dictionary = origin_value
		var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
		var unreachable_projected: Array = EnemyAdventureRules._target_candidates_from_descriptors(session, config, origin_pos, all_descriptors, path_context)
		if _candidate_has_target(unreachable_projected, "artifact", "descriptor_unreachable_artifact"):
			_fail("Enclosed unreachable artifact survived fresh projection from origin %s." % JSON.stringify(origin))
			return {}
	var guarded_descriptor := _descriptor_for_identity(all_descriptors, "resource", "river_pass_riverwatch_hold_rare_exchange")
	if guarded_descriptor.is_empty():
		_fail("Guarded resource source was lost before origin-specific guard projection.")
		return {}

	var planner_profile := {}
	var projected_planner: Array = EnemyAdventureRules._ai_hero_task_planner_candidates_from_origins(
		session,
		config,
		origins,
		known_descriptors,
		planner_profile
	)
	var wrapper_planner: Array = _legacy_planner_candidates_from_origins_control(session, config, origins)
	if JSON.stringify(projected_planner) != JSON.stringify(wrapper_planner):
		_fail("Multi-origin planner changed whole ordered candidate payload under descriptor injection.")
		return {}
	if int(planner_profile.get("enumeration_count", 0)) != 0 \
			or int(planner_profile.get("projection_count", 0)) != origins.size():
		_fail("Preloaded planner did not separate enumeration and projection counters: %s" % JSON.stringify(planner_profile))
		return {}
	var planner_session = _base_session()
	var legacy_planner_session = _base_session()
	var public_plan := EnemyAdventureRules.plan_enemy_hero_task_board(planner_session, config, _enemy_state(planner_session))
	var legacy_public_plan := _legacy_plan_enemy_hero_task_board_control(legacy_planner_session, config, _enemy_state(legacy_planner_session))
	var selected_tasks := _planned_tasks(public_plan.get("state", {}) if public_plan.get("state", {}) is Dictionary else {})
	var legacy_selected_tasks := _planned_tasks(legacy_public_plan.get("state", {}) if legacy_public_plan.get("state", {}) is Dictionary else {})
	if JSON.stringify(selected_tasks) != JSON.stringify(legacy_selected_tasks):
		_fail("Descriptor planner changed selected task payload/order versus independent legacy materialization: current=%s legacy=%s" % [JSON.stringify(selected_tasks), JSON.stringify(legacy_selected_tasks)])
		return {}
	var public_profile: Dictionary = public_plan.get("target_descriptor_profile", {}) if public_plan.get("target_descriptor_profile", {}) is Dictionary else {}
	if int(public_profile.get("enumeration_count", 0)) != 1 \
			or int(public_profile.get("projection_count", 0)) <= 1 \
			or int(public_profile.get("descriptor_count", 0)) <= 0:
		_fail("Planner invocation did not enumerate once and project multiple origins: %s" % JSON.stringify(public_profile))
		return {}

	var detached_json := JSON.stringify(all_descriptors)
	resources = session.overworld.get("resource_nodes", []).duplicate(true)
	for index in range(resources.size()):
		var node: Dictionary = resources[index] if resources[index] is Dictionary else {}
		if String(node.get("placement_id", "")) == "river_free_company":
			node["x"] = int(node.get("x", 0)) + 1
			resources[index] = node
	session.overworld["resource_nodes"] = resources
	if JSON.stringify(all_descriptors) != detached_json:
		_fail("Detached descriptor payload aliased a later live source mutation.")
		return {}
	var rebuilt_descriptors: Array = EnemyAdventureRules._target_candidate_descriptors(session, config, true)
	if JSON.stringify(rebuilt_descriptors) == detached_json:
		_fail("A new descriptor invocation did not rebuild after a live source mutation.")
		return {}
	var rebuilt_wrapper: Array = _legacy_target_candidates_control(session, config, Vector2i(7, 2), true)
	var rebuilt_projection: Array = EnemyAdventureRules._target_candidates_from_descriptors(session, config, Vector2i(7, 2), rebuilt_descriptors)
	if JSON.stringify(rebuilt_wrapper) != JSON.stringify(rebuilt_projection):
		_fail("Rebuilt descriptors changed post-mutation wrapper parity.")
		return {}
	return {
		"case_id": "ordered_target_descriptors_preserve_wrapper_and_multi_origin_projection",
		"source_bucket_identities": source_bucket_identities,
		"descriptor_families": ["town", "resource", "artifact", "encounter", "delivery", "hero"],
		"known_descriptor_count": known_descriptors.size(),
		"all_descriptor_count": all_descriptors.size(),
		"planner_profile": public_profile,
		"preloaded_projection_profile": planner_profile,
		"selected_tasks": selected_tasks,
		"whole_ordered_payload_parity": true,
		"descriptor_deep_detach": true,
		"new_invocation_rebuilt_after_mutation": true,
	}

func _descriptor_identities(descriptors: Array) -> Array:
	var identities := []
	for descriptor_value in descriptors:
		if not (descriptor_value is Dictionary):
			continue
		var descriptor: Dictionary = descriptor_value
		var family := String(descriptor.get("family", ""))
		var identity := String(descriptor.get("placement_id", ""))
		if family == "delivery":
			identity = String((descriptor.get("node", {}) as Dictionary).get("placement_id", ""))
		elif family == "hero":
			identity = String((descriptor.get("hero", {}) as Dictionary).get("id", ""))
		identities.append("%s:%s" % [family, identity])
	return identities

func _descriptors_contain_family(descriptors: Array, family: String) -> bool:
	for descriptor_value in descriptors:
		if descriptor_value is Dictionary and String(descriptor_value.get("family", "")) == family:
			return true
	return false

func _descriptor_for_identity(descriptors: Array, family: String, identity: String) -> Dictionary:
	for descriptor_value in descriptors:
		if not (descriptor_value is Dictionary):
			continue
		var descriptor: Dictionary = descriptor_value
		if String(descriptor.get("family", "")) != family:
			continue
		var descriptor_identity := String(descriptor.get("placement_id", ""))
		if family == "delivery":
			descriptor_identity = String((descriptor.get("node", {}) as Dictionary).get("placement_id", ""))
		elif family == "hero":
			descriptor_identity = String((descriptor.get("hero", {}) as Dictionary).get("id", ""))
		if descriptor_identity == identity:
			return descriptor
	return {}

func _candidate_has_target(candidates: Array, kind: String, identity: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary \
				and String(candidate_value.get("target_kind", "")) == kind \
				and String(candidate_value.get("target_placement_id", "")) == identity:
			return true
	return false

func _legacy_source_bucket_identities(session, config: Dictionary) -> Dictionary:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	var buckets := {
		"01_siege_target": [],
		"02_defeat_objective_towns": [],
		"03_victory_objective_towns": [],
		"04_player_towns": [],
		"05_neutral_towns": [],
		"06_resource_nodes": [],
		"07_artifact_nodes": [],
		"08_encounters": [],
		"09_delivery_interceptions": [],
		"10_known_player_heroes": [],
	}
	var siege_target_id := String(config.get("siege_target_placement_id", ""))
	if siege_target_id != "":
		buckets["01_siege_target"].append(siege_target_id)
	for objective_value in objectives.get("defeat", []):
		if objective_value is Dictionary and String(objective_value.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
			buckets["02_defeat_objective_towns"].append(String(objective_value.get("placement_id", "")))
	for objective_value in objectives.get("victory", []):
		if objective_value is Dictionary and String(objective_value.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
			buckets["03_victory_objective_towns"].append(String(objective_value.get("placement_id", "")))
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "neutral")) == "player":
			buckets["04_player_towns"].append(String(town_value.get("placement_id", "")))
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "neutral")) == "neutral":
			buckets["05_neutral_towns"].append(String(town_value.get("placement_id", "")))
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		buckets["06_resource_nodes"].append(String(node_value.get("placement_id", "")))
		var site: Dictionary = ContentService.get_resource_site(String(node_value.get("site_id", "")))
		var delivery_state: Dictionary = OverworldRules._resource_site_delivery_state(session, node_value, site)
		if bool(delivery_state.get("active", false)) and String(delivery_state.get("controller_id", "")) == "player":
			buckets["09_delivery_interceptions"].append(String(node_value.get("placement_id", "")))
	for node_value in session.overworld.get("artifact_nodes", []):
		if node_value is Dictionary:
			buckets["07_artifact_nodes"].append(String(node_value.get("placement_id", "")))
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary:
			buckets["08_encounters"].append(String(encounter_value.get("placement_id", "")))
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var known_hero := EnemyAdventureRules._known_player_hero_snapshot_for_ai(session, String(config.get("faction_id", "")), hero_value)
		if not known_hero.is_empty():
			buckets["10_known_player_heroes"].append(String(known_hero.get("id", "")))
	return buckets

func _legacy_plan_enemy_hero_task_board_control(
	session: Variant,
	config: Dictionary,
	state: Dictionary = {}
) -> Dictionary:
	if session == null or config.is_empty():
		return {"state": state, "planned_count": 0, "task_count": 0}
	var faction_id := String(config.get("faction_id", state.get("faction_id", "")))
	if faction_id == "":
		return {"state": state, "planned_count": 0, "task_count": 0}
	var working_state := state.duplicate(true) if not state.is_empty() else EnemyAdventureRules._ai_hero_task_enemy_state_for_faction(session, faction_id).duplicate(true)
	if working_state.is_empty():
		return {"state": state, "planned_count": 0, "task_count": 0}
	var origins := EnemyAdventureRules._ai_hero_task_planner_origins(session, config, faction_id)
	if origins.is_empty():
		return {"state": working_state, "planned_count": 0, "task_count": 0}

	EnemyAdventureRules._ai_hero_task_reconcile_live_tasks_for_faction(session, faction_id)
	var reconciled_state := EnemyAdventureRules._ai_hero_task_enemy_state_for_faction(session, faction_id)
	if reconciled_state.get("hero_task_state", {}) is Dictionary:
		working_state["hero_task_state"] = reconciled_state.get("hero_task_state", {}).duplicate(true)
	var roster := EnemyAdventureRules.normalize_commander_roster(
		session,
		faction_id,
		working_state.get("commander_roster", EnemyAdventureRules.commander_roster_for_faction(session, faction_id))
	)
	if roster.is_empty():
		return {"state": working_state, "planned_count": 0, "task_count": 0}
	working_state["commander_roster"] = roster

	var task_state: Dictionary = working_state.get("hero_task_state", {}) if working_state.get("hero_task_state", {}) is Dictionary else {}
	var existing_tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var next_tasks := []
	for task_value in existing_tasks:
		if task_value is Dictionary:
			next_tasks.append(task_value)
	var reservation_recovered_tasks := EnemyAdventureRules.ai_hero_task_apply_reservations(next_tasks)
	var reservation_recovery_changed := JSON.stringify(next_tasks) != JSON.stringify(reservation_recovered_tasks)
	next_tasks = reservation_recovered_tasks

	if not EnemyAdventureRules._ai_hero_task_planner_has_assignable_actor(roster, next_tasks):
		working_state["hero_task_state"] = {
			"schema_version": 1,
			"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))) + (1 if reservation_recovery_changed else 0),
			"tasks": EnemyAdventureRules._ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
		}
		EnemyAdventureRules._ai_hero_task_write_enemy_state_for_faction(session, faction_id, working_state)
		return {
			"state": working_state,
			"planned_count": 0,
			"task_count": working_state.get("hero_task_state", {}).get("tasks", []).size() if working_state.get("hero_task_state", {}) is Dictionary else next_tasks.size(),
			"events": [],
		}

	var candidates := _legacy_planner_candidates_from_origins_control(session, config, origins)
	var target_claims := EnemyAdventureRules._ai_hero_task_planner_target_claims(next_tasks)
	var planned_count := 0
	var events := []
	var assigned_tasks := EnemyAdventureRules._ai_hero_task_planner_global_task_assignments(
		session,
		config,
		faction_id,
		roster,
		origins[0],
		candidates,
		target_claims,
		next_tasks,
		next_tasks.size() + 1
	)
	for task_value in assigned_tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		next_tasks.append(task)
		roster = EnemyAdventureRules._adopt_commander_role_on_roster(roster, faction_id, task, "strategic_planner")
		working_state["commander_roster"] = roster
		var event := EnemyAdventureRules._ai_hero_task_planner_event(session, config, task)
		if not event.is_empty():
			events.append(event)
		var reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
		var reservation_key := String(reservation.get("reservation_key", ""))
		if reservation_key != "":
			target_claims[reservation_key] = true
		planned_count += 1
	if planned_count <= 0 and not reservation_recovery_changed:
		working_state["hero_task_state"] = {
			"schema_version": 1,
			"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))),
			"tasks": EnemyAdventureRules._ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
		}
		EnemyAdventureRules._ai_hero_task_write_enemy_state_for_faction(session, faction_id, working_state)
		return {"state": working_state, "planned_count": 0, "task_count": next_tasks.size(), "events": []}
	working_state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))) + (1 if planned_count > 0 or reservation_recovery_changed else 0),
		"tasks": EnemyAdventureRules._ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
	}
	EnemyAdventureRules._ai_hero_task_write_enemy_state_for_faction(session, faction_id, working_state)
	return {
		"state": working_state,
		"planned_count": planned_count,
		"task_count": working_state.get("hero_task_state", {}).get("tasks", []).size() if working_state.get("hero_task_state", {}) is Dictionary else next_tasks.size(),
		"events": events,
	}

func _legacy_planner_candidates_from_origins_control(
	session: Variant,
	config: Dictionary,
	origins: Array
) -> Array:
	var best_by_target := {}
	var exploration_by_target := {}
	var path_context := EnemyAdventureRules._path_distance_surface_context(
		session,
		"",
		String(config.get("faction_id", ""))
	)
	for origin_value in origins:
		if not (origin_value is Dictionary):
			continue
		var origin: Dictionary = origin_value
		var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
		var origin_candidates := _legacy_target_candidates_control(session, config, origin_pos, false, path_context)
		if origin_candidates.is_empty():
			var exploration_plan := EnemyAdventureRules._no_known_target_exploration_plan(session, config, origin_pos)
			if not exploration_plan.is_empty():
				var exploration_key := "%s:%s" % [
					String(exploration_plan.get("target_kind", "")),
					String(exploration_plan.get("target_placement_id", "")),
				]
				var exploration_with_origin := exploration_plan.duplicate(true)
				exploration_with_origin["planner_origin"] = origin.duplicate(true)
				if (
					not exploration_by_target.has(exploration_key)
					or EnemyAdventureRules._candidate_beats(exploration_with_origin, exploration_by_target.get(exploration_key, {}))
				):
					exploration_by_target[exploration_key] = exploration_with_origin
			continue
		for candidate_value in origin_candidates:
			if not (candidate_value is Dictionary):
				continue
			var candidate: Dictionary = candidate_value
			var target_kind := String(candidate.get("target_kind", ""))
			var target_id := String(candidate.get("target_placement_id", ""))
			if target_kind == "" or target_id == "":
				continue
			var key := "%s:%s" % [target_kind, target_id]
			var candidate_with_origin := candidate.duplicate(true)
			candidate_with_origin["planner_origin"] = origin.duplicate(true)
			if (
				not best_by_target.has(key)
				or EnemyAdventureRules._candidate_beats(candidate_with_origin, best_by_target.get(key, {}))
			):
				best_by_target[key] = candidate_with_origin
	if best_by_target.is_empty():
		for key in exploration_by_target.keys():
			best_by_target[key] = exploration_by_target[key]
	var output := []
	for candidate_value in best_by_target.values():
		if candidate_value is Dictionary:
			output.append(candidate_value)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return EnemyAdventureRules._candidate_beats(a, b)
	)
	return output

func _legacy_target_candidates_control(
	session: Variant,
	config: Dictionary,
	origin_pos: Vector2i,
	include_unscouted: bool = false,
	preloaded_path_context: Dictionary = {}
) -> Array:
	var seen = {}
	var candidates = []
	var faction_id = String(config.get("faction_id", ""))
	var path_context := preloaded_path_context
	if path_context.is_empty():
		path_context = EnemyAdventureRules._path_distance_surface_context(session, "", faction_id)
	var scenario = ContentService.get_scenario(session.scenario_id)
	var siege_target_id = String(config.get("siege_target_placement_id", ""))
	if siege_target_id != "":
		_legacy_append_town_candidate(session, candidates, seen, siege_target_id, origin_pos, 320, config, faction_id, include_unscouted, path_context)

	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		for objective in objectives.get("defeat", []):
			if objective is Dictionary and String(objective.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
				_legacy_append_town_candidate(session, candidates, seen, String(objective.get("placement_id", "")), origin_pos, 260, config, faction_id, include_unscouted, path_context)
		for objective in objectives.get("victory", []):
			if objective is Dictionary and String(objective.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
				_legacy_append_town_candidate(session, candidates, seen, String(objective.get("placement_id", "")), origin_pos, 220, config, faction_id, include_unscouted, path_context)

	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "player":
			continue
		var base_priority = 180
		if EnemyAdventureRules._town_started_enemy(session, String(town.get("placement_id", ""))):
			base_priority += 50
		if EnemyAdventureRules._town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			base_priority += 20
		_legacy_append_town_candidate(session, candidates, seen, String(town.get("placement_id", "")), origin_pos, base_priority, config, faction_id, include_unscouted, path_context)
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "neutral":
			continue
		var base_priority = 145
		if EnemyAdventureRules._town_garrison_strength(town) > 0:
			base_priority += 25
		if EnemyAdventureRules._town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			base_priority += 45
		_legacy_append_town_candidate(session, candidates, seen, String(town.get("placement_id", "")), origin_pos, base_priority, config, faction_id, include_unscouted, path_context)

	for node in session.overworld.get("resource_nodes", []):
		_legacy_append_resource_candidate(
			session,
			candidates,
			seen,
			node,
			origin_pos,
			config,
			faction_id,
			include_unscouted,
			path_context
		)

	for node in session.overworld.get("artifact_nodes", []):
		_legacy_append_artifact_candidate(
			session,
			candidates,
			seen,
			node,
			origin_pos,
			EnemyAdventureRules._artifact_target_priority(session, node),
			config,
			faction_id,
			include_unscouted,
			path_context
		)

	for encounter in session.overworld.get("encounters", []):
		_legacy_append_encounter_candidate(
			session,
			candidates,
			seen,
			encounter,
			origin_pos,
			EnemyAdventureRules._encounter_target_priority(session, encounter),
			config,
			faction_id,
			include_unscouted,
			path_context
		)

	_legacy_append_delivery_interception_candidates(session, candidates, seen, origin_pos, config, faction_id)

	var hero_candidates = _legacy_hero_target_candidates(session, origin_pos, config, faction_id)
	for hero_candidate in hero_candidates:
		if hero_candidate is Dictionary and not hero_candidate.is_empty():
			candidates.append(hero_candidate)
	return candidates

func _legacy_append_town_candidate(
	session: Variant,
	candidates: Array,
	seen: Dictionary,
	placement_id: String,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String,
	include_unscouted: bool = false,
	path_context: Dictionary = {}
) -> void:
	var seen_key = "town:%s" % placement_id
	if placement_id == "" or seen.has(seen_key):
		return
	var town_result = EnemyAdventureRules._find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return
	var town = town_result.get("town", {})
	var owner := String(town.get("owner", "neutral"))
	var neutral_expansion := owner == "neutral"
	if owner != "player" and not neutral_expansion:
		return
	var objective_anchor := EnemyAdventureRules._town_is_objective_anchor(session, placement_id)
	var force_known := EnemyAdventureRules.priority_target_bonus(config, placement_id) > 0 or objective_anchor
	if neutral_expansion and not include_unscouted and not EnemyAdventureRules._enemy_nonhero_target_known(
		session,
		config,
		faction_id,
		"town",
		placement_id,
		int(town.get("x", 0)),
		int(town.get("y", 0)),
		force_known
	):
		return

	seen[seen_key] = true
	var staging_tiles = EnemyAdventureRules._town_staging_tiles(session, town)
	var goal_tile = EnemyAdventureRules._best_goal_tile_with_path_context(path_context, origin_pos, staging_tiles)
	var goal_distance = EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, staging_tiles)
	if goal_distance >= 9999:
		return
	var strategic_bonus = EnemyAdventureRules._town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	var reason_codes := ["town_expansion", "neutral_town_claim"] if neutral_expansion else ["town_siege"]
	if neutral_expansion and EnemyAdventureRules._town_garrison_strength(town) > 0:
		reason_codes.append("neutral_town_siege")
	if objective_anchor and "objective_front" not in reason_codes:
		reason_codes.append("objective_front")
	var scouting_bonus := EnemyAdventureRules._enemy_scouted_target_priority_bonus(session, faction_id, "town", placement_id)
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	candidates.append(
		{
			"target_kind": "town",
			"target_placement_id": placement_id,
			"target_label": EnemyAdventureRules._town_name(town),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				EnemyAdventureRules._weighted_priority(
					config,
					faction_id,
					"town",
					placement_id,
					priority + strategic_bonus + scouting_bonus,
					"",
					objective_anchor
				) - EnemyAdventureRules._assignment_penalty(session, "town", placement_id)
			),
			"target_reason_codes": reason_codes,
			"target_public_reason": (
				"neutral town expansion"
				if neutral_expansion
				else "town siege remains the main front" if placement_id == String(config.get("siege_target_placement_id", ""))
				else "town front pressure"
			),
			"target_debug_reason": (
				(
					"reachable defended neutral town expansion"
					if EnemyAdventureRules._town_garrison_strength(town) > 0
					else "reachable empty neutral town expansion"
				)
				if neutral_expansion
				else "town siege and objective pressure" if objective_anchor
				else "town siege pressure"
			),
			"target_public_importance": "high" if neutral_expansion else "critical" if objective_anchor or placement_id == String(config.get("siege_target_placement_id", "")) else "high",
		}
	)

func _legacy_append_resource_candidate(
	session: Variant,
	candidates: Array,
	seen: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	include_unscouted: bool = false,
	path_context: Dictionary = {}
) -> void:
	if not (node is Dictionary):
		return
	var placement_id = String(node.get("placement_id", ""))
	var seen_key = "resource:%s" % placement_id
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if placement_id == "" or seen.has(seen_key) or not EnemyAdventureRules._resource_node_contestable_by_faction(node, site, faction_id):
		return
	var goal_tile := EnemyAdventureRules._resource_interaction_tile(node)
	var force_known := EnemyAdventureRules.priority_target_bonus(config, placement_id) > 0 \
		or EnemyAdventureRules.target_is_objective_anchor(session, "resource", placement_id)
	if not include_unscouted and not EnemyAdventureRules._enemy_nonhero_target_known(
		session,
		config,
		faction_id,
		"resource",
		placement_id,
		goal_tile.x,
		goal_tile.y,
		force_known
	):
		return
	seen[seen_key] = true
	var goal_distance = EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, [goal_tile])
	if goal_distance >= 9999:
		return
	var guard := EnemyAdventureRules._resource_guard_encounter_for_node(session, node, site)
	if not guard.is_empty():
		var guard_distance := EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, EnemyAdventureRules._encounter_staging_tiles(session, guard))
		if guard_distance >= 9999:
			return
	var anchor_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var anchor_distance := EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, [anchor_tile])
	var score_distance: int = anchor_distance if anchor_distance < 9999 else goal_distance
	var breakdown := EnemyAdventureRules.resource_target_score_breakdown(session, config, node, origin_pos, faction_id, score_distance)
	var scouting_bonus := EnemyAdventureRules._enemy_scouted_target_priority_bonus(session, faction_id, "resource", placement_id)
	var priority := int(breakdown.get("final_priority", 0)) + scouting_bonus
	var reason_codes: Array = EnemyAdventureRules._normalize_string_array(breakdown.get("reason_codes", []))
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	candidates.append(
		{
			"target_kind": "resource",
			"target_placement_id": placement_id,
			"target_label": String(site.get("name", "Resource Site")),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": priority,
			"site_family": String(site.get("family", "")),
			"target_debug_reason": String(breakdown.get("debug_reason", "")),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(breakdown.get("public_reason", "")),
			"target_public_importance": String(breakdown.get("public_importance", "low")),
		}
	)

func _legacy_append_artifact_candidate(
	session: Variant,
	candidates: Array,
	seen: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String,
	include_unscouted: bool = false,
	path_context: Dictionary = {}
) -> void:
	if not (node is Dictionary):
		return
	var placement_id = String(node.get("placement_id", ""))
	var seen_key = "artifact:%s" % placement_id
	if placement_id == "" or seen.has(seen_key) or bool(node.get("collected", false)):
		return
	var goal_tile = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var force_known := EnemyAdventureRules.priority_target_bonus(config, placement_id) > 0 \
		or EnemyAdventureRules.target_is_objective_anchor(session, "artifact", placement_id)
	if not include_unscouted and not EnemyAdventureRules._enemy_nonhero_target_known(
		session,
		config,
		faction_id,
		"artifact",
		placement_id,
		goal_tile.x,
		goal_tile.y,
		force_known
	):
		return
	seen[seen_key] = true
	var goal_distance = EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, [goal_tile])
	if goal_distance >= 9999:
		return
	var guard := EnemyAdventureRules._artifact_guard_encounter_for_node(session, node)
	if not guard.is_empty():
		var guard_distance := EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, EnemyAdventureRules._encounter_staging_tiles(session, guard))
		if guard_distance >= 9999:
			return
	var breakdown := EnemyAdventureRules.artifact_target_valuation_breakdown(session, config, node, origin_pos, faction_id, goal_distance)
	var scouting_bonus := EnemyAdventureRules._enemy_scouted_target_priority_bonus(session, faction_id, "artifact", placement_id)
	var reason_codes: Array = EnemyAdventureRules._normalize_string_array(breakdown.get("reason_codes", []))
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	candidates.append(
		{
			"target_kind": "artifact",
			"target_placement_id": placement_id,
			"target_label": ArtifactRules.describe_artifact(String(node.get("artifact_id", ""))),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				EnemyAdventureRules._weighted_priority(
					config,
					faction_id,
					"artifact",
					placement_id,
					priority + scouting_bonus,
					"",
					false
				) - EnemyAdventureRules._assignment_penalty(session, "artifact", placement_id)
			),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(breakdown.get("public_reason", "")),
			"target_public_importance": String(breakdown.get("public_importance", "medium")),
		}
	)

func _legacy_append_encounter_candidate(
	session: Variant,
	candidates: Array,
	seen: Dictionary,
	encounter: Variant,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String,
	include_unscouted: bool = false,
	path_context: Dictionary = {}
) -> void:
	if not (encounter is Dictionary):
		return
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	if EnemyAdventureRules._encounter_is_pressure_host_candidate(encounter, faction_id, resolved_encounters):
		return
	if OverworldRules.is_encounter_resolved(session, encounter):
		return
	var placement_id = String(encounter.get("placement_id", ""))
	var seen_key = "encounter:%s" % placement_id
	if placement_id == "" or seen.has(seen_key):
		return
	var priority_bonus := EnemyAdventureRules.priority_target_bonus(config, placement_id)
	var objective_anchor = EnemyAdventureRules._encounter_is_objective_anchor(session, encounter)
	if not include_unscouted and not EnemyAdventureRules._enemy_nonhero_target_known(
		session,
		config,
		faction_id,
		"encounter",
		placement_id,
		int(encounter.get("x", 0)),
		int(encounter.get("y", 0)),
		priority_bonus > 0 or objective_anchor
	):
		return
	seen[seen_key] = true
	var staging_tiles = EnemyAdventureRules._encounter_staging_tiles(session, encounter)
	var goal_distance = EnemyAdventureRules._path_distance_with_context(path_context, origin_pos, staging_tiles)
	var goal_tile = EnemyAdventureRules._best_goal_tile_with_path_context(path_context, origin_pos, staging_tiles)
	if goal_distance >= 9999 and priority_bonus > 0:
		var encounter_tile := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		var direct_distance: int = abs(origin_pos.x - encounter_tile.x) + abs(origin_pos.y - encounter_tile.y)
		if direct_distance <= 3:
			goal_distance = direct_distance
			goal_tile = encounter_tile
	if goal_distance >= 9999:
		return
	var object_breakdown := EnemyAdventureRules.neutral_encounter_object_valuation_breakdown(session, config, encounter, origin_pos, faction_id)
	var reason_codes: Array = EnemyAdventureRules._normalize_string_array(object_breakdown.get("reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = EnemyAdventureRules._default_reason_codes_for_target("encounter", placement_id, {"objective_anchor": objective_anchor})
	if priority_bonus > 0 and "objective_front" not in reason_codes:
		reason_codes.append("objective_front")
	var scouting_bonus := EnemyAdventureRules._enemy_scouted_target_priority_bonus(session, faction_id, "encounter", placement_id)
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	var public_reason := String(object_breakdown.get("public_reason", ""))
	if public_reason == "":
		public_reason = EnemyAdventureRules._public_reason_from_codes(reason_codes)
	var public_importance := String(object_breakdown.get("public_importance", EnemyAdventureRules._default_public_importance("encounter", reason_codes)))
	var debug_reason := String(object_breakdown.get("debug_reason", "neutral encounter pressure"))
	var metadata_priority := int(object_breakdown.get("object_metadata_value", 0))
	candidates.append(
		{
			"target_kind": "encounter",
			"target_placement_id": placement_id,
			"target_label": EnemyAdventureRules._encounter_target_label(session, encounter, "Frontier Camp"),
			"target_x": int(encounter.get("x", 0)),
			"target_y": int(encounter.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				EnemyAdventureRules._weighted_priority(
					config,
					faction_id,
					"encounter",
					placement_id,
					priority + metadata_priority + scouting_bonus,
					"",
					objective_anchor
				) - EnemyAdventureRules._assignment_penalty(session, "encounter", placement_id)
			),
			"target_debug_reason": debug_reason,
			"target_reason_codes": reason_codes,
			"target_public_reason": public_reason,
			"target_public_importance": public_importance,
		}
	)

func _legacy_append_delivery_interception_candidates(
	session: Variant,
	candidates: Array,
	seen: Dictionary,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> void:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var placement_id := String(node.get("placement_id", ""))
		var seen_key := "delivery:%s" % placement_id
		if placement_id == "" or seen.has(seen_key):
			continue
		var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = OverworldRules._resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		if not EnemyAdventureRules._enemy_nonhero_target_known(
			session,
			config,
			faction_id,
			"resource",
			placement_id,
			int(node.get("x", 0)),
			int(node.get("y", 0))
		):
			continue
		seen[seen_key] = true
		match String(delivery_state.get("target_kind", "")):
			"town":
				var town_candidate: Dictionary = _legacy_delivery_town_candidate(session, origin_pos, config, faction_id, node, site, delivery_state)
				if not town_candidate.is_empty():
					candidates.append(town_candidate)
			"hero":
				var hero_candidate: Dictionary = _legacy_delivery_hero_candidate(session, origin_pos, config, faction_id, node, site, delivery_state)
				if not hero_candidate.is_empty():
					candidates.append(hero_candidate)

func _legacy_delivery_town_candidate(
	session: Variant,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	node: Dictionary,
	site: Dictionary,
	delivery_state: Dictionary
) -> Dictionary:
	var town_result = EnemyAdventureRules._find_town_by_placement(session, String(delivery_state.get("target_id", "")))
	if int(town_result.get("index", -1)) < 0:
		return {}
	var town: Dictionary = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return {}
	var objective_anchor := EnemyAdventureRules._town_is_objective_anchor(session, String(town.get("placement_id", "")))
	if not EnemyAdventureRules._enemy_nonhero_target_known(
		session,
		config,
		faction_id,
		"town",
		String(town.get("placement_id", "")),
		int(town.get("x", 0)),
		int(town.get("y", 0)),
		objective_anchor
	):
		return {}
	var staging_tiles = EnemyAdventureRules._town_staging_tiles(session, town)
	var goal_distance = EnemyAdventureRules._path_distance(session, origin_pos, staging_tiles, "", faction_id)
	if goal_distance >= 9999:
		return {}
	var goal_tile = EnemyAdventureRules._best_goal_tile(session, origin_pos, staging_tiles, faction_id)
	var logistics: Dictionary = OverworldRules.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRules.town_recovery_state(session, town)
	var capital_project: Dictionary = OverworldRules.town_capital_project_state(town, session)
	var priority = 210 + int(min(180.0, float(int(delivery_state.get("manifest_value", 0))) / 9.0))
	priority += int(max(0, 3 - int(delivery_state.get("days_remaining", 0)))) * 24
	priority += EnemyAdventureRules._town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	priority += int(logistics.get("support_gap", 0)) * 18
	priority += int(logistics.get("delivery_count", 0)) * 12
	priority += int(recovery.get("pressure", 0)) * 12
	if bool(capital_project.get("vulnerable", false)):
		priority += 26
	return {
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"target_label": "%s relief lane" % EnemyAdventureRules._town_name(town),
		"target_x": int(town.get("x", 0)),
		"target_y": int(town.get("y", 0)),
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(
			0,
			EnemyAdventureRules._weighted_priority(
				config,
				faction_id,
				"town",
				String(town.get("placement_id", "")),
				priority,
				"",
				objective_anchor
			) - EnemyAdventureRules._assignment_penalty(session, "town", String(town.get("placement_id", "")))
		),
		"delivery_intercept_node_placement_id": String(node.get("placement_id", "")),
		"delivery_intercept_target_kind": "town",
		"delivery_intercept_target_id": String(town.get("placement_id", "")),
		"delivery_intercept_label": "%s convoy to %s" % [
			String(site.get("name", "Frontier route")),
			String(delivery_state.get("target_label", EnemyAdventureRules._town_name(town))),
		],
	}

func _legacy_delivery_hero_candidate(
	session: Variant,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	node: Dictionary,
	site: Dictionary,
	delivery_state: Dictionary
) -> Dictionary:
	var hero: Dictionary = EnemyAdventureRules._find_player_hero(session, String(delivery_state.get("target_id", "")))
	if hero.is_empty():
		return {}
	hero = EnemyAdventureRules._known_player_hero_snapshot_for_ai(session, faction_id, hero)
	if hero.is_empty():
		return {}
	var goal_tile := EnemyAdventureRules._player_hero_goal_tile(hero)
	var goal_distance = EnemyAdventureRules._hero_target_goal_distance(session, origin_pos, goal_tile, faction_id)
	if goal_distance >= 9999:
		return {}
	var priority = 195 + int(min(170.0, float(int(delivery_state.get("manifest_value", 0))) / 10.0))
	priority += int(max(0, 3 - int(delivery_state.get("days_remaining", 0)))) * 22
	if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
		priority += 28
	if bool(hero.get("is_primary", false)):
		priority += 20
	var hero_strength: int = EnemyAdventureRules._known_player_hero_strength(hero)
	if hero_strength <= 110:
		priority += 34
	elif hero_strength <= 180:
		priority += 18
	return {
		"target_kind": "hero",
		"target_placement_id": String(hero.get("id", "")),
		"target_label": "%s convoy" % String(hero.get("name", "the hero")),
		"target_x": goal_tile.x,
		"target_y": goal_tile.y,
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(
			0,
			EnemyAdventureRules._weighted_priority(
				config,
				faction_id,
				"hero",
				String(hero.get("id", "")),
				priority,
				"",
				false
			) - EnemyAdventureRules._assignment_penalty(session, "hero", String(hero.get("id", "")))
		),
		"delivery_intercept_node_placement_id": String(node.get("placement_id", "")),
		"delivery_intercept_target_kind": "hero",
		"delivery_intercept_target_id": String(hero.get("id", "")),
		"delivery_intercept_label": "%s convoy to %s" % [
			String(site.get("name", "Frontier route")),
			String(hero.get("name", "the hero")),
		],
	}

func _legacy_hero_target_candidates(
	session: Variant,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> Array:
	var candidates := []
	var seen_hero_ids := {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = EnemyAdventureRules._known_player_hero_snapshot_for_ai(session, faction_id, hero_value)
		if hero.is_empty():
			continue
		var hero_id := String(hero.get("id", ""))
		if hero_id == "":
			continue
		seen_hero_ids[hero_id] = true
		_legacy_append_hero_target_candidate(session, candidates, hero, origin_pos, config, faction_id, active_hero_id)
	if active_hero_id != "" and not seen_hero_ids.has(active_hero_id):
		var active_hero_value = session.overworld.get("hero", {})
		if active_hero_value is Dictionary:
			var active_hero: Dictionary = active_hero_value.duplicate(true)
			active_hero["id"] = active_hero_id
			var active_position = active_hero.get("position", {})
			if not (active_position is Dictionary) or active_position.is_empty():
				var position_source = session.overworld.get("hero_position", {"x": 0, "y": 0})
				if position_source is Dictionary:
					active_hero["position"] = position_source.duplicate(true)
			active_hero["is_primary"] = true
			var known_active_hero := EnemyAdventureRules._known_player_hero_snapshot_for_ai(session, faction_id, active_hero)
			if not known_active_hero.is_empty():
				_legacy_append_hero_target_candidate(session, candidates, known_active_hero, origin_pos, config, faction_id, active_hero_id)
	return candidates

func _legacy_append_hero_target_candidate(
	session: Variant,
	candidates: Array,
	hero: Dictionary,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	active_hero_id: String
) -> void:
	var hero_id := String(hero.get("id", ""))
	if hero_id == "":
		return
	var goal_tile := EnemyAdventureRules._player_hero_goal_tile(hero)
	var goal_distance: int = EnemyAdventureRules._hero_target_goal_distance(session, origin_pos, goal_tile, faction_id)
	if goal_distance >= 9999:
		return
	var priority = 95
	if hero_id == active_hero_id:
		priority += 26
	if bool(hero.get("is_primary", false)):
		priority += 18
	var army_strength: int = EnemyAdventureRules._known_player_hero_strength(hero)
	if army_strength <= 110:
		priority += 26
	elif army_strength <= 180:
		priority += 14
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		var distance: int = abs(goal_tile.x - int(town.get("x", 0))) + abs(goal_tile.y - int(town.get("y", 0)))
		if distance > 6:
			continue
		var defense_priority: int = 120 + max(0, (6 - distance) * 10)
		match OverworldRules.town_strategic_role(town):
			"capital":
				defense_priority += 44
			"stronghold":
				defense_priority += 24
		if int(OverworldRules.town_capital_project_state(town, session).get("active", 0)) > 0:
			defense_priority += 24
		if EnemyAdventureRules._town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			defense_priority += 28
		priority = max(priority, defense_priority)
	candidates.append(
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": String(hero.get("name", "the hero")),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
			"priority": max(
				0,
				EnemyAdventureRules._weighted_priority(config, faction_id, "hero", hero_id, priority, "", false)
				- EnemyAdventureRules._assignment_penalty(session, "hero", hero_id)
			),
		}
	)

func _planner_fit_context_preserves_candidate_scores() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var actor_id := "hero_sable"
	var entry := _commander_entry(session, MIRECLAW, actor_id)
	var origins := EnemyAdventureRules._ai_hero_task_planner_origins(session, config, MIRECLAW)
	var candidates := EnemyAdventureRules._ai_hero_task_planner_candidates_from_origins(session, config, origins)
	if entry.is_empty() or candidates.is_empty():
		_fail("Fit-context fixture requires a live commander entry and planner candidates.")
		return {}
	var fit_context := EnemyAdventureRules._ai_commander_task_fit_context(
		session,
		MIRECLAW,
		actor_id,
		entry
	)
	var context_candidates := EnemyAdventureRules._ai_hero_task_planner_candidates_for_commander(
		session,
		MIRECLAW,
		actor_id,
		candidates,
		true,
		fit_context
	)
	var standalone_candidates := EnemyAdventureRules._ai_hero_task_planner_candidates_for_commander(
		session,
		MIRECLAW,
		actor_id,
		candidates
	)
	if JSON.stringify(context_candidates) != JSON.stringify(standalone_candidates):
		_fail("Shared fit context changed candidate scores or ordering: context=%s standalone=%s" % [JSON.stringify(context_candidates), JSON.stringify(standalone_candidates)])
		return {}
	var profile := String(fit_context.get("profile", ""))
	if profile == "" or profile != EnemyAdventureRules._ai_commander_task_fit_profile(session, MIRECLAW, actor_id):
		_fail("Shared fit context changed commander profile: %s" % JSON.stringify(fit_context))
		return {}
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var context_bonus := EnemyAdventureRules._ai_commander_task_fit_bonus_from_context(session, candidate, fit_context)
		var standalone_bonus := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, actor_id, candidate)
		if context_bonus != standalone_bonus:
			_fail("Shared fit context changed candidate bonus: context=%d standalone=%d candidate=%s" % [context_bonus, standalone_bonus, JSON.stringify(candidate)])
			return {}
	return {
		"case_id": "planner_reuses_one_equivalent_commander_fit_context",
		"actor_id": actor_id,
		"candidate_count": candidates.size(),
		"fit_profile": profile,
		"scores_exact": true,
		"ordering_exact": true,
	}

func _planner_seeds_distinct_tasks_before_spawn() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var active_raids_before := _active_raid_count(session)
	if active_raids_before != 0:
		_fail("Planner fixture expected no active raids before planning, got %d" % active_raids_before)
		return {}

	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 2:
		_fail("Planner should seed at least two distinct commander tasks, got %s" % JSON.stringify(plan_result))
		return {}
	var planned_state: Dictionary = plan_result.get("state", {})
	var planned_tasks := _planned_tasks(planned_state)
	_assert_distinct_planned_tasks(planned_tasks)
	if _failed:
		return {}
	var planned_keys := _task_keys(planned_tasks)
	var pressure_target_result := EnemyTurnRules._pressure_summary_target(
		session,
		config,
		planned_state,
		{"x": 7, "y": 2}
	)
	var pressure_target: Dictionary = pressure_target_result.get("target", {}) if pressure_target_result.get("target", {}) is Dictionary else {}
	var pressure_target_key := "%s:%s" % [String(pressure_target.get("target_kind", "")), String(pressure_target.get("target_placement_id", ""))]
	if String(pressure_target_result.get("source", "")) != "hero_task_state" or pressure_target_key not in planned_keys:
		_fail("Pressure summary did not reuse one of the durable planned commander targets: %s / %s" % [JSON.stringify(pressure_target_result), JSON.stringify(planned_keys)])
		return {}
	if String(pressure_target.get("target_label", "")) == "" or String(pressure_target.get("hero_task_id", "")) == "":
		_fail("Pressure summary task target is missing player-facing label or task identity: %s" % JSON.stringify(pressure_target))
		return {}
	var fallback_state := planned_state.duplicate(true)
	fallback_state.erase("hero_task_state")
	var fallback_target_result := EnemyTurnRules._pressure_summary_target(
		session,
		config,
		fallback_state,
		{"x": 7, "y": 2}
	)
	if String(fallback_target_result.get("source", "")) != "fresh_target_scan" \
			or not (fallback_target_result.get("target", {}) is Dictionary) \
			or fallback_target_result.get("target", {}).is_empty():
		_fail("Pressure summary did not retain a fresh target-scan fallback without a durable task board: %s" % JSON.stringify(fallback_target_result))
		return {}
	_update_enemy_state(session, planned_state)

	var spawn_result := EnemyTurnRules._spawn_raid(session, config, planned_state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Spawn from planned task board failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	var spawned_key := "%s:%s" % [String(raid.get("target_kind", "")), String(raid.get("target_placement_id", ""))]
	if spawned_key not in planned_keys:
		_fail("Spawned raid target %s was not one of the planned tasks %s: %s" % [spawned_key, JSON.stringify(planned_keys), JSON.stringify(raid)])
		return {}
	var commander_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	_assert_active_task(session, commander_id, String(raid.get("target_kind", "")), String(raid.get("target_placement_id", "")))
	if _failed:
		return {}
	return {
		"case_id": "river_pass_predeployment_planner_seeds_and_activates_distinct_tasks",
		"active_raids_before": active_raids_before,
		"planned_count": int(plan_result.get("planned_count", 0)),
		"planned_task_keys": planned_keys,
		"pressure_target_key": pressure_target_key,
		"pressure_target_source": String(pressure_target_result.get("source", "")),
		"fallback_target_source": String(fallback_target_result.get("source", "")),
		"spawned_commander_id": commander_id,
		"spawned_target_key": spawned_key,
		"spawn_message": String(spawn_result.get("message", "")),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _planner_uses_local_origin_for_remote_front() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	state.erase("hero_task_state")
	_add_enemy_town(session, "north_mire_watch", "town_duskfen", 0, 0)
	_update_enemy_state(session, state)
	_set_resource_controller(session, "north_wood", "player")
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 2:
		_fail("Multi-origin planner should seed tasks, got %s" % JSON.stringify(plan_result))
		return {}
	var planned_state: Dictionary = plan_result.get("state", {})
	var north_task := _planned_task_for_target(planned_state, "resource", "north_wood")
	if north_task.is_empty():
		_fail("Multi-origin planner did not plan north_wood from local front: %s" % JSON.stringify(_task_keys(_planned_tasks(planned_state))))
		return {}
	if String(north_task.get("origin_id", "")) != "north_mire_watch":
		_fail("north_wood should use the local north_mire_watch origin, got %s" % JSON.stringify(north_task))
		return {}
	return {
		"case_id": "multi_origin_planner_uses_local_town_for_north_resource",
		"planned_count": int(plan_result.get("planned_count", 0)),
		"target_key": "resource:north_wood",
		"origin_id": String(north_task.get("origin_id", "")),
		"origin_x": int(north_task.get("origin_x", -1)),
		"origin_y": int(north_task.get("origin_y", -1)),
	}

func _planner_uses_commander_personality_fit() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var origin := {"kind": "town", "placement_id": "duskfen_bastion", "x": 7, "y": 2}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("Personality fixture expected an active hero id")
		return {}
	var candidates := [
		{
			"target_kind": "artifact",
			"target_placement_id": "trailsinger_cache",
			"target_label": "Trailsinger Cache",
			"target_x": 2,
			"target_y": 0,
			"goal_x": 2,
			"goal_y": 0,
			"goal_distance": 5,
			"priority": 100,
			"target_reason_codes": ["artifact_pressure", "magic_support"],
			"target_public_reason": "magic relic",
			"target_public_importance": "medium",
		},
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": "Exposed Hero",
			"target_x": 1,
			"target_y": 2,
			"goal_x": 1,
			"goal_y": 2,
			"goal_distance": 5,
			"priority": 100,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
		},
	]
	var vaska_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_vaska",
		origin,
		candidates,
		{},
		1
	)
	var sable_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_sable",
		origin,
		candidates,
		{},
		2
	)
	if String(vaska_task.get("target_kind", "")) != "hero":
		_fail("Raider commander should prefer exposed hero pressure, got %s" % JSON.stringify(vaska_task))
		return {}
	if String(sable_task.get("target_kind", "")) != "artifact":
		_fail("Magic commander should prefer magic artifact pressure, got %s" % JSON.stringify(sable_task))
		return {}
	if int(vaska_task.get("commander_fit_bonus", 0)) <= 0 or int(sable_task.get("commander_fit_bonus", 0)) <= 0:
		_fail("Personality-fit tasks should persist positive fit metadata: %s / %s" % [JSON.stringify(vaska_task), JSON.stringify(sable_task)])
		return {}
	return {
		"case_id": "commander_personality_fit_changes_target_choice",
		"raider_actor_id": "hero_vaska",
		"raider_target_key": "%s:%s" % [String(vaska_task.get("target_kind", "")), String(vaska_task.get("target_id", ""))],
		"raider_fit_bonus": int(vaska_task.get("commander_fit_bonus", 0)),
		"raider_fit_profile": String(vaska_task.get("commander_fit_profile", "")),
		"magic_actor_id": "hero_sable",
		"magic_target_key": "%s:%s" % [String(sable_task.get("target_kind", "")), String(sable_task.get("target_id", ""))],
		"magic_fit_bonus": int(sable_task.get("commander_fit_bonus", 0)),
		"magic_fit_profile": String(sable_task.get("commander_fit_profile", "")),
	}

func _planner_assigns_specialized_target_globally() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var origin := {"kind": "town", "placement_id": "duskfen_bastion", "x": 7, "y": 2}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("Global-fit fixture expected an active hero id")
		return {}
	var candidates := [
		{
			"target_kind": "artifact",
			"target_placement_id": "trailsinger_cache",
			"target_label": "Trailsinger Cache",
			"target_x": 2,
			"target_y": 0,
			"goal_x": 2,
			"goal_y": 0,
			"goal_distance": 5,
			"priority": 120,
			"target_reason_codes": ["artifact_pressure", "magic_support"],
			"target_public_reason": "magic relic",
			"target_public_importance": "medium",
		},
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": "Exposed Hero",
			"target_x": 1,
			"target_y": 2,
			"goal_x": 1,
			"goal_y": 2,
			"goal_distance": 5,
			"priority": 20,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
		},
	]
	var vaska_greedy_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_vaska",
		origin,
		candidates,
		{},
		1
	)
	if String(vaska_greedy_task.get("target_kind", "")) != "artifact":
		_fail("Global-fit fixture expected roster-order Vaska to greedily claim artifact before global assignment, got %s" % JSON.stringify(vaska_greedy_task))
		return {}
	var roster := [
		_commander_entry(session, MIRECLAW, "hero_vaska"),
		_commander_entry(session, MIRECLAW, "hero_sable"),
	]
	var assignments := EnemyAdventureRules._ai_hero_task_planner_global_task_assignments(
		session,
		config,
		MIRECLAW,
		roster,
		origin,
		candidates,
		{},
		[],
		1
	)
	if assignments.size() < 2:
		_fail("Global-fit assignment should allocate both commanders, got %s" % JSON.stringify(assignments))
		return {}
	var vaska_task := _task_for_actor_id(assignments, "hero_vaska")
	var sable_task := _task_for_actor_id(assignments, "hero_sable")
	if String(sable_task.get("target_kind", "")) != "artifact" or String(sable_task.get("target_id", "")) != "trailsinger_cache":
		_fail("Global-fit assignment should reserve magic artifact for Sable, got %s assignments=%s" % [JSON.stringify(sable_task), JSON.stringify(assignments)])
		return {}
	if String(vaska_task.get("target_kind", "")) != "hero" or String(vaska_task.get("target_id", "")) != hero_id:
		_fail("Global-fit assignment should move Vaska to the alternate hero pressure target, got %s assignments=%s" % [JSON.stringify(vaska_task), JSON.stringify(assignments)])
		return {}
	if int(sable_task.get("commander_fit_bonus", 0)) <= int(vaska_greedy_task.get("commander_fit_bonus", 0)):
		_fail("Global-fit fixture expected Sable's artifact fit to beat Vaska's artifact fit: sable=%s vaska=%s" % [JSON.stringify(sable_task), JSON.stringify(vaska_greedy_task)])
		return {}
	return {
		"case_id": "global_commander_task_assignment_preserves_specialist_target",
		"greedy_first_actor": "hero_vaska",
		"greedy_first_target_key": "%s:%s" % [String(vaska_greedy_task.get("target_kind", "")), String(vaska_greedy_task.get("target_id", ""))],
		"specialist_actor": "hero_sable",
		"specialist_target_key": "%s:%s" % [String(sable_task.get("target_kind", "")), String(sable_task.get("target_id", ""))],
		"specialist_fit_bonus": int(sable_task.get("commander_fit_bonus", 0)),
		"alternate_actor": "hero_vaska",
		"alternate_target_key": "%s:%s" % [String(vaska_task.get("target_kind", "")), String(vaska_task.get("target_id", ""))],
		"alternate_fit_bonus": int(vaska_task.get("commander_fit_bonus", 0)),
	}

func _planner_uses_commander_outcome_memory() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var origin := {"kind": "town", "placement_id": "duskfen_bastion", "x": 7, "y": 2}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("Adaptive-memory fixture expected an active hero id")
		return {}
	var candidates := [
		{
			"target_kind": "artifact",
			"target_placement_id": "trailsinger_cache",
			"target_label": "Trailsinger Cache",
			"target_x": 2,
			"target_y": 0,
			"goal_x": 2,
			"goal_y": 0,
			"goal_distance": 5,
			"priority": 100,
			"target_reason_codes": ["artifact_pressure", "magic_support"],
			"target_public_reason": "magic relic",
			"target_public_importance": "medium",
		},
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": "Exposed Hero",
			"target_x": 1,
			"target_y": 2,
			"goal_x": 1,
			"goal_y": 2,
			"goal_distance": 5,
			"priority": 180,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
		},
	]
	var initial_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_sable",
		origin,
		candidates,
		{},
		1
	)
	if String(initial_task.get("target_kind", "")) != "artifact":
		_fail("Magic commander fixture should start by preferring artifact pressure before outcome memory, got %s" % JSON.stringify(initial_task))
		return {}
	var entry := _commander_entry(session, MIRECLAW, "hero_sable")
	var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
	commander_state = EnemyAdventureRules.record_target_assignment(
		commander_state,
		"hero",
		hero_id,
		"Exposed Hero",
		1,
		2
	)
	commander_state = EnemyAdventureRules.advance_commander_record(
		commander_state,
		EnemyAdventureRules.COMMANDER_OUTCOME_FIELD_VICTORY
	)
	commander_state = EnemyAdventureRules.record_target_assignment(
		commander_state,
		"hero",
		hero_id,
		"Exposed Hero",
		1,
		2
	)
	commander_state = EnemyAdventureRules.advance_commander_record(
		commander_state,
		EnemyAdventureRules.COMMANDER_OUTCOME_PURSUIT_VICTORY
	)
	var direct_memory := EnemyAdventureRules.commander_target_memory(commander_state)
	var direct_success_counts: Dictionary = direct_memory.get("target_success_counts", {}) if direct_memory.get("target_success_counts", {}) is Dictionary else {}
	if int(direct_success_counts.get("hero", 0)) < 2:
		_fail("Outcome memory did not update on commander state before roster sync: %s" % JSON.stringify(direct_memory))
		return {}
	EnemyAdventureRules.sync_commander_state_to_roster(
		session,
		MIRECLAW,
		commander_state,
		EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE,
		"",
		0,
		EnemyAdventureRules.COMMANDER_OUTCOME_PURSUIT_VICTORY
	)
	var adapted_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_sable",
		origin,
		candidates,
		{},
		2
	)
	var memory := EnemyAdventureRules.commander_target_memory(_commander_entry(session, MIRECLAW, "hero_sable"))
	var artifact_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, "hero_sable", candidates[0])
	var hero_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, "hero_sable", candidates[1])
	if String(adapted_task.get("target_kind", "")) != "hero":
		_fail("Outcome memory should shift experienced commander toward successful hero pressure, got %s memory=%s artifact_fit=%d hero_fit=%d" % [JSON.stringify(adapted_task), JSON.stringify(memory), artifact_fit, hero_fit])
		return {}
	var success_counts: Dictionary = memory.get("target_success_counts", {}) if memory.get("target_success_counts", {}) is Dictionary else {}
	if int(success_counts.get("hero", 0)) < 2:
		_fail("Outcome memory did not preserve hero success counts: %s" % JSON.stringify(memory))
		return {}
	return {
		"case_id": "commander_outcome_memory_changes_future_task_choice",
		"actor_id": "hero_sable",
		"initial_target_key": "%s:%s" % [String(initial_task.get("target_kind", "")), String(initial_task.get("target_id", ""))],
		"adapted_target_key": "%s:%s" % [String(adapted_task.get("target_kind", "")), String(adapted_task.get("target_id", ""))],
		"hero_success_count": int(success_counts.get("hero", 0)),
		"adapted_fit_bonus": int(adapted_task.get("commander_fit_bonus", 0)),
		"adapted_fit_profile": String(adapted_task.get("commander_fit_profile", "")),
	}

func _planner_adopts_live_commander_role_state() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var planned_state: Dictionary = plan_result.get("state", {})
	var adopted_task := _first_planned_task_for_kind(planned_state, "resource")
	if adopted_task.is_empty():
		_fail("Role adoption fixture expected a planned resource task, got %s" % JSON.stringify(plan_result))
		return {}
	var actor_id := String(adopted_task.get("actor_id", ""))
	var entry := _commander_entry_from_state(planned_state, actor_id)
	var role_state := EnemyAdventureRules.commander_live_role_state(entry)
	if role_state.is_empty():
		_fail("Planner did not persist live commander role state for %s in %s" % [actor_id, JSON.stringify(entry)])
		return {}
	if String(role_state.get("target_kind", "")) != String(adopted_task.get("target_kind", "")) or String(role_state.get("target_id", "")) != String(adopted_task.get("target_id", "")):
		_fail("Role state target does not match adopted task: role=%s task=%s" % [JSON.stringify(role_state), JSON.stringify(adopted_task)])
		return {}
	if String(role_state.get("role", "")) != String(adopted_task.get("source_role", "")):
		_fail("Role state did not preserve task source_role: role=%s task=%s" % [JSON.stringify(role_state), JSON.stringify(adopted_task)])
		return {}
	_update_enemy_state(session, planned_state)
	var same_candidate := {
		"target_kind": "resource",
		"target_placement_id": String(adopted_task.get("target_id", "")),
		"priority": 100,
		"target_reason_codes": adopted_task.get("priority_reason_codes", []),
	}
	var rival_id := "river_signal_post" if String(adopted_task.get("target_id", "")) != "river_signal_post" else "river_free_company"
	var rival_candidate := {
		"target_kind": "resource",
		"target_placement_id": rival_id,
		"priority": 100,
		"target_reason_codes": ["persistent_income_denial", "route_pressure", "strategic_task_planner"],
	}
	var same_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, actor_id, same_candidate)
	var rival_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, actor_id, rival_candidate)
	if same_fit <= rival_fit:
		_fail("Live role continuity should favor the adopted front: same=%d rival=%d role=%s" % [same_fit, rival_fit, JSON.stringify(role_state)])
		return {}
	return {
		"case_id": "planner_persists_live_role_state_and_scores_continuity",
		"actor_id": actor_id,
		"role": String(role_state.get("role", "")),
		"source_policy": String(role_state.get("source_policy", "")),
		"target_key": "%s:%s" % [String(role_state.get("target_kind", "")), String(role_state.get("target_id", ""))],
		"same_target_fit": same_fit,
		"rival_fit": rival_fit,
	}

func _planner_recovers_duplicate_reservation_with_alternate_task() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 4,
		"tasks": [
			_saved_resource_task("hero_sable", "river_free_company", 1),
			_saved_resource_task("hero_vaska", "river_free_company", 2),
		],
	}
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var planned_state: Dictionary = plan_result.get("state", {})
	var task_state: Dictionary = planned_state.get("hero_task_state", {}) if planned_state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var primary := _task_for_target_status(tasks, "river_free_company", "planned")
	if primary.is_empty():
		_fail("Duplicate recovery should preserve one primary Free Company task: %s" % JSON.stringify(tasks))
		return {}
	var invalid_duplicate := _invalid_reserved_task(tasks)
	if invalid_duplicate.is_empty():
		_fail("Duplicate recovery should preserve invalidated duplicate history: %s" % JSON.stringify(tasks))
		return {}
	var displaced_actor := String(invalid_duplicate.get("actor_id", ""))
	var alternate := _planned_task_for_actor(tasks, displaced_actor, "river_free_company")
	if alternate.is_empty():
		_fail("Duplicate recovery did not assign alternate planned task for displaced actor %s: %s" % [displaced_actor, JSON.stringify(tasks)])
		return {}
	var reservation_check := EnemyAdventureRules.ai_hero_task_target_reservation_check(tasks)
	if not bool(reservation_check.get("ok", false)):
		_fail("Duplicate recovery left invalid reservation state: %s" % JSON.stringify(reservation_check))
		return {}
	return {
		"case_id": "planner_recovers_duplicate_reservation_with_alternate_task",
		"primary_actor": String(primary.get("actor_id", "")),
		"displaced_actor": displaced_actor,
		"invalidated_by_task_id": String(invalid_duplicate.get("invalidated_by_task_id", "")),
		"alternate_target_key": "%s:%s" % [String(alternate.get("target_kind", "")), String(alternate.get("target_id", ""))],
		"planned_count": int(plan_result.get("planned_count", 0)),
		"task_count": tasks.size(),
		"reservation_primary_count": int(reservation_check.get("primary_reservation_count", 0)),
	}

func _base_session():
	var session = ScenarioFactory.create_session(RIVER_PASS, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW:
			return state
	_fail("Could not find enemy state for %s" % MIRECLAW)
	return {}

func _commander_entry(session, faction_id: String, roster_hero_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, faction_id):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Could not find commander %s for %s" % [roster_hero_id, faction_id])
	return {}

func _add_enemy_town(session, placement_id: String, town_id: String, x: int, y: int) -> void:
	var towns: Array = session.overworld.get("towns", [])
	towns.append({
		"placement_id": placement_id,
		"town_id": town_id,
		"x": x,
		"y": y,
		"owner": "enemy",
	})
	session.overworld["towns"] = towns

func _update_enemy_state(session, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update enemy state for %s" % String(replacement.get("faction_id", "")))

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s" % placement_id)

func _planned_tasks(state: Dictionary) -> Array:
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var output := []
	for task_value in task_state.get("tasks", []):
		if task_value is Dictionary and String(task_value.get("task_status", "")) == "planned":
			output.append(task_value)
	return output

func _assert_distinct_planned_tasks(tasks: Array) -> void:
	if tasks.size() < 2:
		_fail("Expected at least two planned tasks, got %s" % JSON.stringify(tasks))
		return
	var actors := {}
	var targets := {}
	for task_value in tasks:
		var task: Dictionary = task_value
		var actor_id := String(task.get("actor_id", ""))
		var target_key := "%s:%s" % [String(task.get("target_kind", "")), String(task.get("target_id", ""))]
		if actor_id == "" or actors.has(actor_id):
			_fail("Planned tasks must use distinct non-empty actors: %s" % JSON.stringify(tasks))
			return
		if targets.has(target_key):
			_fail("Planned tasks must reserve distinct targets: %s" % JSON.stringify(tasks))
			return
		var reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
		if String(reservation.get("reservation_scope", "")) != "exclusive_target":
			_fail("Planned task must reserve its target exclusively: %s" % JSON.stringify(task))
			return
		if "strategic_task_planner" not in _string_array(task.get("priority_reason_codes", [])):
			_fail("Planned task missing strategic_task_planner reason: %s" % JSON.stringify(task))
			return
		actors[actor_id] = true
		targets[target_key] = true

func _task_keys(tasks: Array) -> Array:
	var keys := []
	for task_value in tasks:
		if task_value is Dictionary:
			keys.append("%s:%s" % [String(task_value.get("target_kind", "")), String(task_value.get("target_id", ""))])
	keys.sort()
	return keys

func _planned_task_for_target(state: Dictionary, target_kind: String, target_id: String) -> Dictionary:
	for task_value in _planned_tasks(state):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("target_kind", "")) == target_kind and String(task.get("target_id", "")) == target_id:
			return task
	return {}

func _planned_task_for_actor(tasks: Array, actor_id: String, excluded_target_id: String) -> Dictionary:
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) != "planned":
			continue
		if String(task.get("target_id", "")) == excluded_target_id:
			continue
		return task
	return {}

func _task_for_actor_id(tasks: Array, actor_id: String) -> Dictionary:
	for task_value in tasks:
		if task_value is Dictionary and String(task_value.get("actor_id", "")) == actor_id:
			return task_value
	return {}

func _task_for_target_status(tasks: Array, target_id: String, status: String) -> Dictionary:
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("target_id", "")) == target_id and String(task.get("task_status", "")) == status:
			return task
	return {}

func _invalid_reserved_task(tasks: Array) -> Dictionary:
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("task_status", "")) == "invalid" and String(task.get("last_validation", "")) == "invalid_target_reserved":
			return task
	return {}

func _saved_resource_task(actor_id: String, target_id: String, sequence: int) -> Dictionary:
	return {
		"task_id": "task:%s:%s:%s:contest_site:resource:%s:day_1:seq_%d" % [RIVER_PASS, MIRECLAW, actor_id, target_id, sequence],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "duplicate_reservation_fixture",
		"task_class": "contest_site",
		"task_status": "planned",
		"target_kind": "resource",
		"target_id": target_id,
		"front_id": EnemyAdventureRules.commander_role_front_id(RIVER_PASS, "resource", target_id),
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"origin_x": 7,
		"origin_y": 2,
		"priority_reason_codes": ["persistent_income_denial", "strategic_task_planner", "duplicate_reservation_fixture"],
		"assigned_day": 1,
		"expires_day": 11,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": "valid",
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "resource:%s" % target_id,
		},
	}

func _first_planned_task_for_kind(state: Dictionary, target_kind: String) -> Dictionary:
	for task_value in _planned_tasks(state):
		if task_value is Dictionary and String(task_value.get("target_kind", "")) == target_kind:
			return task_value
	return {}

func _commander_entry_from_state(state: Dictionary, roster_hero_id: String) -> Dictionary:
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for entry in roster:
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Could not find commander %s in planned state" % roster_hero_id)
	return {}

func _assert_active_task(session, actor_id: String, target_kind: String, target_id: String) -> void:
	var state := _enemy_state(session)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	for task_value in task_state.get("tasks", []):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) == actor_id \
				and String(task.get("target_kind", "")) == target_kind \
				and String(task.get("target_id", "")) == target_id \
				and String(task.get("task_status", "")) == "active":
			return
	_fail("Spawned commander task was not activated for %s/%s:%s in %s" % [actor_id, target_kind, target_id, JSON.stringify(task_state)])

func _latest_raid(session) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW:
			return encounter
	_fail("No spawned Mireclaw raid found.")
	return {}

func _active_raid_count(session) -> int:
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW:
			count += 1
	return count

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
