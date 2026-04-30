class_name OverworldRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

const FOG_KEY := "fog"
const VISIBLE_TILES_KEY := "visible_tiles"
const EXPLORED_TILES_KEY := "explored_tiles"
const ACTIVE_TOWN_PLACEMENT_KEY := "active_town_placement_id"
const COMMAND_BRIEFING_KEY := "command_briefing"
const COMMAND_RISK_FORECAST_KEY := "command_risk_forecast"
const WEEKLY_GROWTH_INTERVAL := 7
const BUILDING_CATEGORIES := ["civic", "dwelling", "economy", "support", "magic"]
const LOGISTICS_SITE_FAMILIES := ["neutral_dwelling", "faction_outpost", "frontier_shrine"]

static var _normalized_read_scope_session_id := ""
static var _normalized_read_scope_depth := 0
static var _blocked_tile_indexes: Dictionary = {}

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func _scenario_rules() -> Variant:
	return load("res://scripts/core/ScenarioRules.gd")

static func _campaign_rules() -> Variant:
	return load("res://scripts/core/CampaignRules.gd")

static func _scenario_script_rules() -> Variant:
	# Validator anchor: ScenarioScriptRules.describe_recent_events
	return load("res://scripts/core/ScenarioScriptRules.gd")

static func _enemy_turn_rules() -> Variant:
	return load("res://scripts/core/EnemyTurnRules.gd")

static func _enemy_adventure_rules() -> Variant:
	return load("res://scripts/core/EnemyAdventureRules.gd")

static func _battle_rules() -> Variant:
	return load("res://scripts/core/BattleRules.gd")

static func _build_scenario_army_state(army_template: Dictionary) -> Dictionary:
	return _scenario_factory()._build_army_state(army_template)

static func _normalize_scenario_resources(value: Variant) -> Dictionary:
	return _scenario_factory()._normalize_resources(value)

static func _build_scenario_town_states(placements: Variant) -> Array:
	return _scenario_factory()._build_town_states(placements)

static func _build_scenario_resource_states(placements: Variant) -> Array:
	return _scenario_factory()._build_resource_states(placements)

static func _seed_scenario_recruits_for_town_state(town: Dictionary) -> Dictionary:
	return _scenario_factory()._seed_recruits_for_town_state(town)

static func _scenario_unit_growth(unit_id: String) -> int:
	return _scenario_factory()._unit_growth(unit_id)

static func _normalize_scenario_state_rules(session: SessionStateStoreScript.SessionData) -> void:
	_scenario_rules().normalize_scenario_state(session)

static func _normalize_active_town_visit_context(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var placement_id := String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, ""))
	if placement_id == "":
		return
	var town_result := _find_town_by_placement(session, placement_id)
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or String(town.get("owner", "neutral")) != "player":
		session.flags.erase(ACTIVE_TOWN_PLACEMENT_KEY)

static func _evaluate_scenario_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _scenario_rules().evaluate_session(session)

static func _scenario_opening_objective_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	return _scenario_rules()._opening_objective_summary(session, scenario)

static func _scenario_enemy_operational_lines(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> Array:
	return _scenario_rules()._enemy_operational_lines(session, scenario)

static func _scenario_first_contact_summary(scenario: Dictionary) -> String:
	return _scenario_rules()._first_contact_summary(scenario)

static func _scenario_objective_labels_from_bucket(session: SessionStateStoreScript.SessionData, bucket: Variant, limit: int) -> Array:
	return _scenario_rules()._objective_labels_from_bucket(session, bucket, limit)

static func _scenario_objective_met(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> bool:
	return _scenario_rules()._objective_met(session, objective)

static func _scenario_is_objective_met(session: SessionStateStoreScript.SessionData, objective_id: String, bucket: String) -> bool:
	return _scenario_rules().is_objective_met(session, objective_id, bucket)

static func _scenario_describe_objectives(session: SessionStateStoreScript.SessionData) -> String:
	return _scenario_rules().describe_objectives(session)

static func _describe_recent_events(session: SessionStateStoreScript.SessionData, limit: int) -> String:
	return _scenario_script_rules().describe_recent_events(session, limit)

static func _normalize_enemy_states(session: SessionStateStoreScript.SessionData) -> void:
	_enemy_turn_rules().normalize_enemy_states(session)

static func _run_enemy_turn_cycle(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _enemy_turn_rules().run_enemy_turn(session)

static func _describe_enemy_threats(session: SessionStateStoreScript.SessionData) -> String:
	return _enemy_turn_rules().describe_threats(session)

static func _enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return _enemy_turn_rules().get_pressure(session, faction_id)

static func _enemy_active_raids(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return _enemy_turn_rules().active_raid_count(session, faction_id)

static func _enemy_raid_threshold_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String) -> int:
	return _enemy_turn_rules()._raid_threshold_for_strategy(session, config, faction_id)

static func _enemy_max_active_raids_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String) -> int:
	return _enemy_turn_rules()._max_active_raids_for_strategy(session, config, faction_id)

static func _raid_target_is_objective_anchor(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> bool:
	return _enemy_adventure_rules().target_is_objective_anchor(session, target_kind, placement_id)

static func _raid_is_public(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	return _enemy_adventure_rules()._raid_is_public(session, encounter)

static func normalize_overworld_state(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if _normalized_read_scope_depth > 0 and String(session.session_id) == _normalized_read_scope_session_id:
		return
	session.save_version = SessionStateStoreScript.SAVE_VERSION
	DifficultyRulesScript.normalize_session(session)

	var scenario := ContentService.get_scenario(session.scenario_id)
	var hero_id := session.hero_id
	if hero_id == "":
		hero_id = String(scenario.get("hero_id", ""))
		session.hero_id = hero_id
	var player_army_id := String(scenario.get("player_army_id", session.overworld.get("player_army_id", "")))
	HeroCommandRulesScript.normalize_session(
		session,
		hero_id,
		scenario.get("start", {"x": 0, "y": 0}),
		_build_scenario_army_state(ContentService.get_army_group(player_army_id))
	)

	var resources = session.overworld.get("resources", {})
	if not (resources is Dictionary) or resources.is_empty():
		resources = _normalize_scenario_resources(scenario.get("starting_resources", {}))
	session.overworld["resources"] = _normalize_scenario_resources(resources)

	if not session.overworld.has("towns") or not (session.overworld.get("towns") is Array):
		session.overworld["towns"] = _build_scenario_town_states(scenario.get("towns", []))
	else:
		session.overworld["towns"] = _normalize_towns(session.overworld.get("towns", []))
	_normalize_active_town_visit_context(session)

	if not session.overworld.has("resource_nodes") or not (session.overworld.get("resource_nodes") is Array):
		session.overworld["resource_nodes"] = _build_scenario_resource_states(scenario.get("resource_nodes", []))
	else:
		session.overworld["resource_nodes"] = _normalize_resource_nodes(session.overworld.get("resource_nodes", []))

	if not session.overworld.has("artifact_nodes") or not (session.overworld.get("artifact_nodes") is Array):
		session.overworld["artifact_nodes"] = ArtifactRulesScript.build_artifact_nodes(scenario.get("artifact_nodes", []))
	else:
		session.overworld["artifact_nodes"] = _normalize_artifact_nodes(session.overworld.get("artifact_nodes", []))

	if not session.overworld.has("encounters") or not (session.overworld.get("encounters") is Array):
		session.overworld["encounters"] = scenario.get("encounters", [])
	if not session.overworld.has("resolved_encounters") or not (session.overworld.get("resolved_encounters") is Array):
		session.overworld["resolved_encounters"] = []
	if not session.overworld.has("map") or not (session.overworld.get("map") is Array):
		session.overworld["map"] = scenario.get("map", [])
	if not session.overworld.has("map_size") or not (session.overworld.get("map_size") is Dictionary):
		session.overworld["map_size"] = scenario.get("map_size", {})
	if not session.overworld.has("terrain_layers") or not (session.overworld.get("terrain_layers") is Dictionary) or session.overworld.get("terrain_layers", {}).is_empty():
		session.overworld["terrain_layers"] = ContentService.get_terrain_layers_for_scenario(session.scenario_id)
	_normalize_generated_runtime_materialization(session, scenario)
	if not session.overworld.has("hero_position") or not (session.overworld.get("hero_position") is Dictionary):
		session.overworld["hero_position"] = scenario.get("start", {"x": 0, "y": 0})
	_refresh_blocked_tile_index(session)
	_normalize_fog_of_war(session)
	_normalize_command_briefing(session)
	_normalize_command_risk_forecast(session)

	_normalize_scenario_state_rules(session)

static func _normalize_generated_runtime_materialization(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> void:
	if session == null:
		return
	if not bool(scenario.get("generated", false)) and not bool(session.flags.get("generated_random_map", false)) and not bool(session.flags.get("generated_random_map_draft", false)):
		return
	var materialization: Dictionary = session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) if session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) is Dictionary else {}
	var identity: Dictionary = session.overworld.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) if session.overworld.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) is Dictionary else {}
	if materialization.is_empty():
		var scenario_materialization: Dictionary = scenario.get("generated_runtime_materialization", {}) if scenario.get("generated_runtime_materialization", {}) is Dictionary else {}
		if not scenario_materialization.is_empty():
			materialization = scenario_materialization.duplicate(true)
	if identity.is_empty() and not materialization.is_empty():
		identity = {
			"schema_id": String(materialization.get("schema_id", "")),
			"scenario_id": String(materialization.get("scenario_id", session.scenario_id)),
			"materialized_map_signature": String(materialization.get("materialized_map_signature", "")),
			"generator_version": String(materialization.get("generator_version", "")),
			"template_id": String(materialization.get("template_id", "")),
			"profile_id": String(materialization.get("profile_id", "")),
			"normalized_seed": String(materialization.get("normalized_seed", "")),
			"content_manifest_fingerprint": String(materialization.get("content_manifest_fingerprint", "")),
			"summary": materialization.get("summary", {}),
			"boundary": materialization.get("boundary", {}),
		}
	if not materialization.is_empty():
		session.overworld[SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY] = materialization
	if not identity.is_empty():
		session.overworld[SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG] = identity
		session.flags[SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG] = identity.duplicate(true)

static func begin_normalized_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if _normalized_read_scope_depth <= 0:
		normalize_overworld_state(session)
		_normalized_read_scope_session_id = String(session.session_id)
		_normalized_read_scope_depth = 1
		return
	if String(session.session_id) == _normalized_read_scope_session_id:
		_normalized_read_scope_depth += 1
		return
	normalize_overworld_state(session)

static func end_normalized_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if _normalized_read_scope_depth <= 0 or String(session.session_id) != _normalized_read_scope_session_id:
		return
	_normalized_read_scope_depth -= 1
	if _normalized_read_scope_depth <= 0:
		_normalized_read_scope_depth = 0
		_normalized_read_scope_session_id = ""

static func normalize_overworld_state_bridge(session) -> void:
	normalize_overworld_state(session)

static func refresh_fog_of_war(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if not session.overworld.has("map") or not (session.overworld.get("map") is Array):
		return
	_normalize_fog_of_war(session)

static func is_tile_visible(session: SessionStateStoreScript.SessionData, x: int, y: int) -> bool:
	if session == null:
		return false
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = session.overworld.get(FOG_KEY, {})
	return _grid_cell(fog.get(VISIBLE_TILES_KEY, []), x, y)

static func is_tile_explored(session: SessionStateStoreScript.SessionData, x: int, y: int) -> bool:
	if session == null:
		return false
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = session.overworld.get(FOG_KEY, {})
	return _grid_cell(fog.get(EXPLORED_TILES_KEY, []), x, y)

static func describe_visibility(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return "Explored 0/0 | Visible 0"
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = session.overworld.get(FOG_KEY, {})
	return "Explored %d/%d | Visible %d" % [
		int(fog.get("explored_count", 0)),
		int(fog.get("total_tiles", 0)),
		int(fog.get("visible_count", 0)),
	]

static func try_move(session: SessionStateStoreScript.SessionData, dx: int, dy: int) -> Dictionary:
	normalize_overworld_state(session)

	var movement = session.overworld.get("movement", {})
	var movement_left := int(movement.get("current", 0))
	if movement_left <= 0:
		return {"ok": false, "message": "No movement left today."}

	var pos := hero_position(session)
	var map_size := derive_map_size(session)
	var nx = clamp(pos.x + dx, 0, max(map_size.x - 1, 0))
	var ny = clamp(pos.y + dy, 0, max(map_size.y - 1, 0))
	if nx == pos.x and ny == pos.y:
		return {"ok": false, "message": "The map edge blocks further travel."}
	if tile_is_blocked(session, nx, ny):
		return {"ok": false, "message": "The terrain blocks that route."}

	session.overworld["hero_position"] = {"x": nx, "y": ny}
	movement["current"] = movement_left - 1
	session.overworld["movement"] = movement
	HeroCommandRulesScript.commit_active_hero(session)

	var messages := ["Moved to %d,%d." % [nx, ny]]
	var target_context := _post_action_tile_context(session, Vector2i(nx, ny))
	var interaction_result := _resolve_post_move_interaction(session)
	var interaction_message := String(interaction_result.get("message", ""))
	if interaction_message != "":
		messages.append(interaction_message)
	var result := _finalize_action_result(
		session,
		bool(interaction_result.get("ok", true)),
		" ".join(messages)
	)
	var route := String(interaction_result.get("route", ""))
	if route != "":
		result["route"] = route
	result = _attach_post_action_recap(
		result,
		session,
		"move",
		{
			"from_x": pos.x,
			"from_y": pos.y,
			"to_x": nx,
			"to_y": ny,
			"route": route,
			"target_context": target_context,
		}
	)
	return result

static func end_turn(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	HeroCommandRulesScript.commit_active_hero(session)
	session.day += 1

	var occupation_messages := _advance_all_town_occupations(session)
	var recovery_messages := _advance_all_town_recovery(session)
	var town_income := {"gold": 0, "wood": 0, "ore": 0}
	var weekly_growth_messages := []
	var should_apply_weekly_growth := is_weekly_growth_day(session.day)
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue

		var income := DifficultyRulesScript.scale_income_resources(session, _calculate_town_income(town, session))
		town_income = _add_resource_sets(town_income, income)
		if should_apply_weekly_growth:
			var growth_summary := _describe_recruit_delta(_growth_tick_town(session, town))
			if growth_summary != "":
				weekly_growth_messages.append("%s (%s)" % [_town_name(town), growth_summary])
		towns[index] = town
	session.overworld["towns"] = towns

	var hero_state = session.overworld.get("hero", {})
	var artifact_income = DifficultyRulesScript.scale_income_resources(
		session,
		ArtifactRulesScript.aggregate_bonuses(hero_state).get("daily_income", {})
	)
	var specialty_income = HeroProgressionRulesScript.daily_income_bonus(hero_state)
	var site_income = DifficultyRulesScript.scale_income_resources(session, controlled_resource_site_income(session, "player"))
	var total_income := _add_resource_sets(
		_add_resource_sets(_add_resource_sets(town_income, artifact_income), specialty_income),
		site_income
	)
	var site_muster_messages := []
	if should_apply_weekly_growth:
		site_muster_messages = apply_controlled_resource_site_musters(session, "player")
	_add_resources(session, total_income)
	_refresh_all_player_heroes_for_new_day(session)
	hero_state = session.overworld.get("hero", {})
	var movement_after = session.overworld.get("movement", {})

	var messages := ["Day %d begins." % session.day]
	var town_income_summary := _describe_resource_delta(town_income)
	if town_income_summary != "":
		messages.append("Town income %s." % town_income_summary)
	if not occupation_messages.is_empty():
		messages.append("Occupation lines %s." % "; ".join(occupation_messages))
	if not recovery_messages.is_empty():
		messages.append("Recovery lines %s." % "; ".join(recovery_messages))
	if not weekly_growth_messages.is_empty():
		messages.append("Weekly musters %s." % "; ".join(weekly_growth_messages))
	var artifact_income_summary := _describe_resource_delta(artifact_income)
	if artifact_income_summary != "":
		messages.append("Artifact income %s." % artifact_income_summary)
	var specialty_income_summary := _describe_resource_delta(specialty_income)
	if specialty_income_summary != "":
		messages.append("Specialty income %s." % specialty_income_summary)
	var site_income_summary := _describe_resource_delta(site_income)
	if site_income_summary != "":
		messages.append("Field sites yield %s." % site_income_summary)
	if not site_muster_messages.is_empty():
		messages.append("Outlying musters %s." % "; ".join(site_muster_messages))
	var delivery_messages := _advance_player_reserve_deliveries(session)
	if not delivery_messages.is_empty():
		messages.append("Reserve deliveries %s." % "; ".join(delivery_messages))
	var enemy_turn_result: Dictionary = _run_enemy_turn_cycle(session)
	var enemy_activity_summary := describe_enemy_activity(enemy_turn_result.get("events", []), 4)
	var enemy_message := String(enemy_turn_result.get("message", ""))
	if enemy_message != "":
		messages.append(enemy_message)
	var result := _finalize_action_result(session, true, " ".join(messages))
	result["enemy_activity_summary"] = enemy_activity_summary
	result["enemy_activity_events"] = _compact_enemy_activity_events(enemy_turn_result.get("events", []), 6)
	result["resource_income_summary"] = _describe_resource_delta(total_income)
	result["weekly_muster_summary"] = _end_turn_muster_summary(weekly_growth_messages, site_muster_messages)
	result["movement_reset_summary"] = "Move %d/%d ready" % [
		int(movement_after.get("current", 0)),
		int(movement_after.get("max", 0)),
	]
	result["town_economy_summary"] = _end_turn_town_economy_summary(
		occupation_messages,
		recovery_messages,
		delivery_messages
	)
	result["turn_resolution_summary"] = _end_turn_resolution_summary(session, result)
	return result

static func collect_active_resource(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var node_result := _find_context_resource_node(session)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No resource site here."}

	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if site.is_empty():
		return {"ok": false, "message": "This site has no authored payload."}
	if not _resource_node_claimable_by_player(node, site, session):
		if _resource_site_is_repeatable(site):
			return {"ok": false, "message": _resource_site_repeatable_block_message(session, node, site)}
		if _resource_site_is_persistent(site):
			return {"ok": false, "message": "This site is already under your control."}
		return {"ok": false, "message": "This site has already been gathered."}
	var visit_cost := _resource_site_visit_cost(site)
	if not _can_afford(session, visit_cost):
		return {
			"ok": false,
			"message": "Insufficient resources for %s." % String(site.get("action_label", "that service")),
		}

	var nodes = session.overworld.get("resource_nodes", [])
	var previous_controller := String(node.get("collected_by_faction_id", ""))
	node["collected"] = true
	node["collected_by_faction_id"] = "player"
	node["collected_day"] = session.day
	node = _clear_resource_site_response(node)
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes
	_refresh_blocked_tile_index(session)

	var rewards = DifficultyRulesScript.scale_reward_resources(session, _resource_site_claim_rewards(site))
	if not visit_cost.is_empty():
		_spend_resources(session, visit_cost)
	_add_resources(session, rewards)
	var disruption_message := apply_resource_site_disruption(
		session,
		node,
		site,
		previous_controller,
		"player"
	)
	var messages := [_resource_site_claim_message(site, previous_controller)]
	var cost_summary := _describe_resource_delta(visit_cost)
	if cost_summary != "":
		messages.append("Cost %s." % cost_summary)
	var reward_summary := _describe_resource_delta(rewards)
	if reward_summary != "":
		messages.append("Stores %s." % reward_summary)
	var recruit_message := _grant_site_claim_recruits(session, _resource_site_claim_recruits(site))
	if recruit_message != "":
		messages.append(recruit_message)
	var spell_message := _learn_site_spell(session, String(site.get("learn_spell_id", "")))
	if spell_message != "":
		messages.append(spell_message)
	if disruption_message != "":
		messages.append(disruption_message)
	messages.append_array(_award_experience(session, int(rewards.get("experience", 0))))
	var result := _finalize_action_result(session, true, " ".join(messages))
	return _attach_post_action_recap(
		result,
		session,
		"resource_site",
		{
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"previous_controller": previous_controller,
			"rewards": rewards,
		}
	)

static func collect_active_artifact(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var node_result := _find_active_artifact_node(session)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No artifact cache is here."}

	var node = node_result.get("node", {})
	if bool(node.get("collected", false)):
		return {"ok": false, "message": "This cache has already been claimed."}

	var pickup_result := _apply_artifact_claim(
		session,
		String(node.get("artifact_id", "")),
		"Recovered",
		true
	)
	if not bool(pickup_result.get("ok", false)):
		return {"ok": false, "message": String(pickup_result.get("message", "Artifact recovery failed."))}

	var nodes = session.overworld.get("artifact_nodes", [])
	node["collected"] = true
	node["collected_by_faction_id"] = "player"
	node["collected_day"] = session.day
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["artifact_nodes"] = nodes

	var result := _finalize_action_result(session, true, String(pickup_result.get("message", "Recovered artifact.")))
	return _attach_post_action_recap(
		result,
		session,
		"artifact",
		{
			"artifact_id": String(node.get("artifact_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
		}
	)

static func perform_context_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	if session == null:
		return {}
	if action_id == "collect_resource":
		return collect_active_resource(session)
	if action_id == "collect_artifact":
		return collect_active_artifact(session)
	if action_id == "capture_town":
		return capture_active_town(session)
	if action_id == "site_response":
		return _issue_active_site_response(session)
	if action_id.begins_with("build:"):
		return build_in_active_town(session, action_id.trim_prefix("build:"))
	if action_id.begins_with("recruit:"):
		return recruit_in_active_town(session, action_id.trim_prefix("recruit:"))
	return {}

static func set_active_town_visit(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	normalize_overworld_state(session)
	if session == null or placement_id == "":
		return {"ok": false, "message": "No town was selected.", "town": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or town.is_empty():
		clear_active_town_visit(session)
		return {"ok": false, "message": "The selected town is no longer available.", "town": {}}
	if String(town.get("owner", "neutral")) != "player":
		clear_active_town_visit(session)
		return {"ok": false, "message": "Only owned towns can be managed remotely.", "town": town}
	session.flags[ACTIVE_TOWN_PLACEMENT_KEY] = placement_id
	return {
		"ok": true,
		"message": "%s opens its gates." % _town_name(town),
		"town": town,
	}

static func clear_active_town_visit(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	session.flags.erase(ACTIVE_TOWN_PLACEMENT_KEY)

static func active_town_visit_result(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _find_active_town(session)

static func _resolve_post_move_interaction(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var encounter := get_active_encounter(session)
	if not encounter.is_empty():
		var battle_payload = _battle_rules().create_battle_payload(session, encounter)
		if battle_payload.is_empty():
			return {
				"ok": false,
				"message": "The enemy blocks the lane, but battle setup failed.",
				"route": "",
			}
		session.battle = battle_payload
		return {
			"ok": true,
			"message": describe_encounter_battle_cue(session, encounter),
			"route": "battle",
		}

	var resource_result := _find_active_resource_node(session)
	if int(resource_result.get("index", -1)) >= 0:
		var result := collect_active_resource(session)
		return {
			"ok": true,
			"message": String(result.get("message", "")),
			"route": "",
		}

	var artifact_result := _find_active_artifact_node(session)
	if int(artifact_result.get("index", -1)) >= 0:
		var result := collect_active_artifact(session)
		return {
			"ok": true,
			"message": String(result.get("message", "")),
			"route": "",
		}

	var town_result := _find_active_town(session)
	var town: Dictionary = town_result.get("town", {})
	if town.is_empty():
		return {"ok": true, "message": "", "route": ""}
	if String(town.get("owner", "neutral")) == "player":
		return {
			"ok": true,
			"message": "%s opens its gates." % _town_name(town),
			"route": "town",
		}
	return {
		"ok": true,
		"message": "%s remains under %s control." % [
			_town_name(town),
			String(town.get("owner", "neutral")).capitalize(),
		],
		"route": "",
	}

static func award_hero_artifact(
	session: SessionStateStoreScript.SessionData,
	artifact_id: String,
	source_verb: String = "Awarded",
	auto_equip: bool = true,
	evaluate_session: bool = true
) -> Dictionary:
	var result := _apply_artifact_claim(session, artifact_id, source_verb, auto_equip)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Artifact award failed."))}
	if not evaluate_session:
		return result
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func capture_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var town_result := _find_active_town(session)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No town stands here."}

	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) == "player":
		return {"ok": false, "message": "This town already flies your banner."}
	if String(town.get("owner", "neutral")) == "enemy" and _town_requires_assault(town):
		return _begin_town_assault(session, town)

	var result := _finalize_action_result(session, true, capture_town_by_placement(session, String(town.get("placement_id", ""))))
	return _attach_post_action_recap(
		result,
		session,
		"town_capture",
		{
			"placement_id": String(town.get("placement_id", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
		}
	)

static func capture_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> String:
	if session == null or placement_id == "":
		return ""
	var town_result := _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	return _claim_town(session, town_result)

static func transition_town_control(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	new_owner: String,
	controlling_faction_id: String = "",
	source: String = ""
) -> Dictionary:
	if session == null or placement_id == "":
		return {"ok": false, "changed": false, "town": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "changed": false, "town": {}}
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var previous_owner := String(town.get("owner", "neutral"))
	if previous_owner != new_owner and previous_owner == "player":
		town = _release_town_occupation_reserves(town)
	town["owner"] = new_owner
	town["front"] = _town_front_after_control_change(
		session,
		town,
		previous_owner,
		new_owner,
		controlling_faction_id,
		source
	)
	var available_recruits = town.get("available_recruits", {})
	if new_owner == "player" and (
		not (available_recruits is Dictionary)
		or (previous_owner != "enemy" and available_recruits is Dictionary and available_recruits.is_empty())
	):
		town["available_recruits"] = _seed_recruits_for_town(town)
	town["occupation"] = _town_occupation_after_control_change(
		session,
		town,
		previous_owner,
		new_owner,
		controlling_faction_id,
		source
	)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return {
		"ok": true,
		"changed": previous_owner != new_owner,
		"previous_owner": previous_owner,
		"town": town,
	}

static func stabilize_town_front(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	faction_id: String,
	source: String = "",
	bonus_days: int = 0
) -> Dictionary:
	if session == null or placement_id == "" or faction_id == "":
		return {"ok": false, "town": {}, "front": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "town": {}, "front": {}}
	var town = town_result.get("town", {})
	var towns = session.overworld.get("towns", [])
	town["front"] = _town_front_stabilizing_state(session, town, faction_id, source, "", bonus_days)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return {
		"ok": true,
		"town": town,
		"front": _town_front_state(session, town),
	}

static func describe_encounter_pressure(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	for_battle_prompt: bool = false
) -> String:
	return _encounter_pressure_summary(session, encounter, for_battle_prompt)

static func describe_encounter_readability_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var lines := []
	var role_parts := [
		_encounter_role_label(encounter),
		_encounter_risk_label(encounter),
		_encounter_difficulty_label(encounter),
	]
	var role_line := " | ".join(_non_empty_strings(role_parts))
	if role_line != "":
		lines.append("Role: %s" % role_line)
	var army_line := _encounter_army_surface(encounter, true)
	if army_line != "":
		lines.append("Army: %s" % army_line)
	var readiness_line := _encounter_readiness_surface(session, encounter)
	if readiness_line != "":
		lines.append(readiness_line)
	var reward_line := _encounter_reward_surface(encounter)
	if reward_line != "":
		lines.append("Reward: %s" % reward_line)
	var guard_line := _encounter_guard_summary(encounter, session)
	if guard_line != "":
		lines.append(guard_line)
	var consequence_line := describe_encounter_consequence_surface(session, encounter)
	if consequence_line != "":
		lines.append(consequence_line)
	var field_line := _encounter_field_objective_surface(encounter)
	if field_line != "":
		lines.append("Field: %s" % field_line)
	return "\n".join(lines)

static func describe_encounter_compact_readability(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var reward_summary := _encounter_reward_surface(encounter)
	var parts := [
		_encounter_risk_label(encounter),
		_encounter_difficulty_label(encounter),
		_encounter_army_surface(encounter, false),
		_encounter_readiness_surface(session, encounter, true),
		"" if reward_summary == "" else "Reward %s" % reward_summary,
	]
	var guard_line := _encounter_guard_summary(encounter, session)
	if guard_line != "":
		parts.append(guard_line)
	var consequence_line := describe_encounter_consequence_surface(session, encounter, true)
	if consequence_line != "":
		parts.append(consequence_line)
	return " | ".join(_non_empty_strings(parts))

static func describe_encounter_battle_cue(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var cue_parts := [
		_encounter_risk_label(encounter),
		_encounter_difficulty_label(encounter),
		_encounter_army_surface(encounter, false),
		_encounter_readiness_surface(session, encounter, true),
	]
	var guard_line := _encounter_guard_summary(encounter, session)
	if guard_line != "":
		cue_parts.append(guard_line)
	var consequence_line := describe_encounter_consequence_surface(session, encounter, true)
	if consequence_line != "":
		cue_parts.append(consequence_line)
	var cue := " | ".join(_non_empty_strings(cue_parts))
	if cue == "":
		return "Battle is joined against %s." % encounter_display_name(encounter)
	return "Battle is joined against %s. %s." % [encounter_display_name(encounter), cue]

static func describe_encounter_guard_link_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var guard := _encounter_guard_link(encounter)
	if guard.is_empty():
		return ""
	var role := String(guard.get("guard_role", "")).strip_edges()
	if role == "" or role == "none":
		return ""
	var target_label := _encounter_guard_target_label(session, guard)
	var parts := ["Guard %s" % _humanize_id(role)]
	if target_label != "":
		parts.append("Target %s" % target_label)
	if bool(guard.get("clear_required_for_target", false)):
		parts.append("clear required")
	elif bool(guard.get("blocks_approach", false)):
		parts.append("blocks approach")
	return " | ".join(parts)

static func describe_encounter_consequence_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	compact: bool = false
) -> String:
	var lines := []
	var guard_consequence := _encounter_guard_consequence_line(session, encounter, compact)
	if guard_consequence != "":
		lines.append(guard_consequence)
	var objective_consequence := _encounter_objective_consequence_line(session, encounter)
	if objective_consequence != "":
		lines.append(objective_consequence)
	var hook_consequence := _encounter_hook_consequence_line(session, encounter)
	if hook_consequence != "":
		lines.append(hook_consequence)
	var limit := 2 if compact else 3
	var visible := []
	for index in range(min(limit, lines.size())):
		visible.append(String(lines[index]))
	return " | ".join(_non_empty_strings(visible))

static func build_in_active_town(session: SessionStateStoreScript.SessionData, building_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var town_result := _find_active_town(session)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No town is available for construction here."}

	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return {"ok": false, "message": "Capture the town before issuing orders there."}

	var build_status := get_town_build_status(town, building_id)
	if not bool(build_status.get("buildable", false)):
		return {"ok": false, "message": String(build_status.get("blocked_message", "That building is not available in this town."))}

	var building: Dictionary = build_status.get("building", {})
	var cost = building.get("cost", {})
	if not _can_afford(session, cost):
		var readiness := town_cost_readiness(town, session.overworld.get("resources", {}), cost)
		var shortfall := _describe_cost_shortfall(readiness)
		return {
			"ok": false,
			"message": "Insufficient resources for %s.%s" % [
				String(building.get("name", building_id)),
				" Missing %s." % shortfall if shortfall != "" else "",
			],
		}

	var income_before := _calculate_town_income(town, session)
	var growth_before := _town_weekly_growth(town, session)
	_spend_resources(session, cost)
	var built_buildings = _normalize_built_buildings_for_town_state(town)
	built_buildings.append(building_id)
	town["built_buildings"] = built_buildings
	town["available_recruits"] = _add_recruit_growth(
		town.get("available_recruits", {}),
		HeroProgressionRulesScript.scale_recruit_growth(
			session.overworld.get("hero", {}),
			_building_growth_payload(building_id)
		)
	)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	var income_after := _calculate_town_income(town, session)
	var growth_after := _town_weekly_growth(town, session)
	var message_parts := ["Built %s in %s." % [String(building.get("name", building_id)), _town_name(town)]]
	var cost_summary := _describe_resource_delta(cost)
	if cost_summary != "":
		message_parts.append("Spent %s." % cost_summary)
	var income_change := _describe_resource_change(income_before, income_after)
	if income_change != "":
		message_parts.append("Daily income now %s (%s)." % [
			_describe_resource_delta(income_after),
			income_change,
		])
	var growth_change := _describe_recruit_projection(growth_before, growth_after)
	if growth_change != "":
		message_parts.append("Weekly muster %s." % growth_change)
	return _finalize_action_result(
		session,
		true,
		" ".join(message_parts)
	)

static func recruit_in_active_town(session: SessionStateStoreScript.SessionData, unit_id: String, requested_count: int = -1) -> Dictionary:
	normalize_overworld_state(session)
	var town_result := _find_active_town(session)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No town is available for recruitment here."}

	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return {"ok": false, "message": "Recruitment requires control of the town."}

	var recruits = town.get("available_recruits", {})
	var available_count := int(recruits.get(unit_id, 0))
	if available_count <= 0:
		return {"ok": false, "message": "No recruits are waiting for that unit."}

	var unit := ContentService.get_unit(unit_id)
	var adjusted_unit_cost := town_recruit_cost(session, town, unit_id)
	var max_affordable := _max_affordable_count(session, adjusted_unit_cost)
	var recruit_count = available_count if requested_count <= 0 else min(requested_count, available_count)
	recruit_count = min(recruit_count, max_affordable)
	if recruit_count <= 0:
		var readiness := town_cost_readiness(town, session.overworld.get("resources", {}), adjusted_unit_cost)
		var shortfall := _describe_cost_shortfall(readiness)
		return {
			"ok": false,
			"message": "Resources are too thin to recruit %s.%s" % [
				String(unit.get("name", unit_id)),
				" Missing %s." % shortfall if shortfall != "" else "",
			],
		}

	var recruit_cost := _multiply_cost(adjusted_unit_cost, recruit_count)
	_spend_resources(session, recruit_cost)
	recruits[unit_id] = available_count - recruit_count
	town["available_recruits"] = recruits
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns

	var army = session.overworld.get("army", {})
	var stacks = army.get("stacks", [])
	var merged := false
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			stack["count"] = int(stack.get("count", 0)) + recruit_count
			stacks[index] = stack
			merged = true
			break
	if not merged:
		stacks.append({"unit_id": unit_id, "count": recruit_count})
	army["stacks"] = stacks
	session.overworld["army"] = army
	var field_total := _army_unit_count(stacks, unit_id)
	var message_parts := ["Recruited %d %s." % [recruit_count, String(unit.get("name", unit_id))]]
	var cost_summary := _describe_resource_delta(recruit_cost)
	if cost_summary != "":
		message_parts.append("Spent %s." % cost_summary)
	message_parts.append("%d remain in town reserve; field army now has %d." % [
		max(0, int(recruits.get(unit_id, 0))),
		field_total,
	])
	return _finalize_action_result(
		session,
		true,
		" ".join(message_parts)
	)

static func cast_overworld_spell(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var hero = session.overworld.get("hero", {})
	var movement = session.overworld.get("movement", {})
	var result := SpellRulesScript.cast_overworld_spell(hero, movement, spell_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Spell casting failed."))}

	session.overworld["hero"] = result.get("hero", hero)
	session.overworld["movement"] = result.get("movement", movement)
	return _attach_post_action_recap(
		_finalize_action_result(session, true, String(result.get("message", ""))),
		session,
		"spell",
		{
			"spell_id": String(result.get("spell_id", spell_id)),
			"spell_name": String(result.get("spell_name", spell_id)),
			"target_contract": result.get("target_contract", {}),
			"consequence_preview": result.get("consequence_preview", {}),
		}
	)

static func equip_artifact(session: SessionStateStoreScript.SessionData, artifact_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.equip_artifact(session.overworld.get("hero", {}), artifact_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to equip artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func unequip_artifact(session: SessionStateStoreScript.SessionData, slot: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.unequip_artifact(session.overworld.get("hero", {}), slot)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to stow artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func perform_artifact_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.perform_management_action(session.overworld.get("hero", {}), action_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to manage artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func get_active_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var pos := hero_position(session)
	if not is_tile_visible(session, pos.x, pos.y):
		return {"type": "empty"}

	var town_result := _find_active_town(session)
	if int(town_result.get("index", -1)) >= 0:
		return {"type": "town", "town": town_result.get("town", {})}

	var resource_result := _find_context_resource_node(session)
	if int(resource_result.get("index", -1)) >= 0:
		return {"type": "resource", "node": resource_result.get("node", {})}

	var artifact_result := _find_active_artifact_node(session)
	if int(artifact_result.get("index", -1)) >= 0:
		return {"type": "artifact", "node": artifact_result.get("node", {})}

	var encounter := get_active_encounter(session)
	if not encounter.is_empty():
		return {"type": "encounter", "encounter": encounter}

	return {"type": "empty"}

static func get_active_encounter(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	if not is_tile_visible(session, pos.x, pos.y):
		return {}
	var encounters = session.overworld.get("encounters", [])
	for encounter in encounters:
		if not (encounter is Dictionary):
			continue
		if _position_matches(encounter, pos) and not is_encounter_resolved(session, encounter):
			return encounter
	return {}

static func encounter_commander_name(encounter: Dictionary) -> String:
	if encounter.is_empty() or String(encounter.get("spawned_by_faction_id", "")) == "":
		return ""
	return String(_enemy_adventure_rules().raid_commander_display_name(encounter))

static func encounter_commander_threat_label(encounter: Dictionary) -> String:
	var commander_name := encounter_commander_name(encounter)
	if commander_name == "":
		return ""
	var memory_brief := String(_enemy_adventure_rules().commander_memory_brief(encounter.get("enemy_commander_state", {})))
	var army_brief := String(_enemy_adventure_rules().commander_army_brief(encounter.get("enemy_commander_state", {})))
	var outcome_brief := String(_enemy_adventure_rules().commander_recent_outcome_brief(encounter.get("enemy_commander_state", {})))
	var parts := []
	if outcome_brief != "":
		parts.append(outcome_brief)
	if memory_brief != "":
		parts.append(memory_brief)
	if army_brief != "":
		parts.append(army_brief)
	if parts.is_empty():
		return commander_name
	return "%s (%s)" % [commander_name, "; ".join(parts)]

static func encounter_display_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return "Hostile contact"
	if String(encounter.get("spawned_by_faction_id", "")) != "":
		var raid_name: String = String(_enemy_adventure_rules().raid_display_name(encounter))
		if raid_name != "":
			return raid_name
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return String(encounter_def.get("name", encounter.get("placement_id", "Hostile contact")))

static func is_encounter_resolved(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	var resolved = session.overworld.get("resolved_encounters", [])
	return resolved is Array and encounter_key(encounter) in resolved

static func encounter_key(encounter: Dictionary) -> String:
	var placement_id := String(encounter.get("placement_id", ""))
	if placement_id != "":
		return placement_id
	return "%d,%d,%s" % [
		int(encounter.get("x", -1)),
		int(encounter.get("y", -1)),
		String(encounter.get("encounter_id", encounter.get("id", "")))
	]

static func hero_position(session: SessionStateStoreScript.SessionData) -> Vector2i:
	var pos = session.overworld.get("hero_position", {"x": 0, "y": 0})
	return Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))

static func derive_map_size(session: SessionStateStoreScript.SessionData) -> Vector2i:
	var stored_size = session.overworld.get("map_size", {})
	if stored_size is Dictionary:
		var width := int(stored_size.get("width", 0))
		var height := int(stored_size.get("height", 0))
		if width > 0 and height > 0:
			return Vector2i(width, height)

	var map_data = session.overworld.get("map", [])
	var height_from_map = map_data.size() if map_data is Array else 0
	var width_from_map := 0
	if height_from_map > 0 and map_data[0] is Array:
		width_from_map = map_data[0].size()
	return Vector2i(max(width_from_map, 1), max(height_from_map, 1))

static func overworld_object_placement_pathing_surface(
	session: SessionStateStoreScript.SessionData,
	placement_id: String
) -> Dictionary:
	if session == null or placement_id == "":
		return {}
	var node_result := _find_resource_node_by_placement(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0 or node.is_empty():
		return {}
	var map_object := _map_object_for_resource_node(node)
	if map_object.is_empty():
		return {}
	var body_tiles := _map_object_world_body_tiles(map_object, node)
	var interaction_tiles := _map_object_world_interaction_tiles(map_object, node)
	var footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var width: int = maxi(1, int(footprint.get("width", 1)))
	var height: int = maxi(1, int(footprint.get("height", 1)))
	var origin := _map_object_footprint_origin(map_object, node)
	var body_payload := []
	for tile in body_tiles:
		body_payload.append(_tile_payload(tile))
	var interaction_payload := []
	for tile in interaction_tiles:
		interaction_payload.append(_tile_payload(tile))
	return {
		"placement_id": placement_id,
		"site_id": String(node.get("site_id", "")),
		"object_id": String(map_object.get("id", "")),
		"footprint": {
			"width": width,
			"height": height,
			"anchor": String(footprint.get("anchor", "bottom_center")),
			"origin": _tile_payload(origin),
			"visual_tile_count": width * height,
		},
		"body_tiles": body_payload,
		"interaction_tiles": interaction_payload,
		"body_tile_count": body_payload.size(),
		"interaction_tile_count": interaction_payload.size(),
		"uses_authored_body_tiles": map_object.get("body_tiles", []) is Array and not map_object.get("body_tiles", []).is_empty(),
		"uses_authored_approach": map_object.get("approach", {}) is Dictionary and not map_object.get("approach", {}).is_empty(),
		"blocks_body_tiles": _map_object_blocks_body_tiles(map_object),
		"blocks_visual_footprint_rectangle": false,
	}

static func tile_is_blocked(session: SessionStateStoreScript.SessionData, x: int, y: int) -> bool:
	var map_data = session.overworld.get("map", [])
	if y < 0 or not (map_data is Array) or y >= map_data.size():
		return false
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return false
	var terrain_id := String(row[x])
	var biome := ContentService.get_biome_for_terrain(terrain_id)
	if not biome.is_empty() and biome.has("passable"):
		if not bool(biome.get("passable", true)):
			return true
	elif terrain_id == "water":
		return true
	return _blocked_tile_index(session).has(_tile_key(Vector2i(x, y)))

static func _tile_blocked_by_resource_object(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> bool:
	if session == null:
		return false
	return _blocked_tile_index(session).has(_tile_key(tile))

static func _refresh_blocked_tile_index(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	_blocked_tile_indexes[str(session.session_id)] = _build_blocked_tile_index(session)

static func _blocked_tile_index(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	var session_id := str(session.session_id)
	if not _blocked_tile_indexes.has(session_id):
		_refresh_blocked_tile_index(session)
	return _blocked_tile_indexes.get(session_id, {})

static func _build_blocked_tile_index(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var index := {}
	if session == null:
		return index
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var map_object := _map_object_for_resource_node(node)
		if map_object.is_empty() or not _map_object_blocks_body_tiles(map_object):
			continue
		for body_tile in _map_object_world_body_tiles(map_object, node):
			if body_tile is Vector2i:
				index[_tile_key(body_tile)] = true
	return index

static func _map_object_for_resource_node(node: Dictionary) -> Dictionary:
	return ContentService.get_map_object_for_resource_site(String(node.get("site_id", "")))

static func _map_object_blocks_body_tiles(map_object: Dictionary) -> bool:
	var body_tiles = map_object.get("body_tiles", [])
	if not (body_tiles is Array) or body_tiles.is_empty():
		return false
	var passability_class := String(map_object.get("passability_class", ""))
	if passability_class in ["passable_visit_on_enter", "passable_scenic"]:
		return false
	if passability_class in ["blocking_visitable", "blocking_non_visitable", "edge_blocker", "conditional_pass", "town_blocking", "neutral_stack_blocking"]:
		return true
	return not bool(map_object.get("passable", true))

static func _map_object_world_body_tiles(map_object: Dictionary, placement: Dictionary) -> Array:
	var tiles := []
	var origin := _map_object_footprint_origin(map_object, placement)
	var body_tiles = map_object.get("body_tiles", [])
	if not (body_tiles is Array):
		return tiles
	for body_value in body_tiles:
		if not (body_value is Dictionary):
			continue
		tiles.append(origin + Vector2i(int(body_value.get("x", 0)), int(body_value.get("y", 0))))
	return tiles

static func _map_object_world_interaction_tiles(map_object: Dictionary, placement: Dictionary) -> Array:
	var tiles := []
	var origin := _map_object_footprint_origin(map_object, placement)
	var approach: Dictionary = map_object.get("approach", {}) if map_object.get("approach", {}) is Dictionary else {}
	var offsets = approach.get("visit_offsets", [])
	if offsets is Array and not offsets.is_empty():
		for offset_value in offsets:
			if not (offset_value is Dictionary):
				continue
			tiles.append(origin + Vector2i(int(offset_value.get("x", 0)), int(offset_value.get("y", 0))))
		return tiles
	return [Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0)))]

static func _map_object_footprint_origin(map_object: Dictionary, placement: Dictionary) -> Vector2i:
	var footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var width: int = maxi(1, int(footprint.get("width", 1)))
	var height: int = maxi(1, int(footprint.get("height", 1)))
	var anchor := String(footprint.get("anchor", "bottom_center"))
	var anchor_tile := Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0)))
	match anchor:
		"top_left":
			return anchor_tile
		"center":
			return anchor_tile - Vector2i(int(width / 2), int(height / 2))
		"bottom_left":
			return anchor_tile - Vector2i(0, height - 1)
		"bottom_right":
			return anchor_tile - Vector2i(width - 1, height - 1)
		_:
			return anchor_tile - Vector2i(int(width / 2), height - 1)

static func _resource_node_matches_interaction_tile(node: Dictionary, tile: Vector2i) -> bool:
	var map_object := _map_object_for_resource_node(node)
	if map_object.is_empty():
		return _position_matches(node, tile)
	for interaction_tile in _map_object_world_interaction_tiles(map_object, node):
		if interaction_tile == tile:
			return true
	return false

static func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

static func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func terrain_profile_at(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	var terrain_id := _terrain_id_at(session, x, y)
	var biome := ContentService.get_biome_for_terrain(terrain_id)
	if biome.is_empty():
		return {
			"terrain_id": terrain_id,
			"name": terrain_id.capitalize() if terrain_id != "" else "Unknown terrain",
			"movement_cost": 1,
			"sight_modifier": 0,
			"passable": terrain_id != "water",
		}
	var profile := biome.duplicate(true)
	profile["terrain_id"] = terrain_id
	return profile

static func describe_resources(session: SessionStateStoreScript.SessionData) -> String:
	var resources = session.overworld.get("resources", {})
	return "Gold %d | Wood %d | Ore %d" % [
		int(resources.get("gold", 0)),
		int(resources.get("wood", 0)),
		int(resources.get("ore", 0)),
	]

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var pos := hero_position(session)
	var movement = session.overworld.get("movement", {})
	var days_until_growth := days_until_next_weekly_growth(session.day)
	return "Week %d Day %d | Pos %d,%d | Move %d/%d | %s | Muster Day %d in %d day%s" % [
		_week_of_day(session.day),
		_weekday_of_day(session.day),
		pos.x,
		pos.y,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		describe_visibility(session),
		next_weekly_growth_day(session.day),
		days_until_growth,
		"" if days_until_growth == 1 else "s",
	]

static func describe_objective_brief(session: SessionStateStoreScript.SessionData) -> String:
	var surface := _objective_stakes_surface(session)
	if surface.is_empty():
		return "Objectives unavailable"

	var line := "%s | Objectives %d/%d" % [
		String(surface.get("mode_label", "Scenario")),
		int(surface.get("victory_met", 0)),
		int(surface.get("victory_total", 0)),
	]
	var next_objective := String(surface.get("next_objective", ""))
	if next_objective != "":
		line += " | Next %s" % _short_player_text(next_objective, 32)
	elif int(surface.get("victory_total", 0)) > 0:
		line += " | Victory ready"
	var watch_objective := String(surface.get("watch_objective", ""))
	if watch_objective != "":
		line += " | Watch %s" % _short_player_text(watch_objective, 28)
	return line

static func describe_objective_stakes_board(session: SessionStateStoreScript.SessionData) -> String:
	var surface := _objective_stakes_surface(session)
	if surface.is_empty():
		return "Objective Stakes\nNo authored scenario objectives are available."

	var lines := [
		"Objective Stakes",
		String(surface.get("context_line", "Scenario context unavailable.")),
		"Progress: %d/%d victory complete | %d/%d defeat risks triggered" % [
			int(surface.get("victory_met", 0)),
			int(surface.get("victory_total", 0)),
			int(surface.get("defeat_triggered", 0)),
			int(surface.get("defeat_total", 0)),
		],
	]
	var campaign_stakes := String(surface.get("campaign_stakes", ""))
	if campaign_stakes != "":
		lines.append("Campaign stakes: %s" % campaign_stakes)
	else:
		lines.append("Skirmish context: self-contained run; no campaign carryover changes.")
	var next_objective := String(surface.get("next_objective", ""))
	lines.append("Next objective: %s" % (next_objective if next_objective != "" else "All victory objectives are complete."))

	var completed: Array = surface.get("completed_objectives", [])
	var incomplete: Array = surface.get("incomplete_objectives", [])
	lines.append("Complete: %s" % _join_limited_labels(completed, 3, "none"))
	lines.append("Incomplete: %s" % _join_limited_labels(incomplete, 3, "none"))
	var defeat_watch: Array = surface.get("defeat_watch", [])
	lines.append("Defeat watch: %s" % _join_limited_labels(defeat_watch, 2, "clear"))

	var victory_text := String(surface.get("victory_text", ""))
	if victory_text != "":
		lines.append("Win: %s" % victory_text)
	var defeat_text := String(surface.get("defeat_text", ""))
	if defeat_text != "":
		lines.append("Lose: %s" % defeat_text)
	var campaign_arc := String(surface.get("campaign_arc", ""))
	if campaign_arc != "":
		lines.append("Campaign arc: %s" % campaign_arc)
	var progress_recap: String = _scenario_rules().describe_session_progress_recap(session, false)
	if progress_recap != "":
		lines.append(progress_recap)
	return "\n".join(lines)

static func _week_of_day(day: int) -> int:
	return int(floori(float(max(day, 1) - 1) / 7.0)) + 1

static func _weekday_of_day(day: int) -> int:
	return ((max(day, 1) - 1) % 7) + 1

static func describe_hero(session: SessionStateStoreScript.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	var scenario := ContentService.get_scenario(session.scenario_id)
	return "\n".join(
		[
			HeroCommandRulesScript.hero_identity_context_line(hero, String(scenario.get("player_faction_id", ""))),
			HeroCommandRulesScript.hero_progress_context_line(hero),
			HeroCommandRulesScript.hero_readiness_context_line(hero, true),
		]
	)

static func _overworld_hero_line(hero: Dictionary) -> String:
	return "%s | %s | %s" % [
		HeroCommandRulesScript.hero_identity_context_line(hero),
		HeroCommandRulesScript.hero_progress_context_line(hero),
		HeroCommandRulesScript.hero_readiness_context_line(hero, true),
	]

static func describe_heroes(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var lines := ["Command Wing"]
	var reserves := []
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var line := _overworld_hero_line(hero)
		if String(hero.get("id", "")) == active_hero_id:
			lines.append("- Active command: %s" % line)
		else:
			reserves.append("- Reserve command: %s" % line)
	if reserves.is_empty():
		lines.append("- No reserve commanders are currently marching under the banner.")
	else:
		lines.append("- Reserve roster %d" % reserves.size())
		for reserve in reserves:
			lines.append(reserve)
	return "\n".join(lines)

static func describe_army(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return "Marching Army\n0 troops in 0 groups | Strength 0\nNo standing force"
	var army = session.overworld.get("army", {})
	var lines := []
	var headcount := 0
	var strength := 0
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		headcount += count
		strength += unit_stack_strength_value(String(stack.get("unit_id", "")), count)
		lines.append("- %s" % describe_stack_inspection_line(stack))
	return "Marching Army\n%d troops in %d groups | Strength %d\n%s" % [
		headcount,
		lines.size(),
		strength,
		"\n".join(lines) if not lines.is_empty() else "No standing force",
	]

static func describe_stack_inspection_line(stack: Dictionary, options: Dictionary = {}) -> String:
	var unit_id := String(stack.get("unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var unit_name := String(unit.get("name", unit_id))
	var count := _stack_display_count(stack, unit)
	var health := _stack_display_health(stack, unit, count)
	var max_health := _stack_display_max_health(stack, unit, count)
	var health_text := "%d/%d" % [health, max_health] if max_health > health else "%d" % health
	var include_name := bool(options.get("include_name", true))
	var parts := []
	if include_name:
		parts.append("%s x%d" % [unit_name, count])
	else:
		parts.append("Count %d" % count)
	parts.append("%s %s" % [unit_tier_label(unit), unit_role_label(unit)])
	parts.append("HP %s" % health_text)
	parts.append("Strength %d" % unit_stack_strength_value(unit_id, count))
	parts.append(_stack_readiness_label(stack, health, max_health))
	return " | ".join(parts)

static func describe_unit_recruit_brief(unit_id: String, count: int = 0) -> String:
	var unit := ContentService.get_unit(unit_id)
	if unit.is_empty():
		return "Unknown unit"
	var strength_count: int = max(1, count)
	var strength_label: String = "reserve" if count > 0 else "each"
	return "%s %s | HP %d each | Strength %d %s" % [
		unit_tier_label(unit),
		unit_role_label(unit),
		max(1, int(unit.get("hp", 1))),
		unit_stack_strength_value(unit_id, strength_count),
		strength_label,
	]

static func unit_tier_label(unit: Dictionary) -> String:
	return "T%d" % max(1, int(unit.get("tier", 1)))

static func unit_role_label(unit: Dictionary) -> String:
	var role := String(unit.get("role", "")).strip_edges()
	if role == "":
		role = "ranged" if bool(unit.get("ranged", false)) else "melee"
	return role.capitalize()

static func unit_stack_strength_value(unit_id: String, count: int) -> int:
	var unit := ContentService.get_unit(unit_id)
	if unit.is_empty() or count <= 0:
		return 0
	return max(0, count) * unit_strength_value(unit_id)

static func unit_strength_value(unit_id: String) -> int:
	var unit := ContentService.get_unit(unit_id)
	if unit.is_empty():
		return 0
	var damage_average := int(round(float(int(unit.get("min_damage", 1)) + int(unit.get("max_damage", 1))) / 2.0))
	return (
		max(1, int(unit.get("hp", 1)))
		+ max(0, int(unit.get("attack", 0)))
		+ max(0, int(unit.get("defense", 0)))
		+ max(1, damage_average)
		+ max(1, int(unit.get("speed", 1)))
		+ max(1, int(unit.get("initiative", 1)))
		+ (3 if bool(unit.get("ranged", false)) else 0)
		+ max(0, int(unit.get("tier", 1)) - 1)
	)

static func _stack_display_count(stack: Dictionary, unit: Dictionary) -> int:
	if stack.has("total_health"):
		var unit_hp: int = max(1, int(stack.get("unit_hp", unit.get("hp", 1))))
		return max(0, int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp))))
	if stack.has("count"):
		return max(0, int(stack.get("count", 0)))
	return max(0, int(stack.get("base_count", 0)))

static func _stack_display_health(stack: Dictionary, unit: Dictionary, count: int) -> int:
	if stack.has("total_health"):
		return max(0, int(stack.get("total_health", 0)))
	return max(0, count) * max(1, int(unit.get("hp", 1)))

static func _stack_display_max_health(stack: Dictionary, unit: Dictionary, count: int) -> int:
	var unit_hp: int = max(1, int(stack.get("unit_hp", unit.get("hp", 1))))
	if stack.has("base_count"):
		return max(0, int(stack.get("base_count", 0))) * unit_hp
	return max(0, count) * unit_hp

static func _stack_readiness_label(stack: Dictionary, health: int, max_health: int) -> String:
	if health <= 0:
		return "Broken"
	if bool(stack.get("defending", false)):
		return "Braced"
	if max_health <= 0:
		return "Ready"
	var ratio := float(health) / float(max_health)
	if ratio < 0.35:
		return "Critical"
	if ratio < 0.70:
		return "Wounded"
	return "Ready"

static func is_weekly_growth_day(day: int) -> bool:
	return day > 1 and ((day - 1) % WEEKLY_GROWTH_INTERVAL) == 0

static func days_until_next_weekly_growth(day: int) -> int:
	return WEEKLY_GROWTH_INTERVAL - ((max(day, 1) - 1) % WEEKLY_GROWTH_INTERVAL)

static func next_weekly_growth_day(day: int) -> int:
	return max(day, 1) + days_until_next_weekly_growth(day)

static func describe_town_context(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	var income := _describe_resource_delta(_calculate_town_income(town, session))
	var weekly_growth := _describe_recruit_delta(town_weekly_growth(town, session))
	var defense := _town_defense_summary(town)
	var readiness := town_battle_readiness(town, session)
	var pressure_output := town_pressure_output(town, session)
	var strategic_role := town_strategic_role(town)
	var capital_project := town_capital_project_state(town, session)
	var battlefront := town_battlefront_profile(town)
	var occupation := town_occupation_state(session, town)
	var parts := [
		_town_name(town),
		String(ContentService.get_faction(_town_faction_id(town)).get("name", _town_faction_id(town))),
		"Owner %s" % String(town.get("owner", "neutral")).capitalize(),
	]
	if strategic_role == "capital":
		parts.append("Capital Anchor")
	elif strategic_role == "stronghold":
		parts.append("Frontier Stronghold")
	for identity_line in _town_identity_surface(town, session).split("\n"):
		var line := String(identity_line)
		if line.begins_with("Economy: ") or line.begins_with("Magic: ") or line.begins_with("Strategic cue: "):
			parts.append(line)
	if income != "":
		parts.append("Daily %s" % income)
	if weekly_growth != "":
		parts.append("Weekly %s" % weekly_growth)
	if bool(occupation.get("active", false)):
		parts.append("Pacifying %d day%s" % [
			int(occupation.get("days_to_clear", 0)),
			"" if int(occupation.get("days_to_clear", 0)) == 1 else "s",
		])
	if defense != "":
		parts.append("Defense %s" % defense)
	if String(town.get("owner", "neutral")) == "enemy" and _town_garrison_headcount(town) > 0:
		parts.append(
			"Garrison %d troops/%d companies" % [_town_garrison_headcount(town), _town_garrison_company_count(town)]
		)
		if _town_requires_assault(town):
			parts.append("Assault required")
	if readiness > 0:
		parts.append("Readiness %d" % readiness)
	if pressure_output > 0:
		parts.append("%s %d" % [_town_pressure_label(town), pressure_output])
	if String(battlefront.get("label", "")) != "":
		parts.append(String(battlefront.get("label", "")))
	if bool(capital_project.get("active", false)):
		parts.append("Project online")
	elif int(capital_project.get("total", 0)) > 0:
		parts.append("Project dormant")
	if session != null:
		var logistics := town_logistics_state(session, town)
		if String(logistics.get("summary", "")) != "":
			parts.append("Logistics %s" % String(logistics.get("summary", "")))
		var recovery := town_recovery_state(session, town)
		if bool(recovery.get("active", false)):
			parts.append("Recovery %s" % String(recovery.get("summary", "")))
	return " | ".join(parts)

static func describe_visibility_panel(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var controlled_outposts := controlled_resource_site_count(session, "player", "faction_outpost")
	var controlled_shrines := controlled_resource_site_count(session, "player", "frontier_shrine")
	var controlled_scouting := controlled_resource_site_count(session, "player", "scouting_structure")
	var lines := [
		"Scout Net",
		"- %s" % describe_visibility(session),
		"- Controlled heroes %d | Current reveal radius follows every marching commander." % HeroCommandRulesScript.player_hero_count(session),
	]
	if controlled_outposts > 0:
		lines.append("- Held outposts %d | Frontier relays extend sight beyond commander scout rings." % controlled_outposts)
	if controlled_scouting > 0:
		lines.append("- Held scout structures %d | Watch sites widen route certainty before raids close." % controlled_scouting)
	if controlled_shrines > 0:
		lines.append("- Held shrines %d | Sanctums keep spell routes open across the frontier." % controlled_shrines)
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var position = hero.get("position", {})
		lines.append(
			"- %s | Pos %d,%d | Scout %d%s" % [
				String(hero.get("name", "Hero")),
				int(position.get("x", 0)),
				int(position.get("y", 0)),
				HeroCommandRulesScript.scouting_radius_for_hero(hero),
				" | Active" if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")) else "",
			]
		)
	return "\n".join(lines)

static func describe_context(session: SessionStateStoreScript.SessionData) -> String:
	var context := get_active_context(session)
	var pos := hero_position(session)
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			return "Town Tile\nTerrain %s | %s\n%s" % [
				terrain,
				_town_name(town),
				describe_town_context(town, session),
			]
		"resource":
			var node = context.get("node", {})
			var site = ContentService.get_resource_site(String(node.get("site_id", "")))
			return "%s\nTerrain %s | %s\n%s" % [
				_resource_site_role_label(node, site),
				terrain,
				String(site.get("name", "Resource Cache")),
				_resource_site_context_summary(session, node, site),
			]
		"artifact":
			var artifact_node = context.get("node", {})
			return "Artifact Cache\nTerrain %s\n%s" % [
				terrain,
				ArtifactRulesScript.describe_artifact_inspection(
					session.overworld.get("hero", {}),
					String(artifact_node.get("artifact_id", "")),
					bool(artifact_node.get("collected", false)),
					String(artifact_node.get("collected_by_faction_id", ""))
				),
			]
		"encounter":
			var placement = context.get("encounter", {})
			var object_surface := describe_encounter_object_surface(placement)
			return "Hostile Contact\nTerrain %s | %s%s\n%s\n%s" % [
				terrain,
				encounter_display_name(placement),
				"" if object_surface == "" else " | %s" % object_surface,
				describe_encounter_readability_surface(session, placement),
				_encounter_pressure_summary(session, placement),
			]
		_:
			return "Open Ground\nTerrain %s | No immediate site action.\nUse the movement controls to scout, consolidate towns, or intercept raids." % terrain

static func _terrain_name_at(session: SessionStateStoreScript.SessionData, x: int, y: int) -> String:
	var terrain := _terrain_id_at(session, x, y)
	var biome := ContentService.get_biome_for_terrain(terrain)
	if not biome.is_empty():
		return String(biome.get("name", terrain.capitalize()))
	return terrain.capitalize() if terrain != "" else "Unknown terrain"

static func _terrain_id_at(session: SessionStateStoreScript.SessionData, x: int, y: int) -> String:
	var map_data = session.overworld.get("map", [])
	if y < 0 or not (map_data is Array) or y >= map_data.size():
		return ""
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return ""
	return String(row[x])

static func describe_objective_board(session: SessionStateStoreScript.SessionData) -> String:
	_normalize_scenario_state_rules(session)
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return "Objectives\n- No authored objectives."

	var victory_total := 0
	var victory_met := 0
	var defeat_total := 0
	var defeat_triggered := 0
	for objective in objectives.get("victory", []):
		if objective is Dictionary:
			victory_total += 1
			if _scenario_is_objective_met(session, String(objective.get("id", "")), "victory"):
				victory_met += 1
	for objective in objectives.get("defeat", []):
		if objective is Dictionary:
			defeat_total += 1
			if _scenario_is_objective_met(session, String(objective.get("id", "")), "defeat"):
				defeat_triggered += 1
	return "Objective Board\nVictory %d/%d | Defeat risks %d/%d triggered\n%s" % [
		victory_met,
		victory_total,
		defeat_triggered,
		defeat_total,
		"%s\n%s" % [
			_scenario_describe_objectives(session),
			_scenario_rules().describe_session_progress_recap(session, false),
		],
	]

static func describe_objectives(session: SessionStateStoreScript.SessionData) -> String:
	return describe_objective_board(session)

static func _objective_stakes_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	if session == null or session.scenario_id == "":
		return {}
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return {}

	var victory_total := 0
	var victory_met := 0
	var defeat_total := 0
	var defeat_triggered := 0
	var completed: Array = []
	var incomplete: Array = []
	var defeat_watch: Array = []
	var next_objective := ""
	var watch_objective := ""

	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		victory_total += 1
		var label := _scenario_objective_player_label(session, objective)
		if _scenario_objective_met(session, objective):
			victory_met += 1
			if label != "":
				completed.append(label)
		else:
			if label != "":
				incomplete.append(label)
				if next_objective == "":
					next_objective = label

	for objective in objectives.get("defeat", []):
		if not (objective is Dictionary):
			continue
		defeat_total += 1
		var label := _scenario_objective_player_label(session, objective)
		if _scenario_objective_met(session, objective):
			defeat_triggered += 1
		if label != "":
			defeat_watch.append(label)
			if watch_objective == "":
				watch_objective = label

	var campaign_context := _campaign_context_for_session(session, scenario)
	return {
		"mode_label": String(campaign_context.get("mode_label", "Scenario")),
		"context_line": String(campaign_context.get("context_line", "")),
		"campaign_stakes": String(campaign_context.get("campaign_stakes", "")),
		"campaign_arc": String(campaign_context.get("campaign_arc", "")),
		"victory_total": victory_total,
		"victory_met": victory_met,
		"defeat_total": defeat_total,
		"defeat_triggered": defeat_triggered,
		"next_objective": next_objective,
		"watch_objective": watch_objective,
		"completed_objectives": completed,
		"incomplete_objectives": incomplete,
		"defeat_watch": defeat_watch,
		"victory_text": String(objectives.get("victory_text", "")),
		"defeat_text": String(objectives.get("defeat_text", "")),
	}

static func _campaign_context_for_session(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> Dictionary:
	var scenario_name := String(scenario.get("name", session.scenario_id))
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	if launch_mode != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		return {
			"mode_label": "Skirmish",
			"context_line": "Skirmish: %s | Day %d" % [scenario_name, session.day],
			"campaign_stakes": "",
			"campaign_arc": "",
		}

	var campaign_id := String(session.flags.get("campaign_id", ""))
	if campaign_id == "":
		campaign_id = _campaign_rules().get_campaign_id_for_scenario(session.scenario_id)
	var campaign := ContentService.get_campaign(campaign_id)
	var entry := _campaign_scenario_entry(campaign, session.scenario_id)
	var campaign_name := String(session.flags.get("campaign_name", campaign.get("name", campaign_id)))
	var chapter_label := String(session.flags.get("campaign_chapter_label", entry.get("label", scenario_name)))
	return {
		"mode_label": "Campaign",
		"context_line": "Campaign: %s | %s | Day %d" % [campaign_name, chapter_label, session.day],
		"campaign_stakes": String(entry.get("stakes", "")),
		"campaign_arc": String(campaign.get("arc_goal", "")),
	}

static func _campaign_scenario_entry(campaign: Dictionary, scenario_id: String) -> Dictionary:
	for entry in campaign.get("scenarios", []):
		if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
			return entry
	return {}

static func _scenario_objective_player_label(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> String:
	var label := String(_scenario_rules()._objective_label(session, objective)).strip_edges()
	return label if label != "" else String(objective.get("label", objective.get("id", "Objective")))

static func _join_limited_labels(labels: Array, limit: int, fallback: String) -> String:
	if labels.is_empty():
		return fallback
	var visible := []
	for index in range(min(max(1, limit), labels.size())):
		visible.append(String(labels[index]))
	if labels.size() > visible.size():
		visible.append("%d more" % (labels.size() - visible.size()))
	return "; ".join(visible)

static func _short_player_text(text: String, max_chars: int) -> String:
	var compact := text.strip_edges().replace("\n", " ")
	while compact.find("  ") >= 0:
		compact = compact.replace("  ", " ")
	if compact.length() <= max_chars:
		return compact
	return "%s..." % compact.left(max(1, max_chars - 3)).strip_edges()

static func describe_frontier_threats(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var lines := ["Frontier Watch"]
	var global_threats: String = _describe_enemy_threats(session)
	if global_threats == "":
		lines.append("- No hostile factions are active.")
	else:
		lines.append(global_threats)
	var local_warning := _local_visible_threat_summary(session)
	if local_warning != "":
		lines.append("Local watch: %s" % local_warning)
	var occupation_watch := _occupied_town_watch_summary(session)
	if occupation_watch != "":
		lines.append("Occupation watch: %s" % occupation_watch)
	lines.append("Defense readiness: %s" % describe_defense_readiness_warnings(session))
	return "\n".join(lines)

static func describe_defense_readiness_warnings(session: SessionStateStoreScript.SessionData, limit: int = 2) -> String:
	normalize_overworld_state(session)
	var items := _defense_readiness_warning_items(session)
	if items.is_empty():
		return "No exposed town or route-defense warning is visible."
	var fragments := []
	var max_items := clampi(limit, 1, 4)
	for index in range(min(max_items, items.size())):
		var item: Dictionary = items[index]
		fragments.append("%s: %s Why: %s Next: %s" % [
			String(item.get("label", "Town front")),
			_short_player_text(String(item.get("context", "")), 128),
			_short_player_text(String(item.get("why", "")), 112),
			_short_player_text(String(item.get("next_step", "")), 112),
		])
	if items.size() > max_items:
		fragments.append("+%d more town/front warning%s" % [
			items.size() - max_items,
			"" if items.size() - max_items == 1 else "s",
		])
	return " | ".join(fragments)

static func describe_town_defense_readiness_warning(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary
) -> String:
	normalize_overworld_state(session)
	if town.is_empty():
		return "No town front is selected."
	var item := _defense_readiness_warning_item(session, town, true)
	if item.is_empty():
		return "No town front is selected."
	return "%s: %s Why: %s Next: %s" % [
		String(item.get("label", _town_name(town))),
		_short_player_text(String(item.get("context", "")), 132),
		_short_player_text(String(item.get("why", "")), 112),
		_short_player_text(String(item.get("next_step", "")), 112),
	]

static func _defense_readiness_warning_items(session: SessionStateStoreScript.SessionData) -> Array:
	var items := []
	if session == null:
		return items
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var item := _defense_readiness_warning_item(session, town, false)
		if not item.is_empty():
			items.append(item)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("severity", 0)) > int(b.get("severity", 0))
	)
	return items

static func _defense_readiness_warning_item(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	include_steady: bool
) -> Dictionary:
	if session == null or town.is_empty():
		return {}
	var readiness := town_battle_readiness(town, session)
	var defense := _town_defense_summary(town)
	var logistics := town_logistics_state(session, town)
	var recovery := town_recovery_state(session, town)
	var capital_project := town_capital_project_state(town, session)
	var occupation := town_occupation_state(session, town)
	var front := _town_front_state(session, town)
	var threat_state := _town_command_risk_state(session, town)
	var objective_anchor: bool = _raid_target_is_objective_anchor(
		session,
		"town",
		String(town.get("placement_id", ""))
	)
	var pressure_parts := _defense_readiness_pressure_parts(threat_state, front, occupation)
	var logistics_alert := (
		int(logistics.get("disrupted_count", 0)) > 0
		or int(logistics.get("threatened_count", 0)) > 0
		or int(logistics.get("support_gap", 0)) > 0
	)
	var recovery_alert := bool(recovery.get("active", false))
	var capital_alert := bool(capital_project.get("vulnerable", false))
	var low_readiness := readiness <= 18 or defense == "thin watch"
	var strained_readiness := readiness <= 30
	var has_warning := (
		not pressure_parts.is_empty()
		or logistics_alert
		or recovery_alert
		or capital_alert
		or low_readiness
		or bool(occupation.get("active", false))
	)
	if not has_warning and not include_steady:
		return {}
	var severity := 0
	if int(threat_state.get("visible_pressuring", 0)) > 0 or int(threat_state.get("siege_progress", 0)) > 0:
		severity += 5
	elif int(threat_state.get("visible_marching", 0)) > 0:
		severity += 3
	if bool(threat_state.get("hidden_targeting", false)):
		severity += 2
	if bool(front.get("active", false)):
		severity += 2 if String(front.get("mode", "")) == "retake" else 1
	if bool(occupation.get("active", false)):
		severity += 2
	if low_readiness:
		severity += 2
	elif strained_readiness:
		severity += 1
	if logistics_alert:
		severity += 2
	if recovery_alert or capital_alert or objective_anchor:
		severity += 1
	var status := "ready"
	if low_readiness:
		status = "under-defended"
	elif has_warning:
		status = "pressured"
	elif strained_readiness:
		status = "guarded"
	var context_parts := []
	if not pressure_parts.is_empty():
		context_parts.append("Pressure %s" % "; ".join(pressure_parts))
	context_parts.append("Readiness %d" % readiness)
	if defense != "":
		context_parts.append(defense)
	if String(logistics.get("summary", "")) != "":
		context_parts.append("Routes %s" % String(logistics.get("summary", "")))
	if String(logistics.get("impact_summary", "")) != "" and (logistics_alert or include_steady):
		context_parts.append("Economy/frontier %s" % String(logistics.get("impact_summary", "")))
	if recovery_alert:
		context_parts.append(String(recovery.get("summary", "")))
	if capital_alert and String(capital_project.get("vulnerability_summary", "")) != "":
		context_parts.append(String(capital_project.get("vulnerability_summary", "")))
	if objective_anchor:
		context_parts.append("objective anchor")
	return {
		"label": "%s %s" % [_town_name(town), status],
		"context": " | ".join(context_parts),
		"why": _defense_readiness_warning_why(
			objective_anchor,
			not pressure_parts.is_empty(),
			logistics_alert,
			recovery_alert,
			capital_alert,
			low_readiness
		),
		"next_step": _defense_readiness_next_step(
			not pressure_parts.is_empty(),
			logistics_alert,
			recovery_alert,
			capital_alert,
			low_readiness,
			bool(front.get("active", false)),
			readiness
		),
		"severity": severity,
	}

static func _defense_readiness_pressure_parts(threat_state: Dictionary, front: Dictionary, occupation: Dictionary) -> Array:
	var parts := []
	if int(threat_state.get("visible_pressuring", 0)) > 0:
		var pressuring: Array = threat_state.get("pressuring_commanders", [])
		if int(threat_state.get("visible_pressuring", 0)) == 1 and pressuring is Array and not pressuring.is_empty():
			parts.append("%s at the approaches" % String(pressuring[0]))
		else:
			parts.append("%d raid hosts at the approaches" % int(threat_state.get("visible_pressuring", 0)))
	if int(threat_state.get("visible_marching", 0)) > 0:
		var marching: Array = threat_state.get("marching_commanders", [])
		var distance: int = max(1, int(threat_state.get("nearest_goal_distance", 9999)))
		if int(threat_state.get("visible_marching", 0)) == 1 and marching is Array and not marching.is_empty():
			parts.append("%s can reach in %d day%s" % [
				String(marching[0]),
				distance,
				"" if distance == 1 else "s",
			])
		else:
			parts.append("%d raid hosts marching" % int(threat_state.get("visible_marching", 0)))
	if bool(threat_state.get("hidden_targeting", false)):
		parts.append("hostile movement beyond the fog")
	if int(threat_state.get("siege_progress", 0)) > 0:
		parts.append("siege %d/%d" % [
			int(threat_state.get("siege_progress", 0)),
			max(1, int(threat_state.get("siege_capture_progress", 1))),
		])
	if bool(front.get("active", false)) and String(front.get("summary", "")) != "":
		parts.append(String(front.get("summary", "")))
	if bool(occupation.get("active", false)) and String(occupation.get("summary", "")) != "":
		parts.append(String(occupation.get("summary", "")))
	return parts

static func _defense_readiness_warning_why(
	objective_anchor: bool,
	has_pressure: bool,
	logistics_alert: bool,
	recovery_alert: bool,
	capital_alert: bool,
	low_readiness: bool
) -> String:
	if objective_anchor:
		return "This front anchors an objective while control, recruitment, income, and defense tempo stay exposed."
	if has_pressure:
		return "Raid pressure can become control loss, recruitment disruption, convoy loss, or siege risk."
	if logistics_alert:
		return "Route and economy pressure weakens readiness, recruitment, convoy support, and recovery."
	if recovery_alert:
		return "Recovery pressure keeps troops and routes brittle until relief or response orders land."
	if capital_alert:
		return "The capital chain needs linked support before its civic and defense gains are safe."
	if low_readiness:
		return "Low readiness leaves the garrison brittle if a raid reaches the walls."
	return "Control, income, recruitment, and route cover remain stable while the watch holds."

static func _defense_readiness_next_step(
	has_pressure: bool,
	logistics_alert: bool,
	recovery_alert: bool,
	capital_alert: bool,
	low_readiness: bool,
	front_active: bool,
	readiness: int
) -> String:
	if has_pressure and low_readiness:
		return "Recruit reserves or build readiness, then intercept the nearest raid if movement allows."
	if has_pressure:
		return "Intercept the raid before ending the day, or hold reserves if this town must anchor the front."
	if logistics_alert or recovery_alert:
		return "Send a town response order or intercept the route blocker before ending the day."
	if capital_alert:
		return "Restore linked route support or hold until the project is covered."
	if low_readiness or readiness <= 30:
		return "Build readiness or recruit reserves before the next exposed day."
	if front_active:
		return "Hold the watch and keep a response route open for the front."
	return "Hold the watch; build or recruit only if it improves the next defense turn."

static func _local_visible_threat_summary(session: SessionStateStoreScript.SessionData, fallback: String = "") -> String:
	var pos := hero_position(session)
	var visible_contacts := 0
	var local_contacts := 0
	var nearest_contact_name := ""
	var nearest_contact_reason := ""
	var nearest_contact_distance := 99999
	var visible_enemy_towns := 0
	var visible_denied_sites := 0
	var visible_contested_fronts := 0
	var visible_commander_names: Array = []
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if is_encounter_resolved(session, encounter):
			continue
		var x := int(encounter.get("x", -1))
		var y := int(encounter.get("y", -1))
		if not is_tile_visible(session, x, y):
			continue
		visible_contacts += 1
		var distance = abs(x - pos.x) + abs(y - pos.y)
		if distance <= 3:
			local_contacts += 1
		if distance < nearest_contact_distance:
			nearest_contact_distance = distance
			nearest_contact_name = encounter_display_name(encounter)
			nearest_contact_reason = String(encounter.get("target_public_reason", ""))
		var commander_name := encounter_commander_threat_label(encounter)
		if commander_name != "" and commander_name not in visible_commander_names:
			visible_commander_names.append(commander_name)
		if String(encounter.get("contested_by_faction_id", "")) != "":
			visible_contested_fronts += 1
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		var town_x := int(town.get("x", -1))
		var town_y := int(town.get("y", -1))
		if is_tile_visible(session, town_x, town_y):
			visible_enemy_towns += 1
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var collector := String(node.get("collected_by_faction_id", ""))
		if collector == "" or collector == "player":
			continue
		if is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			visible_denied_sites += 1
	for node in session.overworld.get("artifact_nodes", []):
		if not (node is Dictionary):
			continue
		var collector := String(node.get("collected_by_faction_id", ""))
		if collector == "" or collector == "player":
			continue
		if is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			visible_denied_sites += 1
	var parts := []
	if local_contacts > 0:
		var local_clause := "%d hostile contact%s operating within 3 tiles" % [local_contacts, "" if local_contacts == 1 else "s"]
		if nearest_contact_reason != "":
			local_clause += " (%s)" % nearest_contact_reason
		parts.append(local_clause)
	elif nearest_contact_name != "":
		var nearest_clause := "Nearest hostile contact %s at %d tiles" % [nearest_contact_name, nearest_contact_distance]
		if nearest_contact_reason != "":
			nearest_clause += " (%s)" % nearest_contact_reason
		parts.append(nearest_clause)
	elif visible_contacts > 0:
		parts.append("%d hostile contact%s visible on the frontier" % [visible_contacts, "" if visible_contacts == 1 else "s"])
	if visible_enemy_towns > 0:
		parts.append("%d enemy-held town%s currently confirmed by scouts" % [visible_enemy_towns, "" if visible_enemy_towns == 1 else "s"])
	if visible_denied_sites > 0:
		parts.append("%d frontier site%s already denied by hostile forces" % [visible_denied_sites, "" if visible_denied_sites == 1 else "s"])
	if visible_contested_fronts > 0:
		parts.append("%d neutral front%s under hostile contest" % [visible_contested_fronts, "" if visible_contested_fronts == 1 else "s"])
	if not visible_commander_names.is_empty():
		var shown_names = visible_commander_names.slice(0, min(2, visible_commander_names.size()))
		var commander_summary: String = "Commanders sighted %s" % ", ".join(shown_names)
		if visible_commander_names.size() > shown_names.size():
			commander_summary += " (+%d more)" % (visible_commander_names.size() - shown_names.size())
		parts.append(commander_summary)
	if parts.is_empty():
		return fallback
	return " | ".join(parts)

static func _occupied_town_watch_summary(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var clauses := []
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary) or String(town_value.get("owner", "neutral")) != "player":
			continue
		var occupation := _town_occupation_state(session, town_value)
		if not bool(occupation.get("active", false)):
			continue
		var clause := String(occupation.get("compact_summary", _town_name(town_value)))
		var front := _town_front_state(session, town_value)
		if bool(front.get("active", false)) and String(front.get("mode", "")) == "retake":
			clause += " under retake pressure"
		clauses.append(clause)
	if clauses.is_empty():
		return ""
	var shown := clauses.slice(0, min(2, clauses.size()))
	var summary := "; ".join(shown)
	if clauses.size() > shown.size():
		summary += "; %d more holding%s" % [clauses.size() - shown.size(), "" if clauses.size() - shown.size() == 1 else "s"]
	return summary

static func describe_enemy_threats(session: SessionStateStoreScript.SessionData) -> String:
	return describe_frontier_threats(session)

static func describe_spellbook(session: SessionStateStoreScript.SessionData, context_filter: String = "") -> String:
	if context_filter == SpellRulesScript.CONTEXT_OVERWORLD:
		return SpellRulesScript.describe_overworld_spellbook(
			session.overworld.get("hero", {}),
			session.overworld.get("movement", {})
		)
	return SpellRulesScript.describe_spellbook(session.overworld.get("hero", {}), context_filter)

static func describe_spellbook_rail(session: SessionStateStoreScript.SessionData, context_filter: String = "") -> String:
	if context_filter == SpellRulesScript.CONTEXT_OVERWORLD:
		return SpellRulesScript.describe_overworld_spell_rail(
			session.overworld.get("hero", {}),
			session.overworld.get("movement", {})
		)
	return SpellRulesScript.describe_spellbook(session.overworld.get("hero", {}), context_filter)

static func describe_specialties(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	return HeroProgressionRulesScript.describe_specialties(session.overworld.get("hero", {}))

static func describe_artifacts(session: SessionStateStoreScript.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	return ArtifactRulesScript.describe_management(hero)

static func describe_command_briefing(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	if not _should_surface_command_briefing(session):
		return ""
	return "\n".join(_command_briefing_lines(session))

static func consume_command_briefing(session: SessionStateStoreScript.SessionData) -> String:
	var briefing_text := describe_command_briefing(session)
	if briefing_text == "":
		return ""
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	if not (briefing_state is Dictionary):
		briefing_state = {}
	briefing_state["shown"] = true
	briefing_state["shown_day"] = session.day
	session.overworld[COMMAND_BRIEFING_KEY] = briefing_state
	return briefing_text

static func describe_command_risk(session: SessionStateStoreScript.SessionData) -> String:
	return String(describe_command_risk_surfaces(session).get("risk", ""))

static func describe_commitment_board(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var lines := [
		"Command Commitment",
		"- Immediate order: %s" % _command_commitment_action_line(session),
		"- Route pressure: %s" % _command_commitment_route_line(session),
		"- Coverage: %s" % _command_commitment_coverage_line(session),
		"- If you hold: %s" % _command_commitment_hold_line(session),
	]
	return "\n".join(lines)

static func describe_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> String:
	return String(describe_command_risk_surfaces(session).get("forecast", ""))

static func describe_end_turn_forecast(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var next_day := session.day + 1
	var lines := [
		"Next day: Day %d | %s | %s" % [
			next_day,
			_end_turn_income_forecast_line(session),
			_end_turn_muster_forecast_line(session, next_day),
		],
		"- Movement: %s" % _end_turn_movement_forecast_line(session),
	]
	var risk_line := _end_turn_risk_forecast_line(session)
	if risk_line != "":
		lines.append("- Pressure: %s" % risk_line)
	var management_line := describe_management_watch(session)
	if management_line != "":
		lines.append("- Town lines: %s" % management_line)
	return "\n".join(lines)

static func describe_end_turn_forecast_compact(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var next_day := session.day + 1
	var parts := [
		"Day %d" % next_day,
		_end_turn_income_forecast_line(session),
		_end_turn_movement_forecast_line(session),
	]
	var risk_line := _end_turn_risk_forecast_line(session)
	if risk_line != "":
		parts.append(risk_line)
	return " | ".join(parts)

static func describe_command_risk_surfaces(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var forecast := _command_risk_forecast(session)
	if not bool(forecast.get("has_risk", false)):
		return {
			"risk": "Command Risk\nSteady watch | No concrete next-day break is signaled from the current frontier watch.",
			"forecast": "",
			"forecast_data": forecast,
		}
	return {
		"risk": "Command Risk\n%s" % String(forecast.get("summary", "")),
		"forecast": "\n".join(forecast.get("lines", [])),
		"forecast_data": forecast,
	}

static func consume_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> String:
	var forecast_text := describe_command_risk_forecast(session)
	if forecast_text == "" or not _should_surface_command_risk_forecast(session):
		return ""
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	if not (forecast_state is Dictionary):
		forecast_state = {}
	forecast_state["shown"] = true
	forecast_state["shown_day"] = session.day
	session.overworld[COMMAND_RISK_FORECAST_KEY] = forecast_state
	return forecast_text

static func describe_dispatch(session: SessionStateStoreScript.SessionData, last_message: String = "") -> String:
	normalize_overworld_state(session)
	var lead_line := "Latest order: %s" % last_message if last_message != "" else "The field table is waiting on fresh orders."
	var lines := [
		"Field Dispatch",
		"- %s" % lead_line,
		"- Active tile: %s" % _dispatch_context_brief(session),
		"- %s" % _local_visible_threat_summary(session, "No visible hostile pressure is crowding the active hero."),
	]
	var management_watch := describe_management_watch(session)
	if management_watch != "":
		lines.append("- Management watch: %s" % management_watch)
	var defense_watch := describe_defense_readiness_warnings(session, 1)
	if defense_watch != "No exposed town or route-defense warning is visible.":
		lines.append("- Defense readiness: %s" % defense_watch)
	var recent_events: String = _describe_recent_events(session, 2)
	if recent_events != "":
		lines.append("- Scenario pulse: %s" % recent_events)
	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		lines.append("- Outcome pending: %s" % session.scenario_summary)
	return "\n".join(lines)

static func describe_event_feed_surface(
	session: SessionStateStoreScript.SessionData,
	last_message: String = "",
	turn_resolution_summary: String = "",
	enemy_activity_summary: String = "",
	enemy_activity_events_value: Variant = [],
	action_recap_value: Variant = {}
) -> Dictionary:
	normalize_overworld_state(session)
	var recent_events := _describe_recent_events(session, 2)
	var action_recap := _normalize_post_action_recap(action_recap_value)
	var use_action_recap := turn_resolution_summary.strip_edges() == "" and enemy_activity_summary.strip_edges() == "" and not action_recap.is_empty()
	var happened := String(action_recap.get("happened", "")) if use_action_recap else _event_feed_happened_line(last_message, turn_resolution_summary, enemy_activity_summary, recent_events)
	var affected := String(action_recap.get("affected", "")) if use_action_recap else _event_feed_affected_line(session, enemy_activity_summary, enemy_activity_events_value)
	var why := String(action_recap.get("why_it_matters", "")) if use_action_recap else _event_feed_why_line(last_message, turn_resolution_summary, enemy_activity_summary, recent_events)
	var next_step := String(action_recap.get("next_step", "")) if use_action_recap else _event_feed_next_step_line(session)
	var watch := _event_feed_watch_line(session)
	var visible := _event_feed_visible_line(happened, turn_resolution_summary, enemy_activity_summary)
	var tooltip_lines := ["Field Feed"]
	tooltip_lines.append("- Happened: %s" % happened)
	if turn_resolution_summary.strip_edges() != "":
		tooltip_lines.append("- Daybreak result: %s" % turn_resolution_summary.strip_edges())
	if enemy_activity_summary.strip_edges() != "":
		tooltip_lines.append("- Recent enemy activity: %s" % enemy_activity_summary.strip_edges())
	if recent_events != "":
		tooltip_lines.append("- Scenario pulse: %s" % _short_player_text(recent_events, 180))
	if affected != "":
		tooltip_lines.append("- Affected: %s" % affected)
	if why != "":
		tooltip_lines.append("- Why it matters: %s" % why)
	if next_step != "":
		tooltip_lines.append("- Next: %s" % next_step)
	if watch != "":
		tooltip_lines.append("- Watch: %s" % watch)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"happened": happened,
		"affected": affected,
		"why_it_matters": why,
		"next_step": next_step,
		"watch": watch,
		"recent_events": recent_events,
		"enemy_activity_summary": enemy_activity_summary,
		"turn_resolution_summary": turn_resolution_summary,
		"post_action_recap": action_recap,
	}

static func describe_enemy_activity(events_value: Variant, limit: int = 4) -> String:
	var lines := []
	var seen := {}
	for event_value in _compact_enemy_activity_events(events_value, max(1, limit * 2)):
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var line := _enemy_activity_line(event)
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		lines.append(line)
		if lines.size() >= max(1, limit):
			break
	return " | ".join(lines)

static func _compact_enemy_activity_events(events_value: Variant, limit: int = 6) -> Array:
	return _enemy_adventure_rules().ai_public_event_log(events_value, limit)

static func _enemy_activity_event_is_player_facing(event: Dictionary) -> bool:
	var event_type := String(event.get("event_type", ""))
	if event_type not in [
		"ai_target_assigned",
		"ai_pressure_summary",
		"ai_site_seized",
		"ai_site_contested",
		"ai_town_built",
		"ai_town_recruited",
		"ai_garrison_reinforced",
		"ai_raid_reinforced",
		"ai_commander_rebuilt",
		"ai_commander_role_observed",
		"ai_raid_moved",
		"ai_raid_arrived",
	]:
		return false
	var text := _enemy_activity_public_text(String(event.get("summary", "")))
	if text == "":
		return String(event.get("target_label", "")) != ""
	return true

static func _enemy_activity_line(event: Dictionary) -> String:
	var summary := _enemy_activity_public_text(String(event.get("summary", "")))
	if summary != "":
		return summary
	var actor := String(event.get("actor_label", event.get("faction_label", "Enemy")))
	var target := String(event.get("target_label", event.get("target_id", "the frontier")))
	var reason := _enemy_activity_public_text(String(event.get("public_reason", "")))
	var suffix := " (%s)" % reason if reason != "" else ""
	match String(event.get("event_type", "")):
		"ai_target_assigned":
			return "%s targets %s%s." % [actor, target, suffix]
		"ai_pressure_summary":
			return "%s pressure centers on %s%s." % [String(event.get("faction_label", actor)), target, suffix]
		"ai_site_seized":
			return "%s seizes %s%s." % [actor, target, suffix]
		"ai_site_contested":
			return "%s contests %s%s." % [actor, target, suffix]
		"ai_town_built":
			return "%s builds %s%s." % [actor, target, suffix]
		"ai_town_recruited":
			return "%s recruits %s%s." % [actor, target, suffix]
		"ai_garrison_reinforced":
			return "%s reinforces %s%s." % [actor, target, suffix]
		"ai_raid_reinforced":
			return "%s feeds %s%s." % [actor, target, suffix]
		"ai_commander_rebuilt":
			return "%s rebuilds %s%s." % [actor, target, suffix]
		_:
			return ""

static func _enemy_activity_public_text(text: String) -> String:
	var output := text.strip_edges().replace("\n", " ")
	while output.find("  ") >= 0:
		output = output.replace("  ", " ")
	for token in [
		"base_value",
		"persistent_income_value",
		"recruit_value",
		"scarcity_value",
		"denial_value",
		"route_pressure_value",
		"town_enablement_value",
		"resource_affinity_value",
		"weighted_claim_value",
		"weighted_income_value",
		"objective_value",
		"faction_bias",
		"travel_cost",
		"guard_cost",
		"assignment_penalty",
		"final_priority",
		"final_score",
		"income_value",
		"growth_value",
		"pressure_value",
		"category_bonus",
		"raid_score",
		"debug_reason",
	]:
		if output.find(token) >= 0:
			return ""
	return output

static func _event_feed_visible_line(happened: String, turn_resolution_summary: String, enemy_activity_summary: String) -> String:
	if turn_resolution_summary.strip_edges() != "":
		return "Turn: %s" % _short_player_text(turn_resolution_summary, 72)
	if enemy_activity_summary.strip_edges() != "":
		return "Enemy: %s" % _short_player_text(enemy_activity_summary, 72)
	var action_text := happened
	if action_text.begins_with("Order resolved: "):
		action_text = action_text.trim_prefix("Order resolved: ")
	elif action_text.begins_with("Scenario pulse: "):
		action_text = action_text.trim_prefix("Scenario pulse: ")
	return "Event: %s" % _short_player_text(action_text, 72)

static func _event_feed_happened_line(
	last_message: String,
	turn_resolution_summary: String,
	enemy_activity_summary: String,
	recent_events: String
) -> String:
	var turn_text := _enemy_activity_public_text(turn_resolution_summary)
	if turn_text != "":
		return "Daybreak resolved: %s" % _short_player_text(turn_text, 160)
	var message_text := _enemy_activity_public_text(last_message)
	if message_text != "":
		return "Order resolved: %s" % _short_player_text(message_text, 160)
	var enemy_text := _enemy_activity_public_text(enemy_activity_summary)
	if enemy_text != "":
		return "Enemy movement reported: %s" % _short_player_text(enemy_text, 160)
	if recent_events != "":
		return "Scenario pulse: %s" % _short_player_text(recent_events, 160)
	return "No new report; the frontier watch is current."

static func _event_feed_affected_line(
	session: SessionStateStoreScript.SessionData,
	enemy_activity_summary: String,
	enemy_activity_events_value: Variant
) -> String:
	var affected := []
	if enemy_activity_summary.strip_edges() != "" and enemy_activity_events_value is Array:
		for event_value in enemy_activity_events_value:
			if not (event_value is Dictionary):
				continue
			var event: Dictionary = event_value
			var target_label := String(event.get("target_label", "")).strip_edges()
			if target_label == "":
				continue
			var target_kind := String(event.get("target_kind", "")).strip_edges()
			var faction_label := String(event.get("faction_label", "")).strip_edges()
			var label := target_label
			if target_kind != "":
				label += " %s" % _humanize_id(target_kind).to_lower()
			if faction_label != "":
				label = "%s: %s" % [faction_label, label]
			if label not in affected:
				affected.append(label)
			if affected.size() >= 2:
				break
	var convoy_line := _event_feed_convoy_line(session)
	if convoy_line != "":
		affected.append(convoy_line)
	if affected.is_empty():
		affected.append(_dispatch_context_brief(session))
	return " | ".join(affected.slice(0, min(3, affected.size())))

static func _event_feed_why_line(
	last_message: String,
	turn_resolution_summary: String,
	enemy_activity_summary: String,
	recent_events: String
) -> String:
	var combined := "%s %s %s %s" % [last_message, turn_resolution_summary, enemy_activity_summary, recent_events]
	var lower := combined.to_lower()
	if enemy_activity_summary.strip_edges() != "":
		return "Enemy moves can close routes, contest sites, or add town pressure before your next turn."
	if lower.find("convoy") >= 0 or lower.find("escort") >= 0 or lower.find("route") >= 0:
		return "Route orders move reinforcements and may need protection from active raids."
	if recent_events != "":
		return "Scenario pulses can open rewards, spawn counterforces, or advance objective stakes."
	if lower.find("claim") >= 0 or lower.find("control") >= 0 or lower.find("captur") >= 0:
		return "Control changes affect income, recruitment, routes, and objective progress."
	if lower.find("recruit") >= 0 or lower.find("muster") >= 0:
		return "Fresh troops change the next battle or town-defense decision."
	return "Use the next order to turn the report into progress toward the active objective."

static func _event_feed_next_step_line(session: SessionStateStoreScript.SessionData) -> String:
	var surface := _objective_stakes_surface(session)
	var next_objective := String(surface.get("next_objective", "")).strip_edges()
	if next_objective != "":
		return "Push toward %s." % _short_player_text(next_objective, 92)
	var watch_objective := String(surface.get("watch_objective", "")).strip_edges()
	if watch_objective != "":
		return "Keep watch on %s." % _short_player_text(watch_objective, 92)
	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		return "Resolve the pending scenario outcome."
	return "Scout, consolidate, or end the turn when orders are spent."

static func _event_feed_watch_line(session: SessionStateStoreScript.SessionData) -> String:
	var parts := []
	var route_pressure := describe_route_interception_surface(session)
	if bool(route_pressure.get("active", false)):
		parts.append(String(route_pressure.get("cue_text", "")))
	var local_pressure := _local_visible_threat_summary(session, "")
	if local_pressure != "":
		parts.append(local_pressure)
	var management_watch := describe_management_watch(session)
	if management_watch != "" and management_watch != "Town lines are stable.":
		parts.append(management_watch)
	var defense_watch := describe_defense_readiness_warnings(session, 1)
	if defense_watch != "No exposed town or route-defense warning is visible.":
		parts.append("Defense readiness: %s" % defense_watch)
	if parts.is_empty():
		return "No urgent raid, convoy, or town-management warning is visible."
	return " | ".join(parts.slice(0, min(3, parts.size())))

static func describe_route_interception_surface(
	session: SessionStateStoreScript.SessionData,
	destination_x: int = -1,
	destination_y: int = -1,
	route_steps: int = 0
) -> Dictionary:
	normalize_overworld_state(session)
	if session == null:
		return _route_interception_empty_surface()
	if destination_x >= 0 and destination_y >= 0:
		var selected := _selected_route_interception_surface(
			session,
			Vector2i(destination_x, destination_y),
			route_steps
		)
		if bool(selected.get("active", false)):
			return selected
	var convoy := _best_convoy_interception_surface(session)
	if bool(convoy.get("active", false)):
		return convoy
	var raid := _best_raid_interception_surface(session)
	if bool(raid.get("active", false)):
		return raid
	return _route_interception_empty_surface()

static func _route_interception_empty_surface() -> Dictionary:
	return {
		"active": false,
		"kind": "",
		"cue_text": "",
		"visible_text": "",
		"tooltip_text": "",
		"affected": "",
		"why_it_matters": "",
		"next_step": "",
		"importance": "normal",
	}

static func _route_interception_payload(
	kind: String,
	affected: String,
	why_it_matters: String,
	next_step: String,
	cue_text: String,
	importance: String = "normal"
) -> Dictionary:
	var cleaned_affected := _short_player_text(_enemy_activity_public_text(affected), 150)
	var cleaned_why := _short_player_text(_enemy_activity_public_text(why_it_matters), 160)
	var cleaned_next := _short_player_text(_enemy_activity_public_text(next_step), 140)
	var cleaned_cue := _short_player_text(_enemy_activity_public_text(cue_text), 96)
	if cleaned_affected == "" or cleaned_why == "" or cleaned_next == "" or cleaned_cue == "":
		return _route_interception_empty_surface()
	return {
		"active": true,
		"kind": kind,
		"cue_text": cleaned_cue,
		"visible_text": cleaned_cue,
		"tooltip_text": "Interception Watch\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [
			cleaned_affected,
			cleaned_why,
			cleaned_next,
		],
		"affected": cleaned_affected,
		"why_it_matters": cleaned_why,
		"next_step": cleaned_next,
		"importance": importance,
	}

static func _selected_route_interception_surface(
	session: SessionStateStoreScript.SessionData,
	tile: Vector2i,
	route_steps: int
) -> Dictionary:
	var encounter := _encounter_at_tile(session, tile.x, tile.y)
	if not encounter.is_empty():
		return _raid_interception_surface(session, encounter, route_steps, true)
	var node := _resource_node_at_tile(session, tile.x, tile.y)
	if node.is_empty():
		return _route_interception_empty_surface()
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if bool(delivery_state.get("active", false)):
		return _convoy_interception_surface(session, node, site, true)
	var response_state := _resource_site_response_state(session, node, site)
	if bool(response_state.get("active", false)):
		var impact := _resource_site_response_effect_summary(response_state)
		return _route_interception_payload(
			"route_response",
			"%s response holds %s for %d day%s%s." % [
				String(site.get("name", "Route site")),
				String(response_state.get("action_label", "route security")).to_lower(),
				int(response_state.get("remaining_days", 0)),
				"" if int(response_state.get("remaining_days", 0)) == 1 else "s",
				"" if impact == "" else " (%s)" % impact,
			],
			"Active response orders protect economy links, convoy movement, and nearby control pressure before raids resolve.",
			"Use the protected lane to intercept a hostile host or keep moving toward the next objective.",
			"%s response active" % String(site.get("name", "Route")),
			"normal"
		)
	if String(node.get("collected_by_faction_id", "")) == "player" and int(response_state.get("watch_days", 0)) > 0:
		return _route_interception_payload(
			"route_response_ready",
			"%s can receive %s." % [
				String(site.get("name", "Route site")),
				String(response_state.get("action_label", "route security")).to_lower(),
			],
			"Response orders spend movement and stores to steady route pressure, protect convoys, and support linked towns.",
			"Stand on the site or use the town response order if this lane matters more than the current march.",
			"%s response ready" % String(site.get("name", "Route")),
			"normal"
		)
	return _route_interception_empty_surface()

static func _best_convoy_interception_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var best := _route_interception_empty_surface()
	var best_score := -99999
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		var interception: Dictionary = _resource_site_delivery_interception(session, node, site)
		var score := int(delivery_state.get("manifest_value", 0))
		score += 10000 if bool(interception.get("blocks_delivery", false)) else 0
		score += 4000 if bool(interception.get("active", false)) else 0
		score += max(0, 20 - int(delivery_state.get("days_remaining", 0))) * 10
		if score <= best_score:
			continue
		best_score = score
		best = _convoy_interception_surface(session, node, site, false)
	return best

static func _convoy_interception_surface(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary,
	selected: bool
) -> Dictionary:
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)):
		return _route_interception_empty_surface()
	var interception: Dictionary = _resource_site_delivery_interception(session, node, site)
	var site_name := String(site.get("name", "Frontier route"))
	var target_label := String(delivery_state.get("target_label", "the front"))
	var recruit_summary := String(delivery_state.get("recruit_summary", "the convoy"))
	var route_label := "%s convoy to %s" % [site_name, target_label]
	var affected := "%s carries %s; %s." % [
		route_label,
		recruit_summary,
		_resource_site_delivery_line(session, node, site),
	]
	var why := _convoy_interception_why(String(delivery_state.get("target_kind", "")), target_label)
	var next_step := "Keep the convoy route covered until arrival."
	var cue := "Convoy: %s to %s" % [site_name, target_label]
	var importance := "normal"
	if bool(interception.get("blocks_delivery", false)):
		var blocker := String(interception.get("encounter_name", "Raid host"))
		next_step = "Break %s before ending the day or the convoy stays intercepted." % blocker
		cue = "Convoy blocked: %s" % blocker
		importance = "high"
	elif bool(interception.get("active", false)):
		var hunter := String(interception.get("encounter_name", "Raid host"))
		next_step = "Intercept %s or reinforce %s before the convoy lane closes." % [
			hunter,
			target_label,
		]
		cue = "Convoy threatened: %s %d tile%s out" % [
			hunter,
			int(interception.get("goal_distance", 0)),
			"" if int(interception.get("goal_distance", 0)) == 1 else "s",
		]
		importance = "high" if int(interception.get("goal_distance", 9999)) <= 1 else "normal"
	elif selected:
		next_step = "Hold this route response or move to intercept raids before they reach %s." % target_label
		cue = "Convoy active: %s" % target_label
	return _route_interception_payload("convoy", affected, why, next_step, cue, importance)

static func _convoy_interception_why(target_kind: String, target_label: String) -> String:
	match target_kind:
		"town":
			return "Those reserves change %s defense, recovery, recruitment tempo, and control stability." % target_label
		"hero":
			return "Those reserves change the field army's next battle odds and the route choices it can survive."
		"raid":
			return "Those reserves help answer the raid directly before it turns pressure into losses."
		_:
			return "Convoys turn controlled sites into practical economy, army, and objective tempo."

static func _best_raid_interception_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var best := _route_interception_empty_surface()
	var best_score := -99999
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("spawned_by_faction_id", "")) == "" or is_encounter_resolved(session, encounter):
			continue
		if not _raid_is_public(session, encounter):
			continue
		var goal_distance := int(encounter.get("goal_distance", 9999))
		var score := 2000 if bool(encounter.get("arrived", false)) or goal_distance <= 0 else 0
		score += max(0, 20 - goal_distance) * 20
		if _raid_target_is_objective_anchor(
			session,
			String(encounter.get("target_kind", "")),
			String(encounter.get("target_placement_id", ""))
		):
			score += 1000
		if score <= best_score:
			continue
		best_score = score
		best = _raid_interception_surface(session, encounter, 0, false)
	return best

static func _raid_interception_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	route_steps: int,
	selected: bool
) -> Dictionary:
	if encounter.is_empty() or is_encounter_resolved(session, encounter):
		return _route_interception_empty_surface()
	var encounter_name := encounter_display_name(encounter)
	var target_kind := String(encounter.get("target_kind", ""))
	var target_label := String(encounter.get("target_label", "the frontier"))
	var goal_distance := int(encounter.get("goal_distance", 9999))
	var objective_anchor: bool = _raid_target_is_objective_anchor(
		session,
		target_kind,
		String(encounter.get("target_placement_id", ""))
	)
	var affected := describe_encounter_pressure(session, encounter)
	var why := _raid_interception_why(target_kind, target_label, objective_anchor)
	var next_step := "Select the hostile contact or a route-response site before ending the day."
	var cue := "Raid: %s toward %s" % [encounter_name, target_label]
	var importance := "normal"
	if selected:
		next_step = "Enter battle now if this route pressure matters more than another site order."
		if route_steps > 0:
			next_step = "Advance %d step%s toward %s; enter battle when adjacent." % [
				route_steps,
				"" if route_steps == 1 else "s",
				encounter_name,
			]
		cue = "Intercept: %s" % encounter_name
	elif bool(encounter.get("arrived", false)) or goal_distance <= 0:
		next_step = "Break %s now or it can turn pressure into control, convoy, or objective losses." % encounter_name
		cue = "Raid arrived: %s" % encounter_name
		importance = "high"
	elif goal_distance <= 2:
		next_step = "Move to intercept %s before it reaches %s." % [encounter_name, target_label]
		cue = "Raid close: %s %d tile%s out" % [
			encounter_name,
			goal_distance,
			"" if goal_distance == 1 else "s",
		]
		importance = "high"
	return _route_interception_payload("raid", affected, why, next_step, cue, importance)

static func _raid_interception_why(target_kind: String, target_label: String, objective_anchor: bool) -> String:
	var objective_clause := " It is tied to objective pressure." if objective_anchor else ""
	match target_kind:
		"town":
			return "Town raids threaten control, recruitment, income, and defense readiness at %s.%s" % [target_label, objective_clause]
		"resource":
			return "Site raids threaten linked economy, route response, convoy support, and town logistics at %s.%s" % [target_label, objective_clause]
		"hero":
			return "Hero hunts can force a field battle and pin the army away from route and objective work.%s" % objective_clause
		"artifact":
			return "Artifact raids can deny a field upgrade before the hero reaches it.%s" % objective_clause
		"encounter":
			return "Raid pressure on this guard can lock a route and delay objective progress.%s" % objective_clause
		_:
			return "Raid pressure can become economy, control, convoy, or objective loss if ignored.%s" % objective_clause

static func _resource_node_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if int(node.get("x", -1)) == x and int(node.get("y", -1)) == y:
			return node
	return {}

static func _encounter_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if int(encounter.get("x", -1)) == x and int(encounter.get("y", -1)) == y:
			return encounter
	return {}

static func _event_feed_convoy_line(session: SessionStateStoreScript.SessionData) -> String:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_line := _resource_site_delivery_line(session, node, site)
		if delivery_line != "":
			return "Convoy: %s" % _short_player_text(delivery_line, 120)
	return ""

static func _dispatch_context_brief(session: SessionStateStoreScript.SessionData) -> String:
	var context := get_active_context(session)
	var pos := hero_position(session)
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			return "%s on %s" % [_town_name(town), terrain]
		"resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return "%s on %s" % [String(site.get("name", "Resource site")), terrain]
		"artifact":
			var artifact_node = context.get("node", {})
			return "%s on %s" % [
				ArtifactRulesScript.describe_artifact_short(String(artifact_node.get("artifact_id", ""))),
				terrain,
			]
		"encounter":
			var encounter_placement = context.get("encounter", {})
			return "%s on %s" % [encounter_display_name(encounter_placement), terrain]
		_:
			return "Open ground at %d,%d on %s" % [pos.x, pos.y, terrain]

static func town_weekly_growth(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	return _town_weekly_growth(town, session)

static func town_income(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	return _calculate_town_income(town, session)

static func town_reinforcement_quality(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return _town_reinforcement_quality(town, session)

static func town_battle_readiness(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return _town_battle_readiness(town, session)

static func town_pressure_output(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return _town_pressure_output(town, session)

static func town_strategic_role(town: Dictionary) -> String:
	return _town_strategic_role(town)

static func town_strategic_summary(town: Dictionary) -> String:
	return _town_strategic_summary(town)

static func describe_faction_identity_surface(faction_id: String) -> String:
	return _faction_identity_surface(faction_id)

static func describe_town_identity_surface(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	return _town_identity_surface(town, session)

static func town_capital_project_state(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	return _town_capital_project_state(town, session)

static func town_logistics_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return _town_logistics_state(session, town)

static func town_recovery_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return _town_recovery_state(session, town)

static func town_public_threat_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return _town_command_risk_state(session, town)

static func town_battlefront_profile(town: Dictionary) -> Dictionary:
	return _town_battlefront_profile(town)

static func town_front_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return _town_front_state(session, town)

static func town_occupation_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return _town_occupation_state(session, town)

static func town_market_state(town: Dictionary) -> Dictionary:
	return _town_market_state(town)

static func describe_town_market(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return "\n".join(_town_market_panel_lines(session, town))

static func get_town_market_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return _town_market_actions(session, town)

static func perform_town_market_action(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	action_id: String
) -> Dictionary:
	return _execute_town_market_action(session, town, action_id)

static func describe_town_response_panel(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return "\n".join(_town_response_panel_lines(session, town))

static func get_town_response_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return _town_response_actions(session, town)

static func perform_town_response_action(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	action_id: String
) -> Dictionary:
	return _execute_town_response_action(session, town, action_id)

static func controlled_resource_site_income(session: SessionStateStoreScript.SessionData, controller_id: String) -> Dictionary:
	var income := {"gold": 0, "wood": 0, "ore": 0}
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		income = _add_resource_sets(income, site.get("control_income", {}))
	return income

static func _player_daily_income_projection(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var town_income := {"gold": 0, "wood": 0, "ore": 0}
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		town_income = _add_resource_sets(
			town_income,
			DifficultyRulesScript.scale_income_resources(session, _calculate_town_income(town, session))
		)
	var hero_state = session.overworld.get("hero", {})
	var artifact_income = DifficultyRulesScript.scale_income_resources(
		session,
		ArtifactRulesScript.aggregate_bonuses(hero_state).get("daily_income", {})
	)
	var specialty_income = HeroProgressionRulesScript.daily_income_bonus(hero_state)
	var site_income = DifficultyRulesScript.scale_income_resources(session, controlled_resource_site_income(session, "player"))
	return _add_resource_sets(
		_add_resource_sets(_add_resource_sets(town_income, artifact_income), specialty_income),
		site_income
	)

static func _end_turn_income_forecast_line(session: SessionStateStoreScript.SessionData) -> String:
	var income_summary := _describe_resource_delta(_player_daily_income_projection(session))
	if income_summary == "":
		return "income steady"
	return "income %s" % income_summary

static func _end_turn_muster_forecast_line(session: SessionStateStoreScript.SessionData, next_day: int) -> String:
	if is_weekly_growth_day(next_day):
		var previews := []
		for town in session.overworld.get("towns", []):
			if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
				continue
			var growth_summary := _describe_recruit_delta(_town_weekly_growth(town, session))
			if growth_summary != "":
				previews.append("%s %s" % [_town_name(town), growth_summary])
			if previews.size() >= 2:
				break
		if previews.is_empty():
			return "weekly muster resolves"
		return "weekly muster %s" % "; ".join(previews)
	var days_until: int = max(1, next_weekly_growth_day(session.day) - next_day)
	return "muster Day %d in %d day%s" % [
		next_weekly_growth_day(session.day),
		days_until,
		"" if days_until == 1 else "s",
	]

static func _end_turn_movement_forecast_line(session: SessionStateStoreScript.SessionData) -> String:
	var max_movement := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	return "move resets %d/%d" % [max_movement, max_movement]

static func _end_turn_risk_forecast_line(session: SessionStateStoreScript.SessionData) -> String:
	var risk_surface := describe_command_risk_surfaces(session)
	var risk_text := String(risk_surface.get("risk", "")).strip_edges()
	if risk_text == "" or risk_text.find("Steady watch") >= 0:
		var local_pressure := _local_visible_threat_summary(session, "")
		return local_pressure if local_pressure != "" else "watch steady"
	var lines := risk_text.split("\n", false)
	return _short_player_text(String(lines[lines.size() - 1]), 96)

static func _end_turn_muster_summary(weekly_growth_messages: Array, site_muster_messages: Array) -> String:
	var parts := []
	for message in weekly_growth_messages:
		var text := String(message).strip_edges()
		if text != "":
			parts.append(text)
	for message in site_muster_messages:
		var text := String(message).strip_edges()
		if text != "":
			parts.append(text)
	if parts.is_empty():
		return ""
	return "; ".join(parts)

static func _end_turn_town_economy_summary(
	occupation_messages: Array,
	recovery_messages: Array,
	delivery_messages: Array
) -> String:
	var parts := []
	for source in [occupation_messages, recovery_messages, delivery_messages]:
		for message in source:
			var text := String(message).strip_edges()
			if text != "":
				parts.append(text)
			if parts.size() >= 3:
				return "; ".join(parts)
	return "; ".join(parts)

static func _end_turn_resolution_summary(session: SessionStateStoreScript.SessionData, result: Dictionary) -> String:
	var parts := ["Day %d" % session.day]
	var income_summary := String(result.get("resource_income_summary", "")).strip_edges()
	if income_summary != "":
		parts.append("income %s" % income_summary)
	var movement_summary := String(result.get("movement_reset_summary", "")).strip_edges()
	if movement_summary != "":
		parts.append(movement_summary)
	var muster_summary := String(result.get("weekly_muster_summary", "")).strip_edges()
	if muster_summary != "":
		parts.append("muster %s" % _short_player_text(muster_summary, 72))
	var town_summary := String(result.get("town_economy_summary", "")).strip_edges()
	if town_summary != "":
		parts.append("towns %s" % _short_player_text(town_summary, 72))
	var enemy_summary := String(result.get("enemy_activity_summary", "")).strip_edges()
	if enemy_summary != "":
		parts.append("enemy %s" % _short_player_text(enemy_summary, 96))
	return " | ".join(parts)

static func can_afford_cost_with_town_market(town: Dictionary, pool: Dictionary, cost: Variant) -> bool:
	return bool(_town_market_cost_coverage(town, pool, cost).get("affordable", false))

static func apply_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant) -> Array:
	return _apply_market_cost_coverage(town, pool, cost)

static func town_cost_readiness(town: Dictionary, pool: Dictionary, cost: Variant) -> Dictionary:
	var readiness := _town_market_cost_coverage(town, pool, cost)
	var market_actions := []
	if bool(readiness.get("market_affordable", false)):
		var simulated_pool: Dictionary = readiness.get("pool", {}).duplicate(true)
		market_actions = _apply_market_cost_coverage(town, simulated_pool, readiness.get("cost", {}))
	readiness["market_actions"] = market_actions
	return readiness

static func controlled_resource_site_pressure_bonus(session: SessionStateStoreScript.SessionData, controller_id: String) -> int:
	var total := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		total += max(0, int(site.get("pressure_bonus", 0)))
		var weekly_recruits = _resource_site_weekly_recruits(site)
		if controller_id != "player" and weekly_recruits is Dictionary and not weekly_recruits.is_empty():
			total += 1
	return total

static func player_resource_site_pressure_guard(session: SessionStateStoreScript.SessionData) -> int:
	var total := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, "player"):
			continue
		total += max(0, int(site.get("pressure_guard", 0)))
		var response_state := _resource_site_response_state(session, node, site)
		if bool(response_state.get("active", false)):
			total += int(response_state.get("pressure_guard_bonus", 0))
	return total

static func apply_controlled_resource_site_musters(session: SessionStateStoreScript.SessionData, controller_id: String) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var weekly_recruits = _resource_site_weekly_recruits(site)
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		if not (weekly_recruits is Dictionary) or weekly_recruits.is_empty():
			continue
		var town_result := _nearest_town_for_controller(session, controller_id, int(node.get("x", 0)), int(node.get("y", 0)))
		if int(town_result.get("index", -1)) < 0:
			continue
		var town = town_result.get("town", {})
		town["available_recruits"] = _add_recruit_growth(town.get("available_recruits", {}), weekly_recruits)
		towns[int(town_result.get("index", -1))] = town
		messages.append(
			"%s feeds %s (%s)" % [
				String(site.get("name", "Frontier site")),
				_town_name(town),
				_describe_recruit_delta(weekly_recruits),
			]
		)
	session.overworld["towns"] = towns
	return messages

static func controlled_resource_site_count(
	session: SessionStateStoreScript.SessionData,
	controller_id: String,
	family_id: String = ""
) -> int:
	var count := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		if family_id != "" and String(site.get("family", "")) != family_id:
			continue
		count += 1
	return count

static func describe_management_watch(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var project_summary := ""
	var disruption_summary := ""
	var recovery_summary := ""
	var delivery_summary := ""
	var project_score := -1
	var disruption_score := -1
	var recovery_score := -1
	var delivery_score := -1
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var town_name := _town_name(town)
		var logistics := town_logistics_state(session, town)
		var recovery := town_recovery_state(session, town)
		var capital_project := town_capital_project_state(town, session)
		var role := town_strategic_role(town)
		var local_project_score := int(capital_project.get("progress_complete", 0))
		if role == "capital":
			local_project_score += 4
		elif role == "stronghold":
			local_project_score += 2
		if bool(capital_project.get("vulnerable", false)):
			local_project_score += 6
		if local_project_score > project_score and (role in ["capital", "stronghold"] or int(capital_project.get("total", 0)) > 0):
			project_score = local_project_score
			project_summary = "%s project %d/%d%s" % [
				town_name,
				int(capital_project.get("progress_complete", 0)),
				int(capital_project.get("progress_total", 0)),
				" vulnerable" if bool(capital_project.get("vulnerable", false)) else "",
			]
		var local_disruption_score := int(logistics.get("disrupted_count", 0)) * 2 + int(logistics.get("threatened_count", 0))
		if local_disruption_score > disruption_score and local_disruption_score > 0:
			disruption_score = local_disruption_score
			disruption_summary = "%s logistics %s" % [town_name, String(logistics.get("summary", ""))]
		var local_recovery_score := int(recovery.get("pressure", 0))
		if local_recovery_score > recovery_score:
			recovery_score = local_recovery_score
			if bool(recovery.get("active", false)):
				recovery_summary = "%s %s" % [town_name, String(recovery.get("summary", ""))]
		var local_delivery_score := int(logistics.get("delivery_count", 0)) * 2 + int(logistics.get("threatened_count", 0))
		if local_delivery_score > delivery_score and int(logistics.get("delivery_count", 0)) > 0:
			delivery_score = local_delivery_score
			var delivery_labels = logistics.get("delivery_site_labels", [])
			if delivery_labels is Array and not delivery_labels.is_empty():
				delivery_summary = "%s %s" % [town_name, String(delivery_labels[0])]
	var parts := []
	if project_summary != "":
		parts.append(project_summary)
	if disruption_summary != "":
		parts.append(disruption_summary)
	if recovery_summary != "":
		parts.append(recovery_summary)
	if delivery_summary != "":
		parts.append(delivery_summary)
	if parts.is_empty():
		return "Town lines are stable."
	return " | ".join(parts)

static func describe_town_build_projection(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building_id: String
) -> String:
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		return "Projection unavailable."
	var current_growth := town_weekly_growth(town, session)
	var current_logistics := town_logistics_state(session, town)
	var current_quality := town_reinforcement_quality(town, session)
	var current_readiness := town_battle_readiness(town, session)
	var current_pressure := town_pressure_output(town, session)
	var current_recovery := town_recovery_state(session, town)
	var current_project := town_capital_project_state(town, session)
	var projected_town := town.duplicate(true)
	var built_buildings = _normalize_built_buildings_for_town_state(projected_town)
	if building_id not in built_buildings:
		built_buildings.append(building_id)
	projected_town["built_buildings"] = built_buildings
	var projected_growth := town_weekly_growth(projected_town, session)
	var projected_logistics := town_logistics_state(session, projected_town)
	var projected_quality := town_reinforcement_quality(projected_town, session)
	var projected_readiness := town_battle_readiness(projected_town, session)
	var projected_pressure := town_pressure_output(projected_town, session)
	var projected_recovery := town_recovery_state(session, projected_town)
	var projected_project := town_capital_project_state(projected_town, session)
	var parts := []
	var growth_projection := _describe_recruit_projection(current_growth, projected_growth)
	if growth_projection != "":
		parts.append("Weekly %s" % growth_projection)
	var quality_delta := projected_quality - current_quality
	if quality_delta != 0:
		parts.append("Quality %s" % _describe_signed_int(quality_delta))
	var readiness_delta := projected_readiness - current_readiness
	if readiness_delta != 0:
		parts.append("Readiness %s" % _describe_signed_int(readiness_delta))
	var pressure_delta := projected_pressure - current_pressure
	if pressure_delta != 0:
		parts.append("%s %s" % [_town_pressure_label(town), _describe_signed_int(pressure_delta)])
	var relief_delta := int(projected_recovery.get("relief_per_day", 1)) - int(current_recovery.get("relief_per_day", 1))
	if relief_delta != 0:
		parts.append("Recovery %s/day" % _describe_signed_int(relief_delta))
	if int(projected_project.get("progress_complete", 0)) != int(current_project.get("progress_complete", 0)):
		parts.append("Project %d/%d" % [
			int(projected_project.get("progress_complete", 0)),
			int(projected_project.get("progress_total", 0)),
		])
	if int(projected_project.get("support_total", 0)) > 0 and (
		int(projected_project.get("progress_complete", 0)) != int(current_project.get("progress_complete", 0))
		or bool(projected_project.get("active", false))
	):
		var anchor_summary := "Anchor watch %d/%d" % [
			int(projected_project.get("support_met", 0)),
			int(projected_project.get("support_total", 0)),
		]
		var missing_support = projected_project.get("missing_support_labels", [])
		if missing_support is Array and not missing_support.is_empty():
			anchor_summary += " | Missing %s" % ", ".join(missing_support)
		if int(projected_project.get("recovery_guard", 0)) > 0:
			anchor_summary += " | Recovery +%d/day" % int(projected_project.get("recovery_guard", 0))
		parts.append(anchor_summary)
	var logistics_required_total = max(
		int(current_logistics.get("required_total", 0)),
		int(projected_logistics.get("required_total", 0))
	)
	if logistics_required_total > 0 and (
		int(projected_logistics.get("support_gap", 0)) != int(current_logistics.get("support_gap", 0))
		or int(projected_logistics.get("met_requirements", 0)) != int(current_logistics.get("met_requirements", 0))
	):
		var logistics_summary := "Logistics %d/%d anchors" % [
			int(projected_logistics.get("met_requirements", 0)),
			int(projected_logistics.get("required_total", 0)),
		]
		var missing_families = projected_logistics.get("missing_family_labels", [])
		if missing_families is Array and not missing_families.is_empty():
			logistics_summary += " | Missing %s" % ", ".join(missing_families)
		parts.append(logistics_summary)
	if bool(projected_project.get("vulnerable", false)) and not bool(current_project.get("vulnerable", false)):
		parts.append("Vulnerability window opens")
	elif not bool(projected_project.get("vulnerable", false)) and bool(current_project.get("vulnerable", false)):
		parts.append("Closes vulnerability window")
	if parts.is_empty():
		return "Projection: steadies current output."
	return "Projection: %s." % " | ".join(parts)

static func apply_town_recovery_pressure(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String,
	amount: int,
	source: String = ""
) -> String:
	if session == null or town_placement_id == "" or amount <= 0:
		return ""
	var town_result := _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	recovery["pressure"] = max(0, int(recovery.get("pressure", 0))) + amount
	recovery["last_event_day"] = session.day
	recovery["source"] = source
	town["recovery"] = recovery
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	var recovery_state := town_recovery_state(session, town)
	var source_clause := " from %s" % source if source != "" else ""
	return "%s recovery +%d%s | %d day%s to stabilize." % [
		_town_name(town),
		amount,
		source_clause,
		int(recovery_state.get("days_to_clear", 0)),
		"" if int(recovery_state.get("days_to_clear", 0)) == 1 else "s",
	]

static func relieve_town_recovery_pressure(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String,
	amount: int,
	source: String = ""
) -> String:
	if session == null or town_placement_id == "" or amount <= 0:
		return ""
	var town_result := _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	var current_pressure = max(0, int(recovery.get("pressure", 0)))
	if current_pressure <= 0:
		return ""
	var relieved = min(current_pressure, amount)
	recovery["pressure"] = max(0, current_pressure - relieved)
	recovery["last_event_day"] = session.day
	if int(recovery.get("pressure", 0)) <= 0:
		recovery["source"] = ""
	elif source != "":
		recovery["source"] = source
	town["recovery"] = recovery
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	var recovery_state := town_recovery_state(session, town)
	var source_clause := " via %s" % source if source != "" else ""
	if int(recovery.get("pressure", 0)) <= 0:
		return "%s recovery stabilized%s." % [_town_name(town), source_clause]
	return "%s recovery -%d%s | %d day%s to stabilize." % [
		_town_name(town),
		relieved,
		source_clause,
		int(recovery_state.get("days_to_clear", 0)),
		"" if int(recovery_state.get("days_to_clear", 0)) == 1 else "s",
	]

static func apply_resource_site_disruption(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary,
	previous_controller: String,
	attacker_controller: String
) -> String:
	if previous_controller in ["", attacker_controller]:
		return ""
	var town_result := _nearest_town_for_controller(
		session,
		previous_controller,
		int(node.get("x", 0)),
		int(node.get("y", 0))
	)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var town = town_result.get("town", {})
	var distance = abs(int(node.get("x", 0)) - int(town.get("x", 0))) + abs(int(node.get("y", 0)) - int(town.get("y", 0)))
	if distance > int(_town_logistics_plan(town).get("support_radius", 0)):
		return ""
	var disruption_pressure := int(_resource_site_town_support(site).get("disruption_pressure", 0))
	var response_state := _resource_site_response_state(session, node, site)
	var disruption_source := String(site.get("name", "frontier route"))
	if bool(response_state.get("active", false)):
		disruption_pressure += max(1, int(response_state.get("recovery_relief", 0)))
		disruption_pressure += max(1, int(response_state.get("break_pressure", 0)))
		disruption_source = "%s escort line" % disruption_source
	if disruption_pressure <= 0:
		return ""
	return apply_town_recovery_pressure(
		session,
		String(town.get("placement_id", "")),
		disruption_pressure,
		disruption_source
	)

static func town_recruit_cost(session: SessionStateStoreScript.SessionData, town: Dictionary, unit_id: String) -> Dictionary:
	var unit := ContentService.get_unit(unit_id)
	var adjusted_cost := HeroProgressionRulesScript.scale_recruit_cost(session.overworld.get("hero", {}), unit.get("cost", {}))
	return _apply_percent_discount(adjusted_cost, _recruitment_discount_percent(town, unit_id))

static func get_town_build_status(town: Dictionary, building_id: String) -> Dictionary:
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		return {
			"buildable": false,
			"blockers": ["Missing authored building data."],
			"blocked_message": "That building has no authored data.",
		}

	var built_buildings = _normalize_built_buildings_for_town_state(town)
	var blockers := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var buildable_ids := []
	for buildable_id_value in town_template.get("buildable_building_ids", []):
		buildable_ids.append(String(buildable_id_value))
	if building_id not in buildable_ids:
		blockers.append("Not authored for this town.")
	if building_id in built_buildings:
		blockers.append("Already built.")
	var missing_requirements := _missing_build_requirements(building, built_buildings)
	for requirement_id in missing_requirements:
		var requirement := ContentService.get_building(String(requirement_id))
		var requirement_name := String(requirement.get("name", requirement_id))
		if String(building.get("upgrade_from", "")) == String(requirement_id):
			blockers.append("Upgrade %s first." % requirement_name)
		else:
			blockers.append("Requires %s." % requirement_name)

	var building_faction_id := String(building.get("faction_id", ""))
	var town_faction_id := _town_faction_id(town)
	if building_faction_id != "" and town_faction_id != "" and building_faction_id != town_faction_id:
		var faction_name := String(ContentService.get_faction(building_faction_id).get("name", building_faction_id))
		blockers.append("Belongs to %s towns." % faction_name)

	return {
		"buildable": blockers.is_empty(),
		"blockers": blockers,
		"blocked_message": " ".join(blockers),
		"building": building,
	}

static func get_context_actions(session: SessionStateStoreScript.SessionData) -> Array:
	var actions := []
	var context := get_active_context(session)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			if String(town.get("owner", "neutral")) != "player":
				var owner := String(town.get("owner", "neutral"))
				actions.append(
					{
						"id": "capture_town",
						"label": (
							"Assault Town"
							if owner == "enemy" and _town_requires_assault(town)
							else ("Capture Town" if owner == "enemy" else "Claim Town")
						),
						"summary": _context_action_summary(session, "capture_town", context),
					}
				)
			else:
				actions.append(
					{
						"id": "visit_town",
						"label": "Visit Town",
						"summary": _context_action_summary(session, "visit_town", context),
					}
				)
		"resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			if _resource_node_claimable_by_player(node, site, session):
				actions.append(
					{
						"id": "collect_resource",
						"label": _resource_site_action_label(node, site),
						"summary": _context_action_summary(session, "collect_resource", context),
					}
				)
			elif _resource_site_is_persistent(site) and String(node.get("collected_by_faction_id", "")) == "player":
				var response_action := _resource_site_response_action(session, node, site)
				if not response_action.is_empty():
					actions.append(response_action)
			var artifact_result := _find_active_artifact_node(session)
			if int(artifact_result.get("index", -1)) >= 0:
				actions.append(
					{
						"id": "collect_artifact",
						"label": "Recover Artifact",
						"summary": _context_action_summary(
							session,
							"collect_artifact",
							{"type": "artifact", "node": artifact_result.get("node", {})}
						),
					}
				)
		"artifact":
			actions.append(
				{
					"id": "collect_artifact",
					"label": "Recover Artifact",
					"summary": _context_action_summary(session, "collect_artifact", context),
				}
			)
		"encounter":
			actions.append(
				{
					"id": "enter_battle",
					"label": "Enter Battle",
					"summary": _context_action_summary(session, "enter_battle", context),
				}
			)
	return actions

static func get_artifact_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_overworld_state(session)
	return ArtifactRulesScript.get_management_actions(session.overworld.get("hero", {}))

static func get_spell_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_overworld_state(session)
	return SpellRulesScript.get_overworld_actions(
		session.overworld.get("hero", {}),
		session.overworld.get("movement", {})
	)

static func get_hero_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_overworld_state(session)
	return HeroCommandRulesScript.get_overworld_switch_actions(session)

static func switch_active_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var result := HeroCommandRulesScript.set_active_hero(session, hero_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to change command."))}
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func get_specialty_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_overworld_state(session)
	return HeroProgressionRulesScript.get_choice_actions(session.overworld.get("hero", {}))

static func choose_specialty(session: SessionStateStoreScript.SessionData, specialty_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var hero = session.overworld.get("hero", {})
	var previous_movement_max := _movement_max_from_hero(hero, session)
	var previous_mana_max := int(hero.get("spellbook", {}).get("mana", {}).get("max", SpellRulesScript.mana_max_from_hero(hero)))
	var result := HeroProgressionRulesScript.choose_specialty(hero, specialty_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to choose specialty."))}

	session.overworld["hero"] = ArtifactRulesScript.ensure_hero_artifacts(
		SpellRulesScript.ensure_hero_spellbook(result.get("hero", hero))
	)
	_sync_movement_to_hero(session, previous_movement_max)
	_sync_spellbook_to_hero(session, previous_mana_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func get_town_build_options(town: Dictionary) -> Array:
	var options := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if bool(get_town_build_status(town, building_id).get("buildable", false)):
			options.append(building_id)
	return options

static func get_town_recruit_options(town: Dictionary) -> Array:
	var options := []
	var available_recruits = town.get("available_recruits", {})
	if not (available_recruits is Dictionary):
		return options
	for unit_id in available_recruits.keys():
		if int(available_recruits[unit_id]) > 0:
			options.append(String(unit_id))
	return options

static func _normalize_army_state(army: Dictionary) -> Dictionary:
	var normalized_stacks := []
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if unit_id == "":
			continue
		normalized_stacks.append({"unit_id": unit_id, "count": max(0, int(stack.get("count", 0)))})
	return {
		"id": String(army.get("id", "")),
		"name": String(army.get("name", "Field Army")),
		"stacks": normalized_stacks,
	}

static func _normalize_towns(towns: Array) -> Array:
	var normalized := []
	for town in towns:
		if not (town is Dictionary):
			continue
		var built_buildings = town.get("built_buildings", [])
		if not (built_buildings is Array):
			built_buildings = []
		var normalized_town := {
			"placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"owner": String(town.get("owner", "neutral")),
			"built_buildings": built_buildings.duplicate(true),
			"available_recruits": _normalize_resource_dict(town.get("available_recruits", {})),
			"garrison": town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else [],
			"recovery": _normalize_town_recovery_state(town.get("recovery", {})),
			"front": _normalize_town_front_state(town.get("front", {})),
			"occupation": _normalize_town_occupation_state(town.get("occupation", {})),
		}
		normalized_town["built_buildings"] = _normalize_built_buildings_for_town_state(normalized_town)
		if not town.has("available_recruits") or not (town.get("available_recruits") is Dictionary):
			normalized_town["available_recruits"] = _seed_recruits_for_town(normalized_town)
		normalized.append(normalized_town)
	return normalized

static func _normalize_resource_nodes(nodes: Array) -> Array:
	var normalized := []
	for node in nodes:
		if not (node is Dictionary):
			continue
		normalized.append(
			{
				"placement_id": String(node.get("placement_id", "")),
				"site_id": String(node.get("site_id", "")),
				"x": int(node.get("x", 0)),
				"y": int(node.get("y", 0)),
				"collected": bool(node.get("collected", false)),
				"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
				"collected_day": max(0, int(node.get("collected_day", 0))),
				"response_origin": String(node.get("response_origin", "")),
				"response_source_town_id": String(node.get("response_source_town_id", "")),
				"response_last_day": max(0, int(node.get("response_last_day", 0))),
				"response_until_day": max(0, int(node.get("response_until_day", 0))),
				"response_commander_id": String(node.get("response_commander_id", "")),
				"response_security_rating": max(0, int(node.get("response_security_rating", 0))),
				"delivery_controller_id": String(node.get("delivery_controller_id", "")),
				"delivery_origin_town_id": String(node.get("delivery_origin_town_id", "")),
				"delivery_target_kind": String(node.get("delivery_target_kind", "")),
				"delivery_target_id": String(node.get("delivery_target_id", "")),
				"delivery_target_label": String(node.get("delivery_target_label", "")),
				"delivery_arrival_day": max(0, int(node.get("delivery_arrival_day", 0))),
				"delivery_manifest": _normalize_recruit_payload(node.get("delivery_manifest", {})),
			}
		)
	return normalized

static func _normalize_artifact_nodes(nodes: Array) -> Array:
	return ArtifactRulesScript.normalize_artifact_nodes(nodes)

static func _find_resource_node_at(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and _position_matches(node, pos):
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_context_resource_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var node_result := _find_resource_node_at(session)
	if int(node_result.get("index", -1)) < 0:
		node_result = _find_resource_node_interaction_at(session)
	if int(node_result.get("index", -1)) < 0:
		return {"index": -1, "node": {}}
	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if _resource_site_is_persistent(site) or not bool(node.get("collected", false)):
		return node_result
	return {"index": -1, "node": {}}

static func _find_resource_node_interaction_at(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and _resource_node_matches_interaction_tile(node, pos):
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_resource_node_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "node": {}}
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var visit_result := _find_active_town_by_visit_context(session)
	if int(visit_result.get("index", -1)) >= 0:
		return visit_result
	var pos := hero_position(session)
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and _position_matches(town, pos):
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_active_town_by_visit_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {"index": -1, "town": {}}
	var placement_id := String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, ""))
	if placement_id == "":
		return {"index": -1, "town": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) >= 0 and String(town.get("owner", "neutral")) == "player":
		return town_result
	session.flags.erase(ACTIVE_TOWN_PLACEMENT_KEY)
	return {"index": -1, "town": {}}

static func _find_active_resource_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var node_result := _find_resource_node_at(session)
	if int(node_result.get("index", -1)) < 0:
		return {"index": -1, "node": {}}
	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if _resource_node_claimable_by_player(node, site, session):
		return node_result
	return {"index": -1, "node": {}}

static func _find_active_artifact_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var nodes = session.overworld.get("artifact_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and _position_matches(node, pos) and not bool(node.get("collected", false)):
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _resource_site_is_persistent(site: Dictionary) -> bool:
	return bool(site.get("persistent_control", false))

static func _resource_node_matches_controller(node: Dictionary, controller_id: String) -> bool:
	return String(node.get("collected_by_faction_id", "")) == controller_id

static func _resource_site_is_repeatable(site: Dictionary) -> bool:
	return bool(site.get("repeatable", false)) or String(site.get("family", "")) == "repeatable_service"

static func _resource_site_visit_cost(site: Dictionary) -> Dictionary:
	return _normalize_resource_dict(site.get("service_cost", {}))

static func _resource_site_repeat_ready(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> bool:
	if not _resource_site_is_repeatable(site):
		return false
	if not bool(node.get("collected", false)):
		return true
	if session == null:
		return false
	var cooldown: int = max(1, int(site.get("visit_cooldown_days", 1)))
	return session.day >= int(node.get("collected_day", 0)) + cooldown

static func _resource_site_next_visit_day(node: Dictionary, site: Dictionary) -> int:
	return int(node.get("collected_day", 0)) + max(1, int(site.get("visit_cooldown_days", 1)))

static func _resource_site_repeatable_block_message(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var next_day := _resource_site_next_visit_day(node, site)
	if session != null and session.day < next_day:
		return "%s can be used again on day %d." % [String(site.get("name", "This service")), next_day]
	return "%s is not available right now." % String(site.get("name", "This service"))

static func _resource_node_claimable_by_player(
	node: Dictionary,
	site: Dictionary,
	session: SessionStateStoreScript.SessionData = null
) -> bool:
	if _resource_site_is_repeatable(site) and not _resource_site_is_persistent(site):
		return _resource_site_repeat_ready(session, node, site)
	if _resource_site_is_persistent(site):
		return String(node.get("collected_by_faction_id", "")) != "player"
	return not bool(node.get("collected", false))

static func _resource_site_claim_rewards(site: Dictionary) -> Dictionary:
	var rewards = site.get("claim_rewards", site.get("rewards", {}))
	return rewards if rewards is Dictionary else {}

static func _resource_site_claim_recruits(site: Dictionary) -> Dictionary:
	var recruits = site.get("claim_recruits", {})
	if recruits is Dictionary and not recruits.is_empty():
		return recruits
	var roster = site.get("neutral_roster", {})
	if roster is Dictionary:
		var roster_recruits = roster.get("claim_recruits", {})
		if roster_recruits is Dictionary:
			return roster_recruits
	return {}

static func _resource_site_weekly_recruits(site: Dictionary) -> Dictionary:
	var recruits = site.get("weekly_recruits", {})
	if recruits is Dictionary and not recruits.is_empty():
		return recruits
	var roster = site.get("neutral_roster", {})
	if roster is Dictionary:
		var roster_recruits = roster.get("weekly_recruits", {})
		if roster_recruits is Dictionary:
			return roster_recruits
	return {}

static func resource_site_is_recruit_source(site: Dictionary) -> bool:
	return (
		String(site.get("family", "")) == "neutral_dwelling"
		or not _resource_site_claim_recruits(site).is_empty()
		or not _resource_site_weekly_recruits(site).is_empty()
	)

static func describe_recruit_source_compact(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	if not resource_site_is_recruit_source(site):
		return ""
	var parts := []
	var claim_line := _recruit_source_roster_line("Ready", _resource_site_claim_recruits(site), 2)
	if claim_line != "":
		parts.append(claim_line)
	var weekly_line := _recruit_source_roster_line("Weekly", _resource_site_weekly_recruits(site), 1)
	if weekly_line != "":
		parts.append(weekly_line)
	var guard_line := _resource_site_guard_or_contest_line(session, node, site)
	if guard_line != "":
		parts.append(guard_line)
	return " | ".join(_non_empty_strings(parts))

static func describe_recruit_source_inspection(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	if not resource_site_is_recruit_source(site):
		return ""
	var lines := []
	var dwelling_label := _resource_site_neutral_dwelling_label(site)
	var scope := String(site.get("dwelling_scope", "")).strip_edges()
	if dwelling_label != "":
		lines.append("Recruit Source: %s | Neutral dwelling" % dwelling_label)
	elif scope == "faction_linked":
		lines.append("Recruit Source: %s | Faction-linked muster" % String(site.get("name", "Recruit source")))
	else:
		lines.append("Recruit Source: %s" % String(site.get("name", "Recruit source")))
	var dwelling_id := String(site.get("neutral_dwelling_family_id", ""))
	if dwelling_id != "":
		var dwelling := ContentService.get_neutral_dwelling(dwelling_id)
		var summary := _short_player_text(String(dwelling.get("summary", "")), 112)
		if summary != "":
			lines.append("Identity: %s" % summary)
	var claim_line := _recruit_source_roster_line("Ready", _resource_site_claim_recruits(site), 4)
	if claim_line != "":
		lines.append(claim_line)
	var weekly_line := _recruit_source_roster_line("Weekly", _resource_site_weekly_recruits(site), 4)
	if weekly_line != "":
		lines.append("%s to nearest held town" % weekly_line)
	lines.append("Cadence: %s | %s" % [
		_interaction_cadence_label(_resource_site_interaction_cadence(site, ContentService.get_map_object_for_resource_site(String(node.get("site_id", site.get("id", "")))))).trim_prefix("Cadence: "),
		_resource_site_control_brief(node, site),
	])
	var support_line := _recruit_source_support_readiness_line(session, node, site)
	if support_line != "":
		lines.append(support_line)
	var route_line := _resource_site_route_line(session, node, site)
	if route_line != "":
		lines.append("Route: %s" % route_line)
	var guard_line := _resource_site_guard_or_contest_line(session, node, site)
	if guard_line != "":
		lines.append("Guard: %s" % guard_line)
	lines.append(_recruit_source_why_line(site))
	return "\n".join(_non_empty_strings(lines))

static func _resource_site_neutral_dwelling_label(site: Dictionary) -> String:
	var dwelling_id := String(site.get("neutral_dwelling_family_id", ""))
	if dwelling_id == "":
		return ""
	var dwelling := ContentService.get_neutral_dwelling(dwelling_id)
	if dwelling.is_empty():
		return dwelling_id
	return String(dwelling.get("name", dwelling_id))

static func _resource_site_family_label(site: Dictionary) -> String:
	match String(site.get("family", "")):
		"mine":
			return "Mine"
		"neutral_dwelling":
			return "Neutral Dwelling"
		"faction_outpost":
			return "Faction Outpost"
		"frontier_shrine":
			return "Frontier Shrine"
		"guarded_reward_site":
			return "Guarded Reward Site"
		"scouting_structure":
			return "Scouting Structure"
		"transit_object":
			return "Transit Object"
		"repeatable_service":
			return "Service Building"
		_:
			return "Resource Site"

static func describe_resource_site_surface(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var parts := [_resource_site_role_label(node, site), _resource_site_family_label(site)]
	var control_label := _resource_site_control_label(node, site)
	if control_label != "":
		parts.append(control_label)
	var income_summary := _describe_resource_delta(site.get("control_income", {}))
	if income_summary != "":
		parts.append("Daily %s" % income_summary)
	var weekly_summary := _describe_recruit_delta(_resource_site_weekly_recruits(site))
	if weekly_summary != "":
		parts.append("Weekly %s" % weekly_summary)
	var claim_recruit_summary := _describe_recruit_delta(_resource_site_claim_recruits(site))
	if claim_recruit_summary != "":
		parts.append("Field recruits %s" % claim_recruit_summary)
	var reward_summary := _describe_reward_delta(_resource_site_claim_rewards(site))
	if reward_summary != "" and not _resource_site_is_persistent(site):
		parts.append("Reward %s" % reward_summary)
	var response_state := _resource_site_response_state(session, node, site)
	if String(node.get("collected_by_faction_id", "")) == "player" and int(response_state.get("watch_days", 0)) > 0:
		parts.append("Support order ready")
	return " | ".join(_non_empty_strings(parts))

static func describe_resource_site_control_summary(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var parts := []
	var control_line := _resource_site_control_brief(node, site)
	if control_line != "":
		parts.append(control_line)
	var yield_line := _resource_site_yield_line(session, node, site)
	if yield_line != "":
		parts.append(yield_line)
	var guard_line := _resource_site_guard_or_contest_line(session, node, site)
	if guard_line != "":
		parts.append(guard_line)
	return " | ".join(_non_empty_strings(parts))

static func describe_resource_site_control_inspection(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var lines := []
	var control_detail := _resource_site_control_detail(node, site)
	if control_detail != "":
		lines.append("Control: %s" % control_detail)
	var yield_line := _resource_site_yield_line(session, node, site)
	if yield_line != "":
		lines.append("Economy: %s" % yield_line)
	var route_line := _resource_site_route_line(session, node, site)
	if route_line != "":
		lines.append("Route: %s" % route_line)
	var guard_line := _resource_site_guard_or_contest_line(session, node, site)
	if guard_line != "":
		lines.append("Guard: %s" % guard_line)
	var recruit_source := describe_recruit_source_inspection(session, node, site)
	if recruit_source != "":
		lines.append(recruit_source)
	return "\n".join(lines)

static func describe_resource_site_interaction_surface(node: Dictionary, site: Dictionary) -> String:
	var map_object := ContentService.get_map_object_for_resource_site(String(node.get("site_id", "")))
	var cadence := _resource_site_interaction_cadence(site, map_object)
	var interaction_parts := [_interaction_cadence_label(cadence)]
	if _resource_site_is_persistent(site):
		interaction_parts.append("capture/ownership")
		var control_income = site.get("control_income", {})
		if control_income is Dictionary and not control_income.is_empty():
			interaction_parts.append("income")
		if not _resource_site_weekly_recruits(site).is_empty():
			interaction_parts.append("weekly recruits")
		if site.has("response_profile"):
			interaction_parts.append("support response")
	elif _resource_site_is_repeatable(site):
		interaction_parts.append("repeat service")
	else:
		interaction_parts.append("pickup/cache")
	var object_class := _resource_site_object_class_label(site, map_object)
	if object_class != "":
		interaction_parts.push_front(object_class)
	var role_tags := _resource_site_role_tag_summary(site, map_object)
	if role_tags != "":
		interaction_parts.append(role_tags)
	return " | ".join(_non_empty_strings(interaction_parts))

static func describe_encounter_object_surface(encounter: Dictionary) -> String:
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	var neutral_metadata = encounter.get("neutral_encounter", {})
	var primary_class := String(map_object.get("primary_class", encounter.get("primary_class", ""))).strip_edges()
	if primary_class == "" and neutral_metadata is Dictionary:
		primary_class = String(neutral_metadata.get("primary_class", "")).strip_edges()
	var parts := []
	if primary_class != "":
		parts.append(_humanize_id(primary_class))
	var tag_summary := _encounter_object_tag_summary(encounter, map_object)
	if tag_summary != "":
		parts.append(tag_summary)
	var risk_summary := _encounter_risk_label(encounter)
	if risk_summary != "":
		parts.append(risk_summary)
	var difficulty_summary := _encounter_difficulty_label(encounter)
	if difficulty_summary != "":
		parts.append(difficulty_summary)
	var interaction_mode := _encounter_object_interaction_label(encounter, map_object)
	if interaction_mode != "":
		parts.append(interaction_mode)
	var guard_summary := _encounter_guard_summary(encounter)
	if guard_summary != "":
		parts.append(guard_summary)
	return " | ".join(_non_empty_strings(parts))

static func _resource_site_claim_message(site: Dictionary, previous_controller: String) -> String:
	if _resource_site_is_repeatable(site) and not _resource_site_is_persistent(site):
		return "Used %s." % String(site.get("name", "the service"))
	if not _resource_site_is_persistent(site):
		return "Claimed %s." % String(site.get("name", "the site"))
	if previous_controller == "":
		return "Secured %s." % String(site.get("name", "the site"))
	if previous_controller == "player":
		return "%s already answers your banners." % String(site.get("name", "The site"))
	return "Retook %s from hostile control." % String(site.get("name", "the site"))

static func _recruit_source_roster_line(label: String, recruits: Variant, limit: int) -> String:
	if not (recruits is Dictionary) or recruits.is_empty():
		return ""
	var unit_ids := []
	for unit_id_value in recruits.keys():
		var unit_id := String(unit_id_value)
		if unit_id != "":
			unit_ids.append(unit_id)
	unit_ids.sort()
	var parts := []
	for unit_id in unit_ids:
		var count: int = maxi(0, int(recruits.get(unit_id, 0)))
		if count <= 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		var unit_name := String(unit.get("name", unit_id))
		var role_label := _unit_role_tier_label(unit)
		var cost_label := _describe_resource_delta(unit.get("cost", {}))
		var detail_parts := _non_empty_strings([role_label, cost_label])
		parts.append("+%d %s%s" % [
			count,
			unit_name,
			" (%s)" % ", ".join(detail_parts) if not detail_parts.is_empty() else "",
		])
		if parts.size() >= max(1, limit):
			break
	var hidden_count: int = maxi(0, unit_ids.size() - parts.size())
	if hidden_count > 0:
		parts.append("%d more" % hidden_count)
	return "%s: %s" % [label, ", ".join(parts)] if not parts.is_empty() else ""

static func _unit_role_tier_label(unit: Dictionary) -> String:
	var tier: int = maxi(1, int(unit.get("tier", 1)))
	var role := String(unit.get("role", "")).strip_edges()
	if role == "":
		role = "ranged" if bool(unit.get("ranged", false)) else "melee"
	return "T%d %s" % [tier, _humanize_id(role)]

static func _recruit_source_support_readiness_line(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var response_state := _resource_site_response_state(session, node, site)
	if int(response_state.get("watch_days", 0)) <= 0:
		return ""
	var parts := [String(response_state.get("action_label", "Support response"))]
	var cost: Dictionary = _normalize_resource_dict(response_state.get("resource_cost", {}))
	var cost_summary := _describe_resource_delta(cost)
	if cost_summary != "":
		var readiness := "ready"
		if session != null and not _can_afford(session, cost):
			var shortfall := _describe_resource_delta(_resource_pool_shortfall(session.overworld.get("resources", {}), cost))
			readiness = "needs %s" % shortfall if shortfall != "" else "not ready"
		parts.append("%s %s" % [cost_summary, readiness])
	var movement_cost := int(response_state.get("movement_cost", 0))
	if movement_cost > 0:
		var movement_left := int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0
		parts.append("move %d/%d" % [movement_left, movement_cost])
	parts.append("%d day%s" % [
		int(response_state.get("watch_days", 0)),
		"" if int(response_state.get("watch_days", 0)) == 1 else "s",
	])
	var impact_summary := _resource_site_response_effect_summary(response_state)
	if impact_summary != "":
		parts.append(impact_summary)
	return "Support: %s" % " | ".join(_non_empty_strings(parts))

static func _recruit_source_why_line(site: Dictionary) -> String:
	var reasons := []
	if not _resource_site_claim_recruits(site).is_empty():
		reasons.append("adds field recruits")
	if not _resource_site_weekly_recruits(site).is_empty():
		reasons.append("feeds weekly musters")
	var control_income = site.get("control_income", {})
	if control_income is Dictionary and not control_income.is_empty():
		reasons.append("keeps local pay flowing")
	if reasons.is_empty():
		return "Why: Securing it strengthens the local route."
	return "Why: Capture %s." % ", ".join(reasons)

static func _resource_site_action_label(node: Dictionary, site: Dictionary) -> String:
	var authored_label := String(site.get("action_label", ""))
	if authored_label != "":
		return authored_label
	if _resource_site_is_persistent(site) and String(node.get("collected_by_faction_id", "")) not in ["", "player"]:
		return "Reclaim Site"
	match String(site.get("family", "")):
		"mine":
			return "Claim Mine"
		"neutral_dwelling":
			return "Secure Dwelling"
		"faction_outpost":
			return "Secure Outpost"
		"frontier_shrine":
			return "Bind Shrine"
		"guarded_reward_site":
			return "Search Vault"
		"scouting_structure":
			return "Secure Watch"
		"transit_object":
			return "Open Route"
		"repeatable_service":
			return "Use Service"
		_:
			return "Claim Site"

static func _resource_site_role_label(node: Dictionary, site: Dictionary) -> String:
	if _resource_site_is_persistent(site):
		match String(site.get("family", "")):
			"mine":
				return "Persistent economy site"
			"neutral_dwelling":
				return "Persistent recruit site"
			"faction_outpost", "scouting_structure", "transit_object":
				return "Transit/support object"
			"frontier_shrine":
				return "Support shrine"
			"guarded_reward_site":
				return "Persistent reward site"
			_:
				return "Persistent economy site"
	if _resource_site_is_repeatable(site):
		return "Repeatable service"
	var site_id := String(node.get("site_id", ""))
	var map_object := ContentService.get_map_object_for_resource_site(site_id)
	if String(map_object.get("family", "")) == "pickup":
		return "Pickup/cache"
	return "Pickup/cache"

static func _resource_site_control_label(node: Dictionary, site: Dictionary) -> String:
	if _resource_site_is_persistent(site):
		var controller := String(node.get("collected_by_faction_id", ""))
		if controller == "":
			return "Unclaimed"
		if controller == "player":
			return "Player held"
		return "AI held: %s" % _controller_display_name(controller)
	if bool(node.get("collected", false)):
		return "Collected"
	return "Unclaimed"

static func _resource_site_control_brief(node: Dictionary, site: Dictionary) -> String:
	if _resource_site_is_persistent(site):
		var controller := String(node.get("collected_by_faction_id", ""))
		if controller == "":
			return "Control unclaimed"
		if controller == "player":
			return "Control player held"
		return "Control held by %s" % _controller_display_name(controller)
	if bool(node.get("collected", false)):
		var controller := String(node.get("collected_by_faction_id", ""))
		if controller == "" or controller == "player":
			return "State collected"
		return "State collected by %s" % _controller_display_name(controller)
	return "State uncollected"

static func _resource_site_control_detail(node: Dictionary, site: Dictionary) -> String:
	if _resource_site_is_persistent(site):
		var controller := String(node.get("collected_by_faction_id", ""))
		if controller == "":
			return "Unclaimed; capture flips control."
		if controller == "player":
			return "Player held; income and support stay active while held."
		return "%s held; reclaim to deny its income and support." % _controller_display_name(controller)
	if bool(node.get("collected", false)):
		var collected_day := int(node.get("collected_day", 0))
		var day_clause := " on day %d" % collected_day if collected_day > 0 else ""
		var controller := String(node.get("collected_by_faction_id", ""))
		if controller == "" or controller == "player":
			return "Collected%s." % day_clause
		return "Collected by %s%s." % [_controller_display_name(controller), day_clause]
	return "Uncollected; one visit can claim it."

static func _resource_site_yield_line(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var parts := []
	var claim_summary := _describe_reward_delta(_resource_site_claim_rewards(site))
	var income_summary := _describe_resource_delta(site.get("control_income", {}))
	var weekly_summary := _describe_recruit_delta(_resource_site_weekly_recruits(site))
	var claim_recruits := _describe_recruit_delta(_resource_site_claim_recruits(site))
	if _resource_site_is_persistent(site):
		if claim_summary != "":
			parts.append("claim %s" % claim_summary)
		if income_summary != "":
			parts.append("daily %s" % income_summary)
		if weekly_summary != "":
			parts.append("weekly %s" % weekly_summary)
		if claim_recruits != "":
			parts.append("capture recruits %s" % claim_recruits)
	else:
		var reward_summary := _describe_reward_delta(_resource_site_claim_rewards(site))
		if reward_summary != "":
			parts.append("one-time %s" % reward_summary)
	if _resource_site_is_repeatable(site):
		var cost_summary := _describe_resource_delta(_resource_site_visit_cost(site))
		if cost_summary != "":
			parts.append("service cost %s" % cost_summary)
		if _resource_site_repeat_ready(session, node, site):
			parts.append("service ready")
		elif bool(node.get("collected", false)):
			parts.append("next service day %d" % _resource_site_next_visit_day(node, site))
	var spell_id := String(site.get("learn_spell_id", ""))
	if spell_id != "":
		parts.append("teaches %s" % String(ContentService.get_spell(spell_id).get("name", spell_id)))
	return ", ".join(_non_empty_strings(parts))

static func _resource_site_route_line(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var parts := []
	if session == null or node.is_empty():
		return ""
	var linked_town_result := _resource_node_linked_town(session, node, "player")
	if int(linked_town_result.get("index", -1)) >= 0:
		parts.append("Linked %s" % _town_name(linked_town_result.get("town", {})))
	elif String(node.get("collected_by_faction_id", "")) == "player":
		parts.append("No owned town support in range")
	var response_state := _resource_site_response_state(session, node, site)
	if bool(response_state.get("active", false)):
		var response_line := "%s active %d day%s" % [
			String(response_state.get("action_label", "Route security")),
			int(response_state.get("remaining_days", 0)),
			"" if int(response_state.get("remaining_days", 0)) == 1 else "s",
		]
		if String(response_state.get("commander_name", "")) != "":
			response_line += "; %s detached" % String(response_state.get("commander_name", ""))
		parts.append(response_line)
	elif String(node.get("collected_by_faction_id", "")) == "player" and int(response_state.get("watch_days", 0)) > 0:
		parts.append("%s available" % String(response_state.get("action_label", "Route security")))
	var delivery_line := _resource_site_delivery_line(session, node, site)
	if delivery_line != "":
		parts.append(delivery_line)
	return " | ".join(_non_empty_strings(parts))

static func _resource_site_guard_or_contest_line(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var guard_encounter := _resource_site_guard_encounter(session, node, site)
	if not guard_encounter.is_empty():
		var guard := _resource_site_guard_link_for_encounter(guard_encounter)
		var line := "Guarded by %s" % encounter_display_name(guard_encounter)
		if bool(guard.get("clear_required_for_target", false)):
			line += "; clear guard to use site"
		elif bool(guard.get("blocks_approach", false)):
			line += "; blocks approach"
		return line
	var controller := String(node.get("collected_by_faction_id", ""))
	if controller == "":
		return ""
	var contest_encounter := _resource_site_contest_encounter(session, node, controller)
	if not contest_encounter.is_empty():
		return "%s is contesting this site" % encounter_display_name(contest_encounter)
	if _resource_site_under_threat(session, node, controller):
		return "Hostile pressure is contesting this site"
	return ""

static func _resource_site_guard_encounter(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	if session == null:
		return {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or is_encounter_resolved(session, encounter):
			continue
		var guard := _resource_site_guard_link_for_encounter(encounter)
		if guard.is_empty():
			continue
		if _resource_site_guard_targets_node(guard, node, site):
			return encounter
	return {}

static func _resource_site_contest_encounter(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	controller_id: String
) -> Dictionary:
	if session == null:
		return {}
	var best := {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) in ["", controller_id]:
			continue
		if String(encounter.get("target_kind", "")) != "resource":
			continue
		if String(encounter.get("target_placement_id", "")) != String(node.get("placement_id", "")):
			continue
		if best.is_empty() or int(encounter.get("goal_distance", 9999)) < int(best.get("goal_distance", 9999)):
			best = encounter
	return best

static func _resource_site_guard_link_for_encounter(encounter: Dictionary) -> Dictionary:
	var guard = encounter.get("guard_link", {})
	if guard is Dictionary and not guard.is_empty():
		return guard
	var metadata := _encounter_neutral_metadata(encounter)
	guard = metadata.get("guard_link", {})
	return guard if guard is Dictionary else {}

static func _resource_site_guard_targets_node(guard: Dictionary, node: Dictionary, site: Dictionary) -> bool:
	var node_placement_id := String(node.get("placement_id", ""))
	var site_id := String(site.get("id", node.get("site_id", "")))
	var target_placement_id := String(guard.get("target_placement_id", ""))
	var target_id := String(guard.get("target_id", ""))
	if target_placement_id != "" and target_placement_id == node_placement_id:
		return true
	if target_id != "" and target_id in [node_placement_id, site_id]:
		return true
	return false

static func _resource_site_object_class_label(site: Dictionary, map_object: Dictionary) -> String:
	var primary_class := String(map_object.get("primary_class", "")).strip_edges()
	if primary_class == "":
		primary_class = String(site.get("family", "")).strip_edges()
	if primary_class == "":
		return ""
	return "Class: %s" % _humanize_id(primary_class)

static func _resource_site_interaction_cadence(site: Dictionary, map_object: Dictionary) -> String:
	var interaction = map_object.get("interaction", {})
	if interaction is Dictionary:
		var cadence := String(interaction.get("cadence", "")).strip_edges()
		if cadence != "":
			return cadence
	if _resource_site_is_persistent(site):
		return "persistent_control"
	if _resource_site_is_repeatable(site):
		return "repeatable"
	return "one_time"

static func _interaction_cadence_label(cadence: String) -> String:
	match cadence:
		"persistent_control":
			return "Cadence: persistent control"
		"one_time":
			return "Cadence: one-time"
		"repeatable":
			return "Cadence: repeatable"
		"repeatable_daily":
			return "Cadence: repeatable daily"
		"repeatable_weekly":
			return "Cadence: repeatable weekly"
		"cooldown_days":
			return "Cadence: cooldown days"
		"conditional":
			return "Cadence: conditional"
		"none":
			return "Cadence: none"
		_:
			return "Cadence: %s" % _humanize_id(cadence) if cadence != "" else ""

static func _resource_site_role_tag_summary(site: Dictionary, map_object: Dictionary) -> String:
	var roles: Array[String] = _string_array(map_object.get("secondary_tags", []))
	if roles.is_empty():
		roles = _string_array(map_object.get("map_roles", []))
	if roles.is_empty():
		roles = _fallback_resource_site_roles(site)
	var visible := []
	for role in roles:
		var label := _humanize_id(role)
		if label != "" and label not in visible:
			visible.append(label)
		if visible.size() >= 3:
			break
	return "Roles: %s" % ", ".join(visible) if not visible.is_empty() else ""

static func _fallback_resource_site_roles(site: Dictionary) -> Array[String]:
	match String(site.get("family", "")):
		"mine":
			return ["income"]
		"neutral_dwelling":
			return ["recruit source", "weekly muster"]
		"faction_outpost":
			return ["frontier watch", "route support"]
		"frontier_shrine":
			return ["spell route", "recovery"]
		"transit_object":
			return ["route link"]
		"repeatable_service":
			return ["service"]
		_:
			return ["route pacing"]

static func _encounter_object_tag_summary(encounter: Dictionary, map_object: Dictionary) -> String:
	var tags := _string_array(map_object.get("secondary_tags", []))
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if tags.is_empty() and neutral_metadata is Dictionary:
		tags = _string_array(neutral_metadata.get("secondary_tags", []))
	var visible := []
	for tag in tags:
		var label := _humanize_id(tag)
		if label != "" and label not in visible:
			visible.append(label)
		if visible.size() >= 3:
			break
	return "Tags: %s" % ", ".join(visible) if not visible.is_empty() else ""

static func _encounter_object_interaction_label(encounter: Dictionary, map_object: Dictionary) -> String:
	var interaction = map_object.get("interaction", {})
	if interaction is Dictionary:
		var cadence := String(interaction.get("cadence", "")).strip_edges()
		if cadence != "":
			return _interaction_cadence_label(cadence)
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if neutral_metadata is Dictionary:
		var passability = neutral_metadata.get("passability", {})
		if passability is Dictionary:
			var mode := String(passability.get("interaction_mode", "")).strip_edges()
			if mode != "":
				return "Interaction: %s" % _humanize_id(mode)
	return "Interaction: enter battle"

static func _encounter_guard_link(encounter: Dictionary) -> Dictionary:
	var guard = encounter.get("guard_link", {})
	if guard is Dictionary and not guard.is_empty():
		return guard
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if neutral_metadata is Dictionary:
		guard = neutral_metadata.get("guard_link", {})
		if guard is Dictionary:
			return guard
	return {}

static func _encounter_guard_summary(encounter: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	var guard := _encounter_guard_link(encounter)
	var role := String(guard.get("guard_role", "")).strip_edges()
	if role == "" or role == "none":
		return ""
	var target_label := _encounter_guard_target_label(session, guard)
	if target_label != "":
		return "Guard: %s for %s" % [_humanize_id(role), target_label]
	return "Guard: %s" % _humanize_id(role)

static func _encounter_role_label(encounter: Dictionary) -> String:
	var metadata := _encounter_neutral_metadata(encounter)
	var representation = metadata.get("representation", {})
	if representation is Dictionary:
		var mode := String(representation.get("mode", "")).strip_edges()
		if mode != "":
			return _humanize_id(mode)
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	var subtype := String(map_object.get("subtype", "")).strip_edges()
	if subtype != "":
		return _humanize_id(subtype)
	var tags := _encounter_tags(encounter, map_object)
	if "route_block" in tags:
		return "Route Block"
	if "guarded_reward" in tags:
		return "Guarded Reward"
	if "visible_army" in tags:
		return "Visible Stack"
	return "Hostile Contact"

static func _encounter_readiness_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	compact: bool = false
) -> String:
	if session == null:
		return ""
	var enemy_totals := _army_totals(_encounter_army_payload(encounter))
	var hero_value: Variant = session.overworld.get("hero", {})
	if not (hero_value is Dictionary):
		return ""
	var hero: Dictionary = hero_value
	var player_army_value: Variant = hero.get("army", session.overworld.get("army", {}))
	if not (player_army_value is Dictionary):
		return ""
	var player_army: Dictionary = player_army_value
	var player_totals := _army_totals(player_army)
	var player_headcount := int(player_totals.get("headcount", 0))
	var enemy_headcount := int(enemy_totals.get("headcount", 0))
	if player_headcount <= 0 or enemy_headcount <= 0:
		return ""
	var relation := "even contact"
	if enemy_headcount >= player_headcount * 2:
		relation = "enemy outnumbers"
	elif player_headcount >= enemy_headcount * 2:
		relation = "you outnumber"
	elif enemy_headcount > player_headcount:
		relation = "enemy larger"
	elif player_headcount > enemy_headcount:
		relation = "you larger"
	if compact:
		return "Ready %d vs %d troops; %s" % [player_headcount, enemy_headcount, relation]
	return "Readiness: your army %d troops/%d groups vs enemy %d troops/%d groups; %s." % [
		player_headcount,
		int(player_totals.get("groups", 0)),
		enemy_headcount,
		int(enemy_totals.get("groups", 0)),
		relation,
	]

static func _encounter_guard_consequence_line(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	compact: bool = false
) -> String:
	var guard := _encounter_guard_link(encounter)
	if guard.is_empty():
		return ""
	var role := String(guard.get("guard_role", "")).strip_edges()
	if role == "" or role == "none":
		return ""
	var target_label := _encounter_guard_target_label(session, guard)
	var target_kind := String(guard.get("target_kind", "")).strip_edges()
	if target_kind == "route":
		var route_label := target_label if target_label != "" else "this route"
		return "Clear: opens %s route" % route_label if compact else "Clear: opens the %s route for safer movement." % route_label
	if target_kind == "resource_node":
		if target_label == "":
			target_label = "linked site"
		var value_line := ""
		if session != null:
			var node_result := _find_resource_node_by_guard(guard, session)
			var node: Dictionary = node_result.get("node", {})
			if not node.is_empty():
				var site := ContentService.get_resource_site(String(node.get("site_id", "")))
				value_line = _resource_site_yield_line(session, node, site)
		if value_line != "":
			return "Clear: access %s (%s)" % [target_label, value_line]
		return "Clear: access %s" % target_label
	if target_label != "":
		var verb := "access" if bool(guard.get("clear_required_for_target", false)) else "reach"
		return "Clear: %s %s" % [verb, target_label]
	return ""

static func _find_resource_node_by_guard(guard: Dictionary, session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {"index": -1, "node": {}}
	var target_placement_id := String(guard.get("target_placement_id", "")).strip_edges()
	if target_placement_id != "":
		return _find_resource_node_by_placement(session, target_placement_id)
	var target_id := String(guard.get("target_id", "")).strip_edges()
	if target_id == "":
		return {"index": -1, "node": {}}
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) == target_id or String(node.get("site_id", "")) == target_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _encounter_objective_consequence_line(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var objectives := _encounter_clear_objectives(session, encounter)
	if objectives.is_empty():
		return ""
	var labels := []
	for objective in objectives:
		if not (objective is Dictionary):
			continue
		var label := String(objective.get("label", "")).strip_edges()
		if label == "" and session != null:
			label = _scenario_objective_player_label(session, objective)
		if label != "":
			labels.append(label)
		if labels.size() >= 2:
			break
	if labels.is_empty():
		return ""
	return "Clear: advances %s" % "; ".join(labels)

static func _encounter_hook_consequence_line(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return ""
	var objective_ids := _encounter_clear_objective_ids(session, encounter)
	var scenario := ContentService.get_scenario(session.scenario_id)
	var summaries := []
	for hook in scenario.get("script_hooks", []):
		if not (hook is Dictionary):
			continue
		if not _hook_follows_encounter_clear(hook, encounter, objective_ids):
			continue
		var effect_summary := _script_hook_effect_consequence_summary(hook.get("effects", []))
		if effect_summary != "":
			summaries.append(effect_summary)
		if summaries.size() >= 2:
			break
	if summaries.is_empty():
		return ""
	return "After clear: %s" % "; ".join(summaries)

static func _encounter_clear_objectives(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> Array:
	var objectives := []
	if session == null or session.scenario_id == "":
		return objectives
	var placement_id := encounter_key(encounter)
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var victory_flags: Array[String] = _string_array(encounter_def.get("victory_flags", []))
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objective_bucket = scenario.get("objectives", {})
	if not (objective_bucket is Dictionary):
		return objectives
	for bucket_name in ["victory", "defeat"]:
		for objective in objective_bucket.get(bucket_name, []):
			if not (objective is Dictionary):
				continue
			var objective_type := String(objective.get("type", ""))
			var linked := (
				objective_type == "encounter_resolved"
				and String(objective.get("placement_id", "")) == placement_id
			)
			linked = linked or (
				objective_type == "flag_true"
				and String(objective.get("flag", "")) in victory_flags
			)
			if linked:
				objectives.append(objective)
	return objectives

static func _encounter_clear_objective_ids(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> Array[String]:
	var ids: Array[String] = []
	for objective in _encounter_clear_objectives(session, encounter):
		if not (objective is Dictionary):
			continue
		var objective_id := String(objective.get("id", "")).strip_edges()
		if objective_id != "" and objective_id not in ids:
			ids.append(objective_id)
	return ids

static func _hook_follows_encounter_clear(
	hook: Dictionary,
	encounter: Dictionary,
	objective_ids: Array[String]
) -> bool:
	var placement_id := encounter_key(encounter)
	for condition in hook.get("conditions", []):
		if not (condition is Dictionary):
			continue
		match String(condition.get("type", "")):
			"encounter_resolved":
				if String(condition.get("placement_id", "")) == placement_id:
					return true
			"objective_met":
				if String(condition.get("objective_id", "")) in objective_ids:
					return true
	return false

static func _script_hook_effect_consequence_summary(effects: Variant) -> String:
	if not (effects is Array):
		return ""
	var parts := []
	var fallback_message := ""
	for effect in effects:
		if not (effect is Dictionary):
			continue
		match String(effect.get("type", "")):
			"spawn_resource_node":
				var resource_placement = effect.get("placement", {})
				if resource_placement is Dictionary:
					var site := ContentService.get_resource_site(String(resource_placement.get("site_id", "")))
					parts.append("reveals %s" % String(site.get("name", "supplies")))
			"spawn_artifact_node":
				var artifact_placement = effect.get("placement", {})
				if artifact_placement is Dictionary:
					parts.append("reveals %s" % ArtifactRulesScript.artifact_name(String(artifact_placement.get("artifact_id", ""))))
			"award_experience":
				var amount := int(effect.get("amount", 0))
				if amount > 0:
					parts.append("+%d xp" % amount)
			"add_resources":
				var resources := _describe_reward_delta(effect.get("resources", {}))
				if resources != "":
					parts.append("+%s" % resources)
			"town_add_recruits":
				parts.append("reinforces a town")
			"town_add_building":
				var building := ContentService.get_building(String(effect.get("building_id", "")))
				parts.append("unlocks %s" % String(building.get("name", "town support")))
			"spawn_encounter":
				parts.append("may draw a counterforce")
			"message":
				if fallback_message == "":
					fallback_message = _short_player_text(String(effect.get("text", "")), 96)
		if parts.size() >= 2:
			break
	if parts.is_empty() and fallback_message != "":
		parts.append(fallback_message)
	return ", ".join(_non_empty_strings(parts))

static func _encounter_risk_label(encounter: Dictionary) -> String:
	var metadata := _encounter_neutral_metadata(encounter)
	var reward_guard = metadata.get("reward_guard_summary", {})
	if reward_guard is Dictionary:
		var risk := String(reward_guard.get("risk_tier", "")).strip_edges()
		if risk != "":
			return "Risk %s" % _humanize_id(risk)
	var difficulty := String(encounter.get("difficulty", "")).strip_edges()
	match difficulty:
		"low":
			return "Risk Light"
		"medium", "normal":
			return "Risk Standard"
		"high":
			return "Risk Heavy"
		"scripted":
			return "Risk Scripted"
		_:
			return ""

static func _encounter_difficulty_label(encounter: Dictionary) -> String:
	var difficulty := String(encounter.get("difficulty", "")).strip_edges()
	if difficulty == "":
		var encounter_ref = encounter.get("encounter_ref", {})
		if encounter_ref is Dictionary:
			difficulty = String(encounter_ref.get("difficulty", "")).strip_edges()
	if difficulty == "":
		return ""
	return "Difficulty %s" % _humanize_id(difficulty)

static func _encounter_army_surface(encounter: Dictionary, include_units: bool) -> String:
	var army := _encounter_army_payload(encounter)
	if army.is_empty():
		return ""
	var totals := _army_totals(army)
	var parts := []
	var army_name := String(army.get("name", "")).strip_edges()
	if army_name != "":
		parts.append(army_name)
	parts.append("%d troops/%d groups" % [int(totals.get("headcount", 0)), int(totals.get("groups", 0))])
	if include_units:
		var unit_summary := _encounter_army_unit_summary(army)
		if unit_summary != "":
			parts.append(unit_summary)
	return " | ".join(_non_empty_strings(parts))

static func _encounter_army_payload(encounter: Dictionary) -> Dictionary:
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var army := ContentService.get_army_group(String(encounter_def.get("enemy_group_id", "")))
	var placement_army = encounter.get("enemy_army", {})
	var placement_stacks = placement_army.get("stacks", []) if placement_army is Dictionary else []
	if placement_army is Dictionary and placement_stacks is Array and not placement_stacks.is_empty():
		army = placement_army
	return army if army is Dictionary else {}

static func _encounter_army_unit_summary(army: Dictionary) -> String:
	var labels := []
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		var unit_id := String(stack.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id)
		labels.append("%s x%d" % [String(unit.get("name", unit_id)), count])
		if labels.size() >= 3:
			break
	var total_groups := int(_army_totals(army).get("groups", 0))
	if total_groups > labels.size():
		labels.append("+%d group%s" % [total_groups - labels.size(), "" if total_groups - labels.size() == 1 else "s"])
	return ", ".join(labels)

static func _encounter_reward_surface(encounter: Dictionary) -> String:
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var reward_summary := _describe_reward_delta(encounter_def.get("rewards", {}))
	if reward_summary != "":
		return reward_summary
	var metadata := _encounter_neutral_metadata(encounter)
	var reward_guard = metadata.get("reward_guard_summary", {})
	if reward_guard is Dictionary:
		var categories := []
		for category in _string_array(reward_guard.get("reward_categories", [])):
			categories.append(_humanize_id(category))
		if not categories.is_empty():
			return "Categories %s" % ", ".join(categories)
	return ""

static func _encounter_field_objective_surface(encounter: Dictionary) -> String:
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var labels := []
	for objective in encounter_def.get("field_objectives", []):
		if not (objective is Dictionary):
			continue
		var label := String(objective.get("label", "")).strip_edges()
		if label != "":
			labels.append(label)
		if labels.size() >= 2:
			break
	return ", ".join(labels)

static func _encounter_guard_target_label(session: SessionStateStoreScript.SessionData, guard: Dictionary) -> String:
	var target_kind := String(guard.get("target_kind", "")).strip_edges()
	var target_placement_id := String(guard.get("target_placement_id", "")).strip_edges()
	var target_id := String(guard.get("target_id", "")).strip_edges()
	if target_kind == "resource_node":
		if session != null and target_placement_id != "":
			var node_result := _find_resource_node_by_placement(session, target_placement_id)
			var node: Dictionary = node_result.get("node", {})
			if not node.is_empty():
				var site := ContentService.get_resource_site(String(node.get("site_id", "")))
				return String(site.get("name", target_placement_id))
		if target_id != "":
			var site_by_id := ContentService.get_resource_site(target_id)
			if not site_by_id.is_empty():
				return String(site_by_id.get("name", target_id))
	if target_kind == "artifact_node":
		return _humanize_id(target_placement_id if target_placement_id != "" else target_id)
	if target_kind == "town":
		if session != null and target_placement_id != "":
			var town_result := _find_town_by_placement(session, target_placement_id)
			var town: Dictionary = town_result.get("town", {})
			if not town.is_empty():
				return _town_name(town)
		return _humanize_id(target_placement_id if target_placement_id != "" else target_id)
	if target_kind == "route":
		return _humanize_id(target_id if target_id != "" else target_placement_id)
	if target_placement_id != "":
		return _humanize_id(target_placement_id)
	if target_id != "":
		return _humanize_id(target_id)
	return ""

static func _encounter_neutral_metadata(encounter: Dictionary) -> Dictionary:
	var metadata = encounter.get("neutral_encounter", {})
	if metadata is Dictionary and not metadata.is_empty():
		return metadata
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	metadata = map_object.get("neutral_encounter", {})
	return metadata if metadata is Dictionary else {}

static func _encounter_tags(encounter: Dictionary, map_object: Dictionary) -> Array[String]:
	var tags := _string_array(map_object.get("secondary_tags", []))
	var metadata := _encounter_neutral_metadata(encounter)
	if tags.is_empty():
		tags = _string_array(metadata.get("secondary_tags", []))
	return tags

static func _controller_display_name(controller_id: String) -> String:
	if controller_id == "enemy":
		return "enemy"
	var faction := ContentService.get_faction(controller_id)
	if not faction.is_empty():
		return String(faction.get("name", controller_id))
	return controller_id

static func _string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in strings:
				strings.append(text)
	return strings

static func _non_empty_strings(value: Array) -> Array[String]:
	var strings: Array[String] = []
	for item in value:
		var text := String(item).strip_edges()
		if text != "":
			strings.append(text)
	return strings

static func _humanize_id(value: String) -> String:
	var normalized := value.strip_edges().replace("_", " ").replace("-", " ")
	if normalized == "":
		return ""
	var words := []
	for word_value in normalized.split(" ", false):
		var word := String(word_value).strip_edges()
		if word == "":
			continue
		words.append(word.left(1).to_upper() + word.substr(1).to_lower())
	return " ".join(words)

static func _resource_site_response_profile(site: Dictionary) -> Dictionary:
	var profile := {
		"action_label": "",
		"summary": "",
		"movement_cost": 0,
		"resource_cost": {"gold": 0, "wood": 0, "ore": 0},
		"watch_days": 0,
		"quality_bonus": 0,
		"readiness_bonus": 0,
		"pressure_bonus": 0,
		"recovery_relief": 0,
		"pressure_guard_bonus": 0,
		"growth_bonus_percent": 0,
		"break_pressure": 0,
	}
	var authored_profile = site.get("response_profile", {})
	if authored_profile is Dictionary:
		profile["action_label"] = String(authored_profile.get("action_label", ""))
		profile["summary"] = String(authored_profile.get("summary", ""))
		profile["movement_cost"] = max(0, int(authored_profile.get("movement_cost", 0)))
		profile["resource_cost"] = _normalize_resource_dict(authored_profile.get("resource_cost", {}))
		profile["watch_days"] = max(0, int(authored_profile.get("watch_days", 0)))
		profile["quality_bonus"] = max(0, int(authored_profile.get("quality_bonus", 0)))
		profile["readiness_bonus"] = max(0, int(authored_profile.get("readiness_bonus", 0)))
		profile["pressure_bonus"] = max(0, int(authored_profile.get("pressure_bonus", 0)))
		profile["recovery_relief"] = max(0, int(authored_profile.get("recovery_relief", 0)))
		profile["pressure_guard_bonus"] = max(0, int(authored_profile.get("pressure_guard_bonus", 0)))
		profile["growth_bonus_percent"] = max(0, int(authored_profile.get("growth_bonus_percent", 0)))
		profile["break_pressure"] = max(0, int(authored_profile.get("break_pressure", 0)))
	if String(profile.get("action_label", "")) == "":
		match String(site.get("family", "")):
			"mine":
				profile["action_label"] = "Secure Work Road"
			"neutral_dwelling":
				profile["action_label"] = "Dispatch Relief"
			"faction_outpost":
				profile["action_label"] = "Repair Outpost"
			"frontier_shrine":
				profile["action_label"] = "Relight Shrine"
			"scouting_structure":
				profile["action_label"] = "Staff Watch"
			"transit_object":
				profile["action_label"] = "Repair Route"
			_:
				profile["action_label"] = "Secure Route"
	if int(profile.get("pressure_guard_bonus", 0)) <= 0:
		match String(site.get("family", "")):
			"mine":
				profile["pressure_guard_bonus"] = 1
			"neutral_dwelling":
				profile["pressure_guard_bonus"] = 1
			"faction_outpost":
				profile["pressure_guard_bonus"] = 2
			"frontier_shrine":
				profile["pressure_guard_bonus"] = 1
			"scouting_structure":
				profile["pressure_guard_bonus"] = 2
			"transit_object":
				profile["pressure_guard_bonus"] = 1
	if int(profile.get("growth_bonus_percent", 0)) <= 0:
		match String(site.get("family", "")):
			"mine":
				profile["growth_bonus_percent"] = 3
			"neutral_dwelling":
				profile["growth_bonus_percent"] = 14
			"faction_outpost":
				profile["growth_bonus_percent"] = 4
			"frontier_shrine":
				profile["growth_bonus_percent"] = 6
			"scouting_structure":
				profile["growth_bonus_percent"] = 3
			"transit_object":
				profile["growth_bonus_percent"] = 3
	if int(profile.get("break_pressure", 0)) <= 0:
		match String(site.get("family", "")):
			"mine":
				profile["break_pressure"] = 1
			"neutral_dwelling":
				profile["break_pressure"] = 1
			"faction_outpost":
				profile["break_pressure"] = 2
			"frontier_shrine":
				profile["break_pressure"] = 1
			"scouting_structure":
				profile["break_pressure"] = 2
			"transit_object":
				profile["break_pressure"] = 1
	return profile

static func _route_security_rating_for_hero(hero: Dictionary) -> int:
	if hero.is_empty():
		return 1
	var command = hero.get("command", {})
	var command_total := (
		int(command.get("attack", 0))
		+ int(command.get("defense", 0))
		+ int(command.get("power", 0))
		+ int(command.get("knowledge", 0))
	)
	var level_bonus = max(0, int(hero.get("level", 1)) - 1)
	return clamp(1 + int(floor(float(command_total + level_bonus) / 4.0)), 1, 5)

static func _resource_site_response_state(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	var profile := _resource_site_response_profile(site)
	var active := false
	var remaining_days := 0
	var commander_id := String(node.get("response_commander_id", ""))
	var commander_name := ""
	var security_rating = max(0, int(node.get("response_security_rating", 0)))
	if session != null and String(node.get("collected_by_faction_id", "")) == "player":
		var response_until_day = max(0, int(node.get("response_until_day", 0)))
		active = response_until_day >= session.day and int(profile.get("watch_days", 0)) > 0
		if active:
			remaining_days = max(1, response_until_day - session.day + 1)
		if commander_id != "":
			commander_name = String(HeroCommandRulesScript.hero_by_id(session, commander_id).get("name", ""))
		if security_rating <= 0:
			var preview_hero := HeroCommandRulesScript.active_hero(session)
			security_rating = _route_security_rating_for_hero(preview_hero)
			if commander_name == "":
				commander_name = String(preview_hero.get("name", ""))
	if active and security_rating <= 0:
		security_rating = 1
	var pressure_guard_bonus = max(0, int(profile.get("pressure_guard_bonus", 0))) + max(0, security_rating - 1)
	var growth_bonus_percent = max(0, int(profile.get("growth_bonus_percent", 0)))
	if growth_bonus_percent > 0:
		growth_bonus_percent += max(0, security_rating - 1) * 3
	var break_pressure = max(0, int(profile.get("break_pressure", 0))) + max(0, security_rating - 1)
	return {
		"active": active,
		"remaining_days": remaining_days,
		"origin": String(node.get("response_origin", "")),
		"source_town_id": String(node.get("response_source_town_id", "")),
		"commander_id": commander_id,
		"commander_name": commander_name,
		"security_rating": security_rating,
		"action_label": String(profile.get("action_label", "")),
		"summary": String(profile.get("summary", "")),
		"movement_cost": int(profile.get("movement_cost", 0)),
		"resource_cost": profile.get("resource_cost", {"gold": 0, "wood": 0, "ore": 0}),
		"watch_days": int(profile.get("watch_days", 0)),
		"quality_bonus": int(profile.get("quality_bonus", 0)),
		"readiness_bonus": int(profile.get("readiness_bonus", 0)),
		"pressure_bonus": int(profile.get("pressure_bonus", 0)),
		"recovery_relief": int(profile.get("recovery_relief", 0)),
		"pressure_guard_bonus": pressure_guard_bonus,
		"growth_bonus_percent": growth_bonus_percent,
		"break_pressure": break_pressure,
	}

static func _resource_site_response_effect_summary(response_state: Dictionary) -> String:
	var parts := []
	if int(response_state.get("quality_bonus", 0)) > 0:
		parts.append("quality +%d" % int(response_state.get("quality_bonus", 0)))
	if int(response_state.get("readiness_bonus", 0)) > 0:
		parts.append("readiness +%d" % int(response_state.get("readiness_bonus", 0)))
	if int(response_state.get("pressure_bonus", 0)) > 0:
		parts.append("pressure +%d" % int(response_state.get("pressure_bonus", 0)))
	if int(response_state.get("recovery_relief", 0)) > 0:
		parts.append("recovery -%d" % int(response_state.get("recovery_relief", 0)))
	if int(response_state.get("growth_bonus_percent", 0)) > 0:
		parts.append("musters +%d%%" % int(response_state.get("growth_bonus_percent", 0)))
	if int(response_state.get("pressure_guard_bonus", 0)) > 0:
		parts.append("pressure guard +%d" % int(response_state.get("pressure_guard_bonus", 0)))
	return ", ".join(parts)

static func _resource_site_delivery_target_label(
	session: SessionStateStoreScript.SessionData,
	target_kind: String,
	target_id: String,
	fallback_label: String = ""
) -> String:
	if session != null:
		match target_kind:
			"hero":
				var hero := HeroCommandRulesScript.hero_by_id(session, target_id)
				if not hero.is_empty():
					return String(hero.get("name", target_id))
			"town":
				var town_result := _find_town_by_placement(session, target_id)
				if int(town_result.get("index", -1)) >= 0:
					return _town_name(town_result.get("town", {}))
			"raid":
				var encounter_result = _find_encounter_by_placement(session, target_id)
				if int(encounter_result.get("index", -1)) >= 0:
					var encounter: Dictionary = encounter_result.get("encounter", {})
					return String(encounter.get("target_label", encounter.get("placement_id", target_id)))
	if fallback_label != "":
		return fallback_label
	match target_kind:
		"hero":
			return "frontline hero"
		"town":
			return "frontline town"
		"raid":
			return "raid host"
		_:
			return "frontline"

static func _resource_site_delivery_state(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	_site: Dictionary = {}
) -> Dictionary:
	var manifest = _normalize_recruit_payload(node.get("delivery_manifest", {}))
	var controller_id = String(node.get("delivery_controller_id", ""))
	var arrival_day = max(0, int(node.get("delivery_arrival_day", 0)))
	var target_kind = String(node.get("delivery_target_kind", ""))
	var target_id = String(node.get("delivery_target_id", ""))
	var target_label = _resource_site_delivery_target_label(
		session,
		target_kind,
		target_id,
		String(node.get("delivery_target_label", ""))
	)
	var source_town_id = String(node.get("delivery_origin_town_id", ""))
	var source_town_label := ""
	if session != null and source_town_id != "":
		var source_town_result = _find_town_by_placement(session, source_town_id)
		if int(source_town_result.get("index", -1)) >= 0:
			source_town_label = _town_name(source_town_result.get("town", {}))
	var active := false
	var days_remaining := 0
	if session != null and controller_id != "" and not manifest.is_empty() and arrival_day > 0:
		active = String(node.get("collected_by_faction_id", "")) == controller_id
		if active:
			days_remaining = max(0, arrival_day - session.day)
			if days_remaining > 0:
				days_remaining = max(1, days_remaining)
	return {
		"active": active,
		"controller_id": controller_id,
		"origin_town_id": source_town_id,
		"origin_town_label": source_town_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"arrival_day": arrival_day,
		"days_remaining": days_remaining,
		"manifest": manifest,
		"recruit_summary": _describe_recruit_delta(manifest),
		"manifest_value": _weighted_recruit_value(manifest),
	}

static func _delivery_encounter_matches_node(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	node: Dictionary,
	delivery_state: Dictionary
) -> bool:
	if session == null or encounter.is_empty() or node.is_empty() or delivery_state.is_empty():
		return false
	var explicit_node_id := String(encounter.get("delivery_intercept_node_placement_id", ""))
	if explicit_node_id != "" and explicit_node_id == String(node.get("placement_id", "")):
		return true
	match String(encounter.get("target_kind", "")):
		"resource":
			return String(encounter.get("target_placement_id", "")) == String(node.get("placement_id", ""))
		"town":
			return (
				String(delivery_state.get("target_kind", "")) == "town"
				and String(encounter.get("target_placement_id", "")) == String(delivery_state.get("target_id", ""))
			)
		"hero":
			if String(delivery_state.get("target_kind", "")) != "hero":
				return false
			var hero_target_id := String(encounter.get("target_placement_id", ""))
			if hero_target_id == "":
				hero_target_id = String(session.overworld.get("active_hero_id", ""))
			return hero_target_id != "" and hero_target_id == String(delivery_state.get("target_id", ""))
		_:
			return false

static func _resource_site_delivery_interception(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary = {}
) -> Dictionary:
	var empty_state := {
		"active": false,
		"arrived": false,
		"blocks_delivery": false,
		"goal_distance": 9999,
		"strength": 0,
		"encounter_key": "",
		"encounter_name": "",
		"summary": "",
	}
	if session == null or node.is_empty():
		return empty_state
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
		return empty_state
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var best := empty_state.duplicate(true)
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == "":
			continue
		if resolved_encounters is Array and encounter_key(encounter) in resolved_encounters:
			continue
		if not _delivery_encounter_matches_node(session, encounter, node, delivery_state):
			continue
		var goal_distance: int = max(0, int(encounter.get("goal_distance", 9999)))
		var arrived: bool = bool(encounter.get("arrived", false)) or goal_distance <= 0
		var strength: int = int(_enemy_adventure_rules().raid_strength(encounter))
		if bool(best.get("active", false)):
			var best_arrived := bool(best.get("arrived", false))
			var best_distance := int(best.get("goal_distance", 9999))
			var best_strength := int(best.get("strength", 0))
			if arrived == best_arrived:
				if goal_distance == best_distance and strength <= best_strength:
					continue
				if goal_distance > best_distance:
					continue
			elif not arrived:
				continue
		best = {
			"active": true,
			"arrived": arrived,
			"blocks_delivery": arrived,
			"goal_distance": goal_distance,
			"strength": strength,
			"encounter_key": encounter_key(encounter),
			"encounter_name": encounter_display_name(encounter),
			"summary": "",
		}
	var encounter_name := String(best.get("encounter_name", "Raid host"))
	var target_label := String(delivery_state.get("target_label", "the front"))
	if bool(best.get("active", false)):
		if bool(best.get("blocks_delivery", false)):
			best["summary"] = "%s is contesting %s." % [encounter_name, target_label]
		else:
			best["summary"] = "%s closes on %s in %d tile%s." % [
				encounter_name,
				target_label,
				int(best.get("goal_distance", 0)),
				"" if int(best.get("goal_distance", 0)) == 1 else "s",
			]
	return best

static func delivery_interception_context_for_encounter(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> Dictionary:
	var empty_context := {
		"active": false,
		"node_placement_id": "",
		"site_name": "",
		"origin_town_id": "",
		"origin_town_label": "",
		"target_kind": "",
		"target_id": "",
		"target_label": "",
		"route_label": "",
		"pressure_label": "",
		"arrival_day": 0,
		"recruit_summary": "",
		"manifest": {},
		"manifest_value": 0,
		"interception": {
			"active": false,
			"arrived": false,
			"blocks_delivery": false,
			"goal_distance": 9999,
			"strength": 0,
			"encounter_key": "",
			"encounter_name": "",
			"summary": "",
		},
	}
	if session == null or encounter.is_empty():
		return empty_context
	var explicit_node_id := String(encounter.get("delivery_intercept_node_placement_id", ""))
	var nodes = session.overworld.get("resource_nodes", [])
	var best := empty_context.duplicate(true)
	for node_value in nodes:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if explicit_node_id != "" and String(node.get("placement_id", "")) != explicit_node_id:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		if not _delivery_encounter_matches_node(session, encounter, node, delivery_state):
			continue
		var target_label := String(delivery_state.get("target_label", "the front"))
		var site_name := String(site.get("name", "Frontier route"))
		var route_label := "%s convoy to %s" % [site_name, target_label]
		var pressure_label := route_label
		match String(delivery_state.get("target_kind", "")):
			"town":
				pressure_label = "%s relief lane" % target_label
			"hero":
				pressure_label = "%s convoy" % target_label
		var candidate := {
			"active": true,
			"node_placement_id": String(node.get("placement_id", "")),
			"site_name": site_name,
			"origin_town_id": String(delivery_state.get("origin_town_id", "")),
			"origin_town_label": String(delivery_state.get("origin_town_label", "")),
			"target_kind": String(delivery_state.get("target_kind", "")),
			"target_id": String(delivery_state.get("target_id", "")),
			"target_label": target_label,
			"route_label": route_label,
			"pressure_label": pressure_label,
			"arrival_day": int(delivery_state.get("arrival_day", 0)),
			"recruit_summary": String(delivery_state.get("recruit_summary", "")),
			"manifest": _normalize_recruit_payload(delivery_state.get("manifest", {})),
			"manifest_value": int(delivery_state.get("manifest_value", 0)),
			"interception": _resource_site_delivery_interception(session, node, site),
		}
		if not bool(best.get("active", false)):
			best = candidate
			if explicit_node_id != "":
				break
			continue
		if int(candidate.get("manifest_value", 0)) > int(best.get("manifest_value", 0)):
			best = candidate
			continue
		if int(candidate.get("manifest_value", 0)) == int(best.get("manifest_value", 0)) and int(candidate.get("arrival_day", 0)) < int(best.get("arrival_day", 0)):
			best = candidate
	if explicit_node_id != "" and not bool(best.get("active", false)):
		return empty_context
	return best

static func _resource_site_delivery_line(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var delivery_state = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)):
		return ""
	var parts := [
		"%s convoy" % String(site.get("name", "Frontier route")),
		"to %s" % String(delivery_state.get("target_label", "the front")),
	]
	var recruit_summary = String(delivery_state.get("recruit_summary", ""))
	if recruit_summary != "":
		parts.append(recruit_summary)
	var days_remaining := int(delivery_state.get("days_remaining", 0))
	if days_remaining > 0:
		parts.append("%d day%s out" % [days_remaining, "" if days_remaining == 1 else "s"])
	else:
		var interception_state: Dictionary = _resource_site_delivery_interception(session, node, site)
		if bool(interception_state.get("blocks_delivery", false)):
			parts.append("holding under interception")
	var interception: Dictionary = _resource_site_delivery_interception(session, node, site)
	if bool(interception.get("active", false)):
		if bool(interception.get("blocks_delivery", false)):
			parts.append("%s blocks the route" % String(interception.get("encounter_name", "Raid host")))
		else:
			parts.append("%s %d tile%s out" % [
				String(interception.get("encounter_name", "Raid host")),
				int(interception.get("goal_distance", 0)),
				"" if int(interception.get("goal_distance", 0)) == 1 else "s",
			])
	return " | ".join(parts)

static func _estimate_reserve_delivery_eta(
	origin: Vector2i,
	target: Vector2i,
	security_rating: int,
	max_days: int
) -> int:
	var distance = abs(origin.x - target.x) + abs(origin.y - target.y)
	var travel_speed = max(2, security_rating + 1)
	return clamp(int(ceili(float(max(distance, 1)) / float(travel_speed))), 1, max(1, max_days))

static func _player_reserve_delivery_plan(
	session: SessionStateStoreScript.SessionData,
	source_town: Dictionary,
	response_state: Dictionary
) -> Dictionary:
	if session == null or source_town.is_empty():
		return {}
	var available_recruits = _normalize_recruit_payload(source_town.get("available_recruits", {}))
	if available_recruits.is_empty():
		return {}
	var candidates = _player_reserve_delivery_candidates(session, source_town, response_state)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			var a_eta := int(a.get("eta_days", 999))
			var b_eta := int(b.get("eta_days", 999))
			if a_eta == b_eta:
				return String(a.get("label", "")) < String(b.get("label", ""))
			return a_eta < b_eta
		return a_priority > b_priority
	)
	var best_candidate: Dictionary = candidates[0]
	var manifest = _reserve_delivery_manifest_for_candidate(session, source_town, best_candidate, response_state)
	if manifest.is_empty():
		return {}
	return {
		"target_kind": String(best_candidate.get("target_kind", "")),
		"target_id": String(best_candidate.get("target_id", "")),
		"target_label": String(best_candidate.get("label", "")),
		"eta_days": int(best_candidate.get("eta_days", 1)),
		"manifest": manifest,
		"priority": int(best_candidate.get("priority", 0)),
	}

static func _player_reserve_delivery_candidates(
	session: SessionStateStoreScript.SessionData,
	source_town: Dictionary,
	response_state: Dictionary
) -> Array:
	var candidates = []
	if session == null or source_town.is_empty():
		return candidates
	var source_position = Vector2i(int(source_town.get("x", 0)), int(source_town.get("y", 0)))
	var support_radius = max(1, int(_town_logistics_plan(source_town).get("support_radius", 0)))
	var range_bonus = max(0, int(response_state.get("security_rating", 1)) - 1)
	var max_range = support_radius + range_bonus
	var source_placement_id = String(source_town.get("placement_id", ""))
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var placement_id = String(town.get("placement_id", ""))
		if placement_id == "" or placement_id == source_placement_id:
			continue
		var target_position = Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
		var distance = abs(source_position.x - target_position.x) + abs(source_position.y - target_position.y)
		var front = _town_front_state(session, town)
		var occupation = _town_occupation_state(session, town)
		var emergency_range_bonus := 0
		if bool(front.get("active", false)) and String(front.get("mode", "")) == "retake":
			emergency_range_bonus += 2
		if bool(occupation.get("active", false)):
			emergency_range_bonus += 2
		if distance > max_range + emergency_range_bonus:
			continue
		var threat_state = _town_command_risk_state(session, town)
		var recovery = _town_recovery_state(session, town)
		var logistics = _town_logistics_state(session, town)
		var capital_project = _town_capital_project_state(town, session)
		var priority = int(threat_state.get("visible_pressuring", 0)) * 52
		priority += int(threat_state.get("visible_marching", 0)) * 22
		if bool(threat_state.get("hidden_targeting", false)):
			priority += 10
		if bool(front.get("active", false)) and String(front.get("mode", "")) == "retake":
			priority += 26 + int(round(float(int(front.get("priority_bonus", 0))) / 8.0))
		if bool(occupation.get("active", false)):
			priority += 18 + int(occupation.get("pressure", 0)) * 12 + min(28, int(occupation.get("locked_headcount", 0)) * 2)
		priority += int(recovery.get("pressure", 0)) * 18
		priority += int(logistics.get("disrupted_count", 0)) * 18
		priority += int(logistics.get("threatened_count", 0)) * 10
		priority += int(logistics.get("support_gap", 0)) * 14
		match _town_strategic_role(town):
			"capital":
				priority += 24
			"stronghold":
				priority += 12
		if bool(capital_project.get("vulnerable", false)):
			priority += 18
		elif bool(capital_project.get("active", false)):
			priority += 8
		if priority <= 0:
			continue
		candidates.append(
			{
				"target_kind": "town",
				"target_id": placement_id,
				"label": _town_name(town),
				"priority": priority,
				"eta_days": _estimate_reserve_delivery_eta(
					source_position,
					target_position,
					int(response_state.get("security_rating", 1)),
					int(response_state.get("watch_days", 1))
				),
			}
		)
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var hero_id = String(hero.get("id", ""))
		if hero_id == "":
			continue
		var hero_position = Vector2i(int(hero.get("position", {}).get("x", 0)), int(hero.get("position", {}).get("y", 0)))
		if hero_position == source_position:
			continue
		var hero_distance = abs(source_position.x - hero_position.x) + abs(source_position.y - hero_position.y)
		if hero_distance > max_range:
			continue
		var hero_priority = _player_hero_delivery_priority(session, hero)
		if hero_priority <= 0:
			continue
		candidates.append(
			{
				"target_kind": "hero",
				"target_id": hero_id,
				"label": String(hero.get("name", "the hero")),
				"priority": hero_priority,
				"eta_days": _estimate_reserve_delivery_eta(
					source_position,
					hero_position,
					int(response_state.get("security_rating", 1)),
					int(response_state.get("watch_days", 1))
				),
			}
		)
	return candidates

static func _player_hero_delivery_priority(session: SessionStateStoreScript.SessionData, hero: Dictionary) -> int:
	if session == null or hero.is_empty():
		return 0
	var hero_position = Vector2i(int(hero.get("position", {}).get("x", 0)), int(hero.get("position", {}).get("y", 0)))
	var priority = 0
	var active_hero_id = String(session.overworld.get("active_hero_id", ""))
	if String(hero.get("id", "")) == active_hero_id:
		priority += 16
	if bool(hero.get("is_primary", false)):
		priority += 10
	var army_strength = _army_strength_value(hero.get("army", {}).get("stacks", []))
	if army_strength <= 90:
		priority += 28
	elif army_strength <= 140:
		priority += 18
	elif army_strength <= 200:
		priority += 8
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or is_encounter_resolved(session, encounter):
			continue
		var encounter_x := int(encounter.get("x", -1))
		var encounter_y := int(encounter.get("y", -1))
		if not is_tile_visible(session, encounter_x, encounter_y):
			continue
		var distance = abs(hero_position.x - encounter_x) + abs(hero_position.y - encounter_y)
		if distance <= 1:
			priority += 38
		elif distance <= 3:
			priority += 20
		if String(encounter.get("target_kind", "")) == "hero" and bool(encounter.get("arrived", false)):
			priority += 10
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if not is_tile_visible(session, int(town.get("x", -1)), int(town.get("y", -1))):
			continue
		var town_distance = abs(hero_position.x - int(town.get("x", 0))) + abs(hero_position.y - int(town.get("y", 0)))
		if town_distance <= 2:
			priority += 16
		elif town_distance <= 4:
			priority += 8
	return priority

static func _reserve_delivery_manifest_for_candidate(
	session: SessionStateStoreScript.SessionData,
	source_town: Dictionary,
	candidate: Dictionary,
	response_state: Dictionary
) -> Dictionary:
	var recruits = _normalize_recruit_payload(source_town.get("available_recruits", {}))
	if recruits.is_empty():
		return {}
	var capacity = 10 + (max(1, int(response_state.get("security_rating", 1))) * 6)
	capacity += int(response_state.get("quality_bonus", 0)) * 2
	capacity += int(response_state.get("readiness_bonus", 0)) * 2
	if String(candidate.get("target_kind", "")) == "town":
		capacity += 6
	if int(candidate.get("priority", 0)) >= 70:
		capacity += 8
	elif int(candidate.get("priority", 0)) >= 40:
		capacity += 4
	var hold_back := _town_should_hold_back_reserves(session, source_town)
	var unit_ids = []
	for unit_id_value in recruits.keys():
		var unit_id := String(unit_id_value)
		var available := int(recruits.get(unit_id_value, 0))
		var keep_count := 1 if hold_back and available > 2 else 0
		if max(0, available - keep_count) <= 0:
			continue
		unit_ids.append(unit_id)
	unit_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_priority := _reserve_delivery_unit_priority(a, String(candidate.get("target_kind", "")))
		var b_priority := _reserve_delivery_unit_priority(b, String(candidate.get("target_kind", "")))
		if a_priority == b_priority:
			return a < b
		return a_priority > b_priority
	)
	var manifest = {}
	var remaining_capacity = max(1, capacity)
	for unit_id in unit_ids:
		var available_count = int(recruits.get(unit_id, 0))
		var keep_count = 1 if hold_back and available_count > 2 else 0
		var sendable = max(0, available_count - keep_count)
		if sendable <= 0:
			continue
		var unit_value = _reserve_delivery_unit_value(unit_id)
		var max_by_capacity = max(1, int(floor(float(max(remaining_capacity, unit_value)) / float(unit_value))))
		var send_count = min(sendable, max_by_capacity)
		if send_count <= 0:
			continue
		manifest[unit_id] = send_count
		remaining_capacity -= send_count * unit_value
		if remaining_capacity <= 0:
			break
	if manifest.is_empty() and not unit_ids.is_empty():
		manifest[unit_ids[0]] = 1
	return manifest

static func _reserve_delivery_unit_priority(unit_id: String, target_kind: String) -> int:
	var unit = ContentService.get_unit(unit_id)
	var priority = (max(1, int(unit.get("tier", 1))) * 10)
	priority += int(unit.get("attack", 0)) + int(unit.get("defense", 0))
	if bool(unit.get("ranged", false)):
		priority += 6 if target_kind == "town" else 3
	return priority

static func _reserve_delivery_unit_value(unit_id: String) -> int:
	return max(1, _weighted_recruit_value({unit_id: 1}))

static func _town_should_hold_back_reserves(session: SessionStateStoreScript.SessionData, town: Dictionary) -> bool:
	if session == null or town.is_empty():
		return false
	var recovery := _town_recovery_state(session, town)
	var threat_state := _town_command_risk_state(session, town)
	if bool(recovery.get("active", false)):
		return true
	if int(threat_state.get("visible_pressuring", 0)) > 0 or int(threat_state.get("visible_marching", 0)) > 0 or bool(threat_state.get("hidden_targeting", false)):
		return true
	return _town_strategic_role(town) in ["capital", "stronghold"]

static func _consume_recruit_payload(recruits: Variant, manifest: Variant) -> Dictionary:
	var remaining := _normalize_recruit_payload(recruits)
	var shipment := _normalize_recruit_payload(manifest)
	for unit_id_value in shipment.keys():
		var unit_id := String(unit_id_value)
		remaining[unit_id] = max(0, int(remaining.get(unit_id, 0)) - int(shipment.get(unit_id_value, 0)))
		if int(remaining.get(unit_id, 0)) <= 0:
			remaining.erase(unit_id)
	return remaining

static func _clear_resource_site_delivery(node: Dictionary) -> Dictionary:
	var cleared := node.duplicate(true)
	cleared["delivery_controller_id"] = ""
	cleared["delivery_origin_town_id"] = ""
	cleared["delivery_target_kind"] = ""
	cleared["delivery_target_id"] = ""
	cleared["delivery_target_label"] = ""
	cleared["delivery_arrival_day"] = 0
	cleared["delivery_manifest"] = {}
	return cleared

static func _resource_site_response_action(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	var response_state := _resource_site_response_state(session, node, site)
	if int(response_state.get("watch_days", 0)) <= 0:
		return {}
	if bool(response_state.get("active", false)):
		return {}
	var linked_town_result := _resource_node_linked_town(session, node, "player")
	var cost = response_state.get("resource_cost", {})
	var movement_cost := int(response_state.get("movement_cost", 0))
	var movement_left := int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0
	var disabled := (not _can_afford(session, cost)) or movement_left < movement_cost
	var summary_parts := []
	var summary := String(response_state.get("summary", ""))
	if summary != "":
		summary_parts.append(summary)
	var commander_name := String(response_state.get("commander_name", ""))
	if commander_name != "":
		summary_parts.append("Commander %s" % commander_name)
	if int(linked_town_result.get("index", -1)) >= 0:
		summary_parts.append("Linked %s" % _town_name(linked_town_result.get("town", {})))
	var delivery_plan := {}
	if int(linked_town_result.get("index", -1)) >= 0:
		delivery_plan = _player_reserve_delivery_plan(session, linked_town_result.get("town", {}), response_state)
	if not delivery_plan.is_empty():
		summary_parts.append(
			"Load %s for %s" % [
				_describe_recruit_delta(delivery_plan.get("manifest", {})),
				String(delivery_plan.get("target_label", "the front")),
			]
		)
		summary_parts.append(
			"ETA %d day%s" % [
				int(delivery_plan.get("eta_days", 1)),
				"" if int(delivery_plan.get("eta_days", 1)) == 1 else "s",
			]
		)
	var impact_summary := _resource_site_response_effect_summary(response_state)
	if impact_summary != "":
		summary_parts.append(impact_summary)
	summary_parts.append("Escort %d" % int(response_state.get("security_rating", 1)))
	var cost_summary := _describe_resource_delta(cost)
	if cost_summary != "":
		summary_parts.append("Cost %s" % cost_summary)
	if movement_cost > 0:
		summary_parts.append("Move -%d" % movement_cost)
	summary_parts.append("%d day%s" % [
		int(response_state.get("watch_days", 0)),
		"" if int(response_state.get("watch_days", 0)) == 1 else "s",
	])
	return {
		"id": "site_response",
		"label": String(response_state.get("action_label", "Secure Route")),
		"summary": " | ".join(summary_parts),
		"disabled": disabled,
	}

static func _resource_site_context_summary(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	var parts := []
	var surface := describe_resource_site_surface(session, node, site)
	if surface != "":
		parts.append(surface)
	var interaction_surface := describe_resource_site_interaction_surface(node, site)
	if interaction_surface != "":
		parts.append(interaction_surface)
	var control_inspection := describe_resource_site_control_inspection(session, node, site)
	if control_inspection != "":
		parts.append(control_inspection)
	if _resource_site_is_persistent(site):
		var controller := String(node.get("collected_by_faction_id", ""))
		match controller:
			"":
				parts.append("Control unclaimed")
			"player":
				parts.append("Control secured")
			_:
				parts.append("Control denied by %s" % String(ContentService.get_faction(controller).get("name", controller)))
	var neutral_dwelling_label := _resource_site_neutral_dwelling_label(site)
	if neutral_dwelling_label != "":
		parts.append("Neutral family %s" % neutral_dwelling_label)
	var income_summary := _describe_resource_delta(site.get("control_income", {}))
	if income_summary != "":
		parts.append("Daily %s" % income_summary)
	var weekly_summary := _describe_recruit_delta(_resource_site_weekly_recruits(site))
	if weekly_summary != "":
		parts.append("Weekly %s" % weekly_summary)
	var claim_summary := _describe_recruit_delta(_resource_site_claim_recruits(site))
	if claim_summary != "":
		parts.append("Field recruits %s" % claim_summary)
	var reward_summary := _describe_reward_delta(_resource_site_claim_rewards(site))
	if reward_summary != "":
		parts.append("Reward %s" % reward_summary)
	var vision_radius = max(0, int(site.get("vision_radius", 0)))
	if vision_radius > 0:
		parts.append("Scout ring %d" % vision_radius)
	var pressure_guard = max(0, int(site.get("pressure_guard", 0)))
	if pressure_guard > 0:
		parts.append("Pressure guard %d" % pressure_guard)
	var town_support := _resource_site_town_support(site)
	var support_parts := []
	if int(town_support.get("readiness_bonus", 0)) > 0:
		support_parts.append("readiness +%d" % int(town_support.get("readiness_bonus", 0)))
	if int(town_support.get("quality_bonus", 0)) > 0:
		support_parts.append("quality +%d" % int(town_support.get("quality_bonus", 0)))
	if int(town_support.get("pressure_bonus", 0)) > 0:
		support_parts.append("pressure +%d" % int(town_support.get("pressure_bonus", 0)))
	if int(town_support.get("growth_bonus_percent", 0)) > 0:
		support_parts.append("growth +%d%%" % int(town_support.get("growth_bonus_percent", 0)))
	if int(town_support.get("recovery_relief", 0)) > 0:
		support_parts.append("recovery +%d" % int(town_support.get("recovery_relief", 0)))
	if not support_parts.is_empty():
		parts.append("Town support %s" % ", ".join(support_parts))
	var spell_id := String(site.get("learn_spell_id", ""))
	if spell_id != "":
		parts.append("Teaches %s" % String(ContentService.get_spell(spell_id).get("name", spell_id)))
	if _resource_site_is_repeatable(site):
		var service_summary := String(site.get("service_summary", ""))
		if service_summary != "":
			parts.append(service_summary)
		var visit_cost_summary := _describe_resource_delta(_resource_site_visit_cost(site))
		if visit_cost_summary != "":
			parts.append("Service cost %s" % visit_cost_summary)
		if _resource_site_repeat_ready(session, node, site):
			parts.append("Service ready")
		elif bool(node.get("collected", false)):
			parts.append("Next service day %d" % _resource_site_next_visit_day(node, site))
	var guard_profile = site.get("guard_profile", {})
	if guard_profile is Dictionary and not guard_profile.is_empty():
		parts.append("Guard %s | %s" % [
			String(guard_profile.get("threat", "unknown")),
			String(guard_profile.get("reward_tone", "reward site")),
		])
	var transit_profile = site.get("transit_profile", {})
	if transit_profile is Dictionary and not transit_profile.is_empty():
		parts.append("Transit %s | %s" % [
			String(transit_profile.get("mode", "route")),
			String(transit_profile.get("route_role", "link")),
		])
	var response_state := _resource_site_response_state(session, node, site)
	var delivery_state := _resource_site_delivery_state(session, node, site)
	if bool(response_state.get("active", false)):
		var response_line := "%s escort %d day%s" % [
			String(response_state.get("action_label", "Route secure")),
			int(response_state.get("remaining_days", 0)),
			"" if int(response_state.get("remaining_days", 0)) == 1 else "s",
		]
		var commander_name := String(response_state.get("commander_name", ""))
		if commander_name != "":
			response_line += " | %s detached" % commander_name
		var impact_summary := _resource_site_response_effect_summary(response_state)
		if impact_summary != "":
			response_line += " | %s" % impact_summary
		parts.append(response_line)
		if bool(delivery_state.get("active", false)):
			parts.append(_resource_site_delivery_line(session, node, site))
	elif String(node.get("collected_by_faction_id", "")) == "player" and int(response_state.get("watch_days", 0)) > 0:
		var ready_commander := String(response_state.get("commander_name", ""))
		if ready_commander != "":
			parts.append("Commit %s to escort %s and steady nearby threat lanes." % [
				ready_commander,
				String(response_state.get("action_label", "route security")).to_lower(),
			])
		else:
			parts.append("Order %s to steady nearby threat lanes." % String(response_state.get("action_label", "route security")))
		var linked_town_result := _resource_node_linked_town(session, node, "player")
		if int(linked_town_result.get("index", -1)) >= 0:
			var delivery_plan := _player_reserve_delivery_plan(session, linked_town_result.get("town", {}), response_state)
			if not delivery_plan.is_empty():
				parts.append(
					"Next convoy %s for %s in %d day%s." % [
						_describe_recruit_delta(delivery_plan.get("manifest", {})),
						String(delivery_plan.get("target_label", "the front")),
						int(delivery_plan.get("eta_days", 1)),
						"" if int(delivery_plan.get("eta_days", 1)) == 1 else "s",
					]
				)
	if parts.is_empty():
		return "Claim the site to add its stores immediately."
	return " | ".join(parts)

static func _grant_site_claim_recruits(session: SessionStateStoreScript.SessionData, recruits: Variant) -> String:
	if not (recruits is Dictionary) or recruits.is_empty():
		return ""
	var hero = session.overworld.get("hero", {})
	var army := _normalize_army_state(hero.get("army", {}))
	var unit_ids := []
	for unit_id_value in recruits.keys():
		unit_ids.append(String(unit_id_value))
	unit_ids.sort()
	for unit_id in unit_ids:
		var count = max(0, int(recruits.get(unit_id, 0)))
		if unit_id == "" or count <= 0:
			continue
		army["stacks"] = _add_army_stack(army.get("stacks", []), unit_id, count)
	hero["army"] = army
	session.overworld["hero"] = hero
	session.overworld["army"] = army
	return "Auxiliaries join the field army (%s)." % _describe_recruit_delta(recruits)

static func _learn_site_spell(session: SessionStateStoreScript.SessionData, spell_id: String) -> String:
	if spell_id == "":
		return ""
	var result := SpellRulesScript.learn_spell(session.overworld.get("hero", {}), spell_id)
	if not bool(result.get("ok", false)):
		return ""
	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	return String(result.get("message", ""))

static func _issue_active_site_response(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var node_result := _find_context_resource_node(session)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No logistics site is ready for response orders here."}
	return _issue_resource_site_response(session, String(node_result.get("node", {}).get("placement_id", "")), "field")

static func _issue_resource_site_response(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	origin: String
) -> Dictionary:
	normalize_overworld_state(session)
	var node_result := _find_resource_node_by_placement(session, placement_id)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": "That logistics site is no longer available."}
	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_site_is_persistent(site) or String(node.get("collected_by_faction_id", "")) != "player":
		return {"ok": false, "message": "Only player-controlled logistics sites can receive response orders."}
	var response_state := _resource_site_response_state(session, node, site)
	if int(response_state.get("watch_days", 0)) <= 0:
		return {"ok": false, "message": "This site has no authored response order."}
	if bool(response_state.get("active", false)):
		return {"ok": false, "message": "%s is already active here." % String(response_state.get("action_label", "Route security"))}
	var cost = response_state.get("resource_cost", {})
	if not _can_afford(session, cost):
		return {"ok": false, "message": "Insufficient resources for %s." % String(response_state.get("action_label", "that response"))}
	var movement_result := HeroCommandRulesScript.spend_active_hero_movement(
		session,
		int(response_state.get("movement_cost", 0)),
		String(response_state.get("action_label", "response order")).to_lower()
	)
	if not bool(movement_result.get("ok", false)):
		return movement_result
	if cost is Dictionary and not cost.is_empty():
		_spend_resources(session, cost)

	var active_hero := HeroCommandRulesScript.active_hero(session)
	var commander_id := String(active_hero.get("id", ""))
	var commander_name := String(active_hero.get("name", "The commander"))
	var security_rating := _route_security_rating_for_hero(active_hero)
	var linked_town_result := _resource_node_linked_town(session, node, "player")
	var delivery_plan := {}
	if int(linked_town_result.get("index", -1)) >= 0:
		delivery_plan = _player_reserve_delivery_plan(session, linked_town_result.get("town", {}), response_state)
	node["response_origin"] = origin
	node["response_source_town_id"] = String(linked_town_result.get("town", {}).get("placement_id", ""))
	node["response_last_day"] = session.day
	node["response_until_day"] = session.day + max(1, int(response_state.get("watch_days", 0))) - 1
	node["response_commander_id"] = commander_id
	node["response_security_rating"] = security_rating
	node = _clear_resource_site_delivery(node)
	if not delivery_plan.is_empty():
		var source_town = linked_town_result.get("town", {})
		var towns = session.overworld.get("towns", [])
		source_town["available_recruits"] = _consume_recruit_payload(
			source_town.get("available_recruits", {}),
			delivery_plan.get("manifest", {})
		)
		towns[int(linked_town_result.get("index", -1))] = source_town
		session.overworld["towns"] = towns
		node["delivery_controller_id"] = "player"
		node["delivery_origin_town_id"] = String(source_town.get("placement_id", ""))
		node["delivery_target_kind"] = String(delivery_plan.get("target_kind", ""))
		node["delivery_target_id"] = String(delivery_plan.get("target_id", ""))
		node["delivery_target_label"] = String(delivery_plan.get("target_label", ""))
		node["delivery_arrival_day"] = session.day + max(1, int(delivery_plan.get("eta_days", 1)))
		node["delivery_manifest"] = _normalize_recruit_payload(delivery_plan.get("manifest", {}))
	var nodes = session.overworld.get("resource_nodes", [])
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes

	var messages := [
		"%s commits %s at %s for %d day%s." % [
			commander_name,
			String(response_state.get("action_label", "route security")).to_lower(),
			String(site.get("name", "the site")),
			int(response_state.get("watch_days", 0)),
			"" if int(response_state.get("watch_days", 0)) == 1 else "s",
		]
	]
	var cost_summary := _describe_resource_delta(cost)
	if cost_summary != "":
		messages.append("Spent %s." % cost_summary)
	var impact_summary := _resource_site_response_effect_summary(response_state)
	if impact_summary != "":
		messages.append("Escort line %s while active." % impact_summary)
	messages.append("Route escort strength %d." % security_rating)
	if not delivery_plan.is_empty():
		messages.append(
			"%s loads %s for %s (%d day%s)." % [
				String(site.get("name", "The route")),
				_describe_recruit_delta(delivery_plan.get("manifest", {})),
				String(delivery_plan.get("target_label", "the front")),
				int(delivery_plan.get("eta_days", 1)),
				"" if int(delivery_plan.get("eta_days", 1)) == 1 else "s",
			]
		)
	var relief_message := ""
	if int(linked_town_result.get("index", -1)) >= 0 and int(response_state.get("recovery_relief", 0)) > 0:
		relief_message = relieve_town_recovery_pressure(
			session,
			String(linked_town_result.get("town", {}).get("placement_id", "")),
			int(response_state.get("recovery_relief", 0)),
			String(site.get("name", "frontier route"))
		)
	if relief_message != "":
		messages.append(relief_message)
	var result := _finalize_action_result(session, true, " ".join(messages))
	return _attach_post_action_recap(
		result,
		session,
		"site_response",
		{
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
		}
	)

static func _resource_node_linked_town(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	controller_id: String
) -> Dictionary:
	var town_result := _nearest_town_for_controller(
		session,
		controller_id,
		int(node.get("x", 0)),
		int(node.get("y", 0))
	)
	if int(town_result.get("index", -1)) < 0:
		return {"index": -1, "town": {}}
	var town = town_result.get("town", {})
	var distance = abs(int(node.get("x", 0)) - int(town.get("x", 0))) + abs(int(node.get("y", 0)) - int(town.get("y", 0)))
	if distance > int(_town_logistics_plan(town).get("support_radius", 0)):
		return {"index": -1, "town": {}}
	return town_result

static func _clear_resource_site_response(node: Dictionary) -> Dictionary:
	var cleared := _clear_resource_site_delivery(node)
	cleared["response_origin"] = ""
	cleared["response_source_town_id"] = ""
	cleared["response_last_day"] = 0
	cleared["response_until_day"] = 0
	cleared["response_commander_id"] = ""
	cleared["response_security_rating"] = 0
	return cleared

static func _advance_player_reserve_deliveries(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	if session == null:
		return messages
	var nodes = session.overworld.get("resource_nodes", [])
	var changed := false
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		var delivery_state: Dictionary = _resource_site_delivery_state(session, node)
		if String(delivery_state.get("controller_id", "")) != "player":
			continue
		if _normalize_recruit_payload(delivery_state.get("manifest", {})).is_empty():
			node = _clear_resource_site_delivery(node)
			nodes[index] = node
			changed = true
			continue
		if String(node.get("collected_by_faction_id", "")) != "player":
			node = _clear_resource_site_delivery(node)
			nodes[index] = node
			changed = true
			continue
		if session.day < int(delivery_state.get("arrival_day", 0)):
			continue
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		var interception_state: Dictionary = _resource_site_delivery_interception(session, node, site)
		if bool(interception_state.get("blocks_delivery", false)):
			continue
		var message = _resolve_player_reserve_delivery(session, site, delivery_state)
		node = _clear_resource_site_delivery(node)
		var followup_result := _queue_followup_reserve_delivery(session, node, site)
		node = followup_result.get("node", node)
		nodes[index] = node
		changed = true
		if message != "":
			messages.append(message)
		var followup_message := String(followup_result.get("message", ""))
		if followup_message != "":
			messages.append(followup_message)
	if changed:
		session.overworld["resource_nodes"] = nodes
	return messages

static func _queue_followup_reserve_delivery(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	var result := {"node": node, "message": ""}
	if session == null or node.is_empty() or site.is_empty():
		return result
	if String(node.get("collected_by_faction_id", "")) != "player":
		return result
	var response_state := _resource_site_response_state(session, node, site)
	if not bool(response_state.get("active", false)):
		return result
	if bool(_resource_site_delivery_state(session, node, site).get("active", false)):
		return result
	var linked_town_result := _resource_node_linked_town(session, node, "player")
	if int(linked_town_result.get("index", -1)) < 0:
		return result
	var source_town: Dictionary = linked_town_result.get("town", {})
	var delivery_plan := _player_reserve_delivery_plan(session, source_town, response_state)
	if delivery_plan.is_empty():
		return result
	var towns = session.overworld.get("towns", [])
	source_town["available_recruits"] = _consume_recruit_payload(
		source_town.get("available_recruits", {}),
		delivery_plan.get("manifest", {})
	)
	towns[int(linked_town_result.get("index", -1))] = source_town
	session.overworld["towns"] = towns
	var queued := node.duplicate(true)
	queued["delivery_controller_id"] = "player"
	queued["delivery_origin_town_id"] = String(source_town.get("placement_id", ""))
	queued["delivery_target_kind"] = String(delivery_plan.get("target_kind", ""))
	queued["delivery_target_id"] = String(delivery_plan.get("target_id", ""))
	queued["delivery_target_label"] = String(delivery_plan.get("target_label", ""))
	queued["delivery_arrival_day"] = session.day + max(1, int(delivery_plan.get("eta_days", 1)))
	queued["delivery_manifest"] = _normalize_recruit_payload(delivery_plan.get("manifest", {}))
	result["node"] = queued
	result["message"] = "%s loads a follow-up convoy for %s (%s, %d day%s)." % [
		String(site.get("name", "The route")),
		String(delivery_plan.get("target_label", "the front")),
		_describe_recruit_delta(delivery_plan.get("manifest", {})),
		int(delivery_plan.get("eta_days", 1)),
		"" if int(delivery_plan.get("eta_days", 1)) == 1 else "s",
	]
	return result

static func _resolve_player_reserve_delivery(
	session: SessionStateStoreScript.SessionData,
	site: Dictionary,
	delivery_state: Dictionary
) -> String:
	var manifest = _normalize_recruit_payload(delivery_state.get("manifest", {}))
	if manifest.is_empty():
		return ""
	var site_name = String(site.get("name", "The route"))
	var target_kind = String(delivery_state.get("target_kind", ""))
	var target_id = String(delivery_state.get("target_id", ""))
	var target_label = String(delivery_state.get("target_label", "the front"))
	var recruit_summary = String(delivery_state.get("recruit_summary", ""))
	var delivered := false
	match target_kind:
		"hero":
			delivered = _deliver_reinforcements_to_hero(session, target_id, manifest)
		"town":
			delivered = _deliver_reinforcements_to_town(session, target_id, manifest)
	if delivered:
		return "%s convoy reaches %s (%s)." % [site_name, target_label, recruit_summary]
	var returned_to = _return_reinforcements_to_source(session, String(delivery_state.get("origin_town_id", "")), manifest)
	if returned_to != "":
		return "%s convoy turns back to %s after %s closes (%s)." % [
			site_name,
			returned_to,
			target_label,
			recruit_summary,
		]
	return "%s convoy for %s is lost on the frontier (%s)." % [site_name, target_label, recruit_summary]

static func apply_delivery_interception_outcome(
	session: SessionStateStoreScript.SessionData,
	node_placement_id: String,
	outcome: String
) -> Dictionary:
	var result := {"summary": ""}
	if session == null or node_placement_id == "":
		return result
	var node_result := _find_resource_node_by_placement(session, node_placement_id)
	if int(node_result.get("index", -1)) < 0:
		return result
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
		return result
	var nodes = session.overworld.get("resource_nodes", [])
	match outcome:
		"victory":
			if session.day < int(delivery_state.get("arrival_day", 0)):
				result["summary"] = "%s route holds. %s keeps marching toward %s." % [
					String(site.get("name", "The route")),
					String(delivery_state.get("recruit_summary", "The convoy")),
					String(delivery_state.get("target_label", "the front")),
				]
				return result
			var delivery_message := _resolve_player_reserve_delivery(session, site, delivery_state)
			node = _clear_resource_site_delivery(node)
			nodes[int(node_result.get("index", -1))] = node
			session.overworld["resource_nodes"] = nodes
			result["summary"] = delivery_message
			return result
		"stalemate":
			node = _clear_resource_site_delivery(node)
			nodes[int(node_result.get("index", -1))] = node
			session.overworld["resource_nodes"] = nodes
			var returned_to := _return_reinforcements_to_source(
				session,
				String(delivery_state.get("origin_town_id", "")),
				_normalize_recruit_payload(delivery_state.get("manifest", {}))
			)
			if returned_to != "":
				result["summary"] = "%s convoy turns back to %s after the lane stalls (%s)." % [
					String(site.get("name", "The route")),
					returned_to,
					String(delivery_state.get("recruit_summary", "")),
				]
			else:
				result["summary"] = "%s convoy breaks off from %s after the line stalls (%s)." % [
					String(site.get("name", "The route")),
					String(delivery_state.get("target_label", "the front")),
					String(delivery_state.get("recruit_summary", "")),
				]
			return result
		"retreat":
			node = _clear_resource_site_delivery(node)
			nodes[int(node_result.get("index", -1))] = node
			session.overworld["resource_nodes"] = nodes
			var partition := _split_recruit_payload(
				_normalize_recruit_payload(delivery_state.get("manifest", {})),
				0.45
			)
			var returned_manifest: Dictionary = partition.get("returned", {})
			var lost_manifest: Dictionary = partition.get("lost", {})
			var returned_to := _return_reinforcements_to_source(
				session,
				String(delivery_state.get("origin_town_id", "")),
				returned_manifest
			)
			var returned_summary := _describe_recruit_delta(returned_manifest)
			var lost_summary := _describe_recruit_delta(lost_manifest)
			if returned_to != "" and returned_summary != "" and lost_summary != "":
				result["summary"] = "%s convoy scatters under pursuit. %s regathers %s, but %s is lost before it reaches %s." % [
					String(site.get("name", "The route")),
					returned_to,
					returned_summary,
					lost_summary,
					String(delivery_state.get("target_label", "the front")),
				]
			elif returned_to != "" and returned_summary != "":
				result["summary"] = "%s convoy breaks contact and turns %s back to %s." % [
					String(site.get("name", "The route")),
					returned_summary,
					returned_to,
				]
			else:
				result["summary"] = "%s convoy is cut apart during the withdrawal (%s)." % [
					String(site.get("name", "The route")),
					String(delivery_state.get("recruit_summary", "")),
				]
			return result
		"surrender":
			node = _clear_resource_site_delivery(node)
			nodes[int(node_result.get("index", -1))] = node
			session.overworld["resource_nodes"] = nodes
			result["summary"] = "%s convoy for %s is handed over intact with the surrender terms (%s)." % [
				String(site.get("name", "The route")),
				String(delivery_state.get("target_label", "the front")),
				String(delivery_state.get("recruit_summary", "")),
			]
			return result
		_:
			node = _clear_resource_site_delivery(node)
			nodes[int(node_result.get("index", -1))] = node
			session.overworld["resource_nodes"] = nodes
			var collapse_label := "is overrun in the rout" if outcome in ["hero_defeat", "defeat", "town_lost"] else "is intercepted"
			result["summary"] = "%s convoy for %s %s (%s)." % [
				String(site.get("name", "The route")),
				String(delivery_state.get("target_label", "the front")),
				collapse_label,
				String(delivery_state.get("recruit_summary", "")),
			]
			return result

static func _deliver_reinforcements_to_hero(
	session: SessionStateStoreScript.SessionData,
	hero_id: String,
	manifest: Dictionary
) -> bool:
	if session == null or hero_id == "":
		return false
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary) or String(hero.get("id", "")) != hero_id:
			continue
		var army = _normalize_army_state(hero.get("army", {}))
		var unit_ids = manifest.keys()
		unit_ids.sort()
		for unit_id_value in unit_ids:
			var unit_id := String(unit_id_value)
			army["stacks"] = _add_army_stack(army.get("stacks", []), unit_id, int(manifest.get(unit_id_value, 0)))
		hero["army"] = army
		heroes[index] = hero
		session.overworld["player_heroes"] = heroes
		if String(session.overworld.get("active_hero_id", "")) == hero_id:
			HeroCommandRulesScript._sync_active_hero_mirror(session)
		return true
	return false

static func _deliver_reinforcements_to_town(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String,
	manifest: Dictionary
) -> bool:
	if session == null or town_placement_id == "":
		return false
	var town_result = _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return false
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return false
	var garrison = town.get("garrison", [])
	var unit_ids := manifest.keys()
	unit_ids.sort()
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		garrison = _add_army_stack(garrison, unit_id, int(manifest.get(unit_id_value, 0)))
	town["garrison"] = garrison
	var towns = session.overworld.get("towns", [])
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return true

static func _return_reinforcements_to_source(
	session: SessionStateStoreScript.SessionData,
	source_town_id: String,
	manifest: Dictionary
) -> String:
	if session == null or source_town_id == "":
		return ""
	var town_result = _find_town_by_placement(session, source_town_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return ""
	town["available_recruits"] = _add_recruit_growth(town.get("available_recruits", {}), manifest)
	var towns = session.overworld.get("towns", [])
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return _town_name(town)

static func _split_recruit_payload(manifest: Dictionary, return_ratio: float) -> Dictionary:
	var normalized := _normalize_recruit_payload(manifest)
	var result := {"returned": {}, "lost": {}}
	if normalized.is_empty():
		return result
	var total_units := 0
	for unit_id_value in normalized.keys():
		total_units += max(0, int(normalized.get(unit_id_value, 0)))
	var target_returned := int(floor(float(total_units) * clampf(return_ratio, 0.0, 1.0)))
	if target_returned <= 0 and total_units >= 4 and return_ratio > 0.0:
		target_returned = 1
	target_returned = clampi(target_returned, 0, maxi(0, total_units - 1))
	var returned := {}
	var lost := {}
	var remaining_to_return := target_returned
	var unit_ids := normalized.keys()
	unit_ids.sort()
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var available: int = max(0, int(normalized.get(unit_id_value, 0)))
		var returned_count: int = min(available, remaining_to_return)
		if returned_count > 0:
			returned[unit_id] = returned_count
		var lost_count: int = max(0, available - returned_count)
		if lost_count > 0:
			lost[unit_id] = lost_count
		remaining_to_return = max(0, remaining_to_return - returned_count)
	result["returned"] = returned
	result["lost"] = lost
	return result

static func _army_strength_value(stacks: Variant) -> int:
	var total_strength := 0
	if not (stacks is Array):
		return total_strength
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var count = max(0, int(stack.get("count", 0)))
		if count <= 0:
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		total_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total_strength

static func _nearest_town_for_controller(
	session: SessionStateStoreScript.SessionData,
	controller_id: String,
	x: int,
	y: int
) -> Dictionary:
	var best_index := -1
	var best_distance := 9999
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or not _town_matches_controller(town, controller_id):
			continue
		var distance = abs(x - int(town.get("x", 0))) + abs(y - int(town.get("y", 0)))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0:
		return {"index": -1, "town": {}}
	return {"index": best_index, "town": towns[best_index]}

static func _town_matches_controller(town: Dictionary, controller_id: String) -> bool:
	if controller_id == "player":
		return String(town.get("owner", "neutral")) == "player"
	return String(town.get("owner", "neutral")) == "enemy" and _town_faction_id(town) == controller_id

static func _get_town_at(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == x and int(town.get("y", -1)) == y:
			return town
	return {}

static func _position_matches(entry: Dictionary, pos: Vector2i) -> bool:
	return int(entry.get("x", -1)) == pos.x and int(entry.get("y", -1)) == pos.y

static func _add_army_stack(stacks: Variant, unit_id: String, amount: int) -> Array:
	var normalized := []
	var added := false
	if stacks is Array:
		for stack_value in stacks:
			if not (stack_value is Dictionary):
				continue
			var stack = {
				"unit_id": String(stack_value.get("unit_id", "")),
				"count": max(0, int(stack_value.get("count", 0))),
			}
			if stack["unit_id"] == unit_id:
				stack["count"] = int(stack.get("count", 0)) + max(0, amount)
				added = true
			if stack["unit_id"] != "" and int(stack.get("count", 0)) > 0:
				normalized.append(stack)
	if not added and unit_id != "" and amount > 0:
		normalized.append({"unit_id": unit_id, "count": amount})
	return normalized

static func _army_unit_count(stacks: Variant, unit_id: String) -> int:
	var total := 0
	if stacks is Array:
		for stack_value in stacks:
			if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
				total += max(0, int(stack_value.get("count", 0)))
	return total

static func _movement_max_from_hero(hero: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HeroCommandRulesScript.movement_max_for_hero(hero, session)

static func _calculate_town_income(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	var income := {"gold": 0, "wood": 0, "ore": 0}
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	for building_id_value in built_buildings:
		var building := ContentService.get_building(String(building_id_value))
		income = _add_resource_sets(income, building.get("income", {}))
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	income = _add_resource_sets(
		income,
		_economy_profile_income(ContentService.get_faction(String(town_template.get("faction_id", ""))).get("economy", {}), built_buildings)
	)
	income = _add_resource_sets(income, _economy_profile_income(town_template.get("economy", {}), built_buildings))
	if session != null:
		var occupation := _town_occupation_state(session, town)
		income = _apply_resource_percent_scale(income, 100 - int(occupation.get("income_penalty_percent", 0)))
	return income

static func _growth_tick_town(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var hero = session.overworld.get("hero", {})
	var weekly_growth := HeroProgressionRulesScript.scale_recruit_growth(hero, _town_weekly_growth(town, session))
	town["available_recruits"] = _add_recruit_growth(
		town.get("available_recruits", {}),
		weekly_growth
	)
	return weekly_growth

static func _seed_recruits_for_town(town: Dictionary) -> Dictionary:
	var normalized_town := town.duplicate(true)
	normalized_town["built_buildings"] = _normalize_built_buildings_for_town_state(normalized_town)
	return _seed_scenario_recruits_for_town_state(normalized_town)

static func _town_weekly_growth(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	var growth := _seed_recruits_for_town(town)
	if session == null:
		return growth
	var growth_percent := 0
	var logistics := _town_logistics_state(session, town)
	growth_percent += int(logistics.get("growth_bonus_percent", 0))
	growth_percent += int(logistics.get("response_growth_bonus_percent", 0))
	growth_percent -= int(logistics.get("gap_growth_penalty_percent", 0))
	var recovery := _town_recovery_state(session, town)
	growth_percent -= int(recovery.get("growth_penalty_percent", 0))
	var capital_project := _town_capital_project_state(town, session)
	growth_percent -= int(capital_project.get("growth_penalty_percent", 0))
	var occupation := _town_occupation_state(session, town)
	growth_percent -= int(occupation.get("growth_penalty_percent", 0))
	return _apply_recruit_percent(growth, growth_percent)

static func _town_reinforcement_quality(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	var quality := _weighted_recruit_value(_town_weekly_growth(town, session))
	quality += _town_role_quality_bonus(_town_strategic_role(town))
	var logistics := _town_logistics_state(session, town)
	quality += int(logistics.get("quality_bonus", 0))
	quality += int(logistics.get("response_quality_bonus", 0))
	quality -= int(logistics.get("gap_quality_penalty", 0))
	var recovery := _town_recovery_state(session, town)
	quality -= int(recovery.get("quality_penalty", 0))
	var capital_project := town_capital_project_state(town, session)
	quality += int(capital_project.get("quality_bonus", 0))
	quality -= int(capital_project.get("quality_penalty", 0))
	var occupation := _town_occupation_state(session, town)
	quality -= int(occupation.get("quality_penalty", 0))
	return max(0, quality)

static func _town_battle_readiness(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var readiness := int(round(float(_town_garrison_strength(town)) / 12.0))
	readiness += int(round(float(_town_reinforcement_quality(town, session)) / 6.0))
	readiness += _readiness_bonus_from_profile(faction.get("recruitment", {}))
	readiness += _readiness_bonus_from_profile(town_template.get("recruitment", {}))
	readiness += _town_building_bonus_total(town, "readiness_bonus")
	readiness += _town_spell_tier(town) * 6
	readiness += _town_role_readiness_bonus(_town_strategic_role(town))
	var logistics := _town_logistics_state(session, town)
	readiness += int(logistics.get("readiness_bonus", 0))
	readiness += int(logistics.get("response_readiness_bonus", 0))
	readiness -= int(logistics.get("gap_readiness_penalty", 0))
	var recovery := _town_recovery_state(session, town)
	readiness -= int(recovery.get("readiness_penalty", 0))
	var capital_project := town_capital_project_state(town, session)
	readiness += int(round(float(int(capital_project.get("defense_bonus", 0))) / 8.0))
	readiness -= int(capital_project.get("readiness_penalty", 0))
	var occupation := _town_occupation_state(session, town)
	readiness -= int(occupation.get("readiness_penalty", 0))
	return max(0, readiness)

static func _town_pressure_output(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var pressure := _pressure_bonus_from_profile(faction.get("economy", {}))
	pressure += _pressure_bonus_from_profile(town_template.get("economy", {}))
	pressure += _town_building_bonus_total(town, "pressure_bonus")
	pressure += int(floor(float(_town_reinforcement_quality(town, session)) / 18.0))
	pressure += max(0, _town_spell_tier(town) - 1)
	pressure += _town_role_pressure_bonus(_town_strategic_role(town))
	var logistics := _town_logistics_state(session, town)
	pressure += int(logistics.get("pressure_bonus", 0))
	pressure += int(logistics.get("response_pressure_bonus", 0))
	pressure -= int(logistics.get("gap_pressure_penalty", 0))
	var recovery := _town_recovery_state(session, town)
	pressure -= int(recovery.get("pressure_penalty", 0))
	var capital_project := town_capital_project_state(town, session)
	pressure += int(capital_project.get("pressure_bonus", 0))
	pressure -= int(capital_project.get("pressure_penalty", 0))
	var occupation := _town_occupation_state(session, town)
	pressure -= int(occupation.get("pressure_penalty", 0))
	return max(0, pressure)

static func _town_logistics_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var empty_state := _empty_town_logistics_state()
	if session == null or town.is_empty():
		return empty_state
	var controller_id := _town_controller_id(town)
	if controller_id == "":
		return empty_state
	var plan := _town_logistics_plan(town)
	var support_radius := int(plan.get("support_radius", 0))
	var family_counts := {}
	var held_site_labels := []
	var disrupted_site_labels := []
	var threatened_site_labels := []
	var response_site_labels := []
	var delivery_site_labels := []
	var held_site_count := 0
	var disrupted_count := 0
	var threatened_count := 0
	var response_count := 0
	var delivery_count := 0
	var quality_bonus := 0
	var readiness_bonus := 0
	var pressure_bonus := 0
	var growth_bonus_percent := 0
	var recovery_relief_bonus := 0
	var response_quality_bonus := 0
	var response_readiness_bonus := 0
	var response_pressure_bonus := 0
	var response_recovery_relief_bonus := 0
	var response_growth_bonus_percent := 0
	var response_pressure_guard_bonus := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		var family := String(site.get("family", ""))
		if family == "":
			continue
		var town_result := _resource_node_linked_town(session, node, controller_id)
		if int(town_result.get("index", -1)) < 0:
			continue
		var assigned_town = town_result.get("town", {})
		if String(assigned_town.get("placement_id", "")) != String(town.get("placement_id", "")):
			continue
		var threatened := _resource_site_under_threat(session, node, controller_id)
		var site_name := String(site.get("name", "Frontier site"))
		var controller := String(node.get("collected_by_faction_id", ""))
		if controller == controller_id:
			held_site_count += 1
			family_counts[family] = int(family_counts.get(family, 0)) + 1
			held_site_labels.append(site_name)
			var support := _resource_site_town_support(site)
			quality_bonus += int(support.get("quality_bonus", 0))
			readiness_bonus += int(support.get("readiness_bonus", 0))
			pressure_bonus += int(support.get("pressure_bonus", 0))
			growth_bonus_percent += int(support.get("growth_bonus_percent", 0))
			recovery_relief_bonus += int(support.get("recovery_relief", 0))
			var response_state := _resource_site_response_state(session, node, site)
			if bool(response_state.get("active", false)):
				response_count += 1
				response_site_labels.append("%s escort (%dd)" % [site_name, int(response_state.get("remaining_days", 0))])
				response_quality_bonus += int(response_state.get("quality_bonus", 0))
				response_readiness_bonus += int(response_state.get("readiness_bonus", 0))
				response_pressure_bonus += int(response_state.get("pressure_bonus", 0))
				response_recovery_relief_bonus += int(response_state.get("recovery_relief", 0))
				response_growth_bonus_percent += int(response_state.get("growth_bonus_percent", 0))
				response_pressure_guard_bonus += int(response_state.get("pressure_guard_bonus", 0))
				var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
				if bool(delivery_state.get("active", false)):
					delivery_count += 1
					delivery_site_labels.append(_resource_site_delivery_line(session, node, site))
			if threatened:
				threatened_count += 1
				threatened_site_labels.append(site_name)
		else:
			disrupted_count += 1
			disrupted_site_labels.append(site_name)
			if threatened:
				threatened_count += 1
				threatened_site_labels.append(site_name)
	var requirement_progress := _support_requirement_progress(family_counts, plan.get("support_requirements", {}))
	var missing_family_labels = requirement_progress.get("missing_family_labels", [])
	var gap_penalties := _town_logistics_gap_penalties(town, int(requirement_progress.get("support_gap", 0)))
	var summary_parts := []
	var grade := "stable"
	if held_site_count <= 0 and int(requirement_progress.get("required_total", 0)) > 0:
		grade = "broken"
	elif disrupted_count > 0 or threatened_count > 0 or int(requirement_progress.get("support_gap", 0)) > 0:
		grade = "strained"
	summary_parts.append("%s chain" % grade.capitalize())
	if int(requirement_progress.get("required_total", 0)) > 0:
		summary_parts.append("%d/%d anchors" % [
			int(requirement_progress.get("met_requirements", 0)),
			int(requirement_progress.get("required_total", 0)),
		])
	elif held_site_count > 0:
		summary_parts.append("%d linked" % held_site_count)
	if disrupted_count > 0:
		summary_parts.append("%d denied" % disrupted_count)
	if threatened_count > 0:
		summary_parts.append("%d threatened" % threatened_count)
	if response_count > 0:
		summary_parts.append("%d escorted" % response_count)
	if delivery_count > 0:
		summary_parts.append("%d convoy%s" % [delivery_count, "" if delivery_count == 1 else "s"])
	if missing_family_labels is Array and not missing_family_labels.is_empty():
		summary_parts.append("Missing %s" % ", ".join(missing_family_labels))
	var impact_parts := []
	if quality_bonus > 0:
		impact_parts.append("quality +%d" % quality_bonus)
	if readiness_bonus > 0:
		impact_parts.append("readiness +%d" % readiness_bonus)
	if pressure_bonus > 0:
		impact_parts.append("%s +%d" % [_town_pressure_label(town), pressure_bonus])
	if growth_bonus_percent > 0:
		impact_parts.append("recruits +%d%%" % growth_bonus_percent)
	if recovery_relief_bonus > 0:
		impact_parts.append("recovery +%d/day" % recovery_relief_bonus)
	if response_quality_bonus > 0:
		impact_parts.append("response +%d quality" % response_quality_bonus)
	if response_readiness_bonus > 0:
		impact_parts.append("response +%d readiness" % response_readiness_bonus)
	if response_pressure_bonus > 0:
		impact_parts.append("response +%d %s" % [response_pressure_bonus, _town_pressure_label(town).to_lower()])
	if response_recovery_relief_bonus > 0:
		impact_parts.append("response +%d/day recovery" % response_recovery_relief_bonus)
	if response_growth_bonus_percent > 0:
		impact_parts.append("response +%d%% recruits" % response_growth_bonus_percent)
	if response_pressure_guard_bonus > 0:
		impact_parts.append("escort +%d pressure guard" % response_pressure_guard_bonus)
	if int(gap_penalties.get("quality_penalty", 0)) > 0:
		impact_parts.append("gap -%d quality" % int(gap_penalties.get("quality_penalty", 0)))
	if int(gap_penalties.get("readiness_penalty", 0)) > 0:
		impact_parts.append("gap -%d readiness" % int(gap_penalties.get("readiness_penalty", 0)))
	if int(gap_penalties.get("pressure_penalty", 0)) > 0:
		impact_parts.append("gap -%d %s" % [int(gap_penalties.get("pressure_penalty", 0)), _town_pressure_label(town).to_lower()])
	if int(gap_penalties.get("growth_penalty_percent", 0)) > 0:
		impact_parts.append("gap -%d%% recruits" % int(gap_penalties.get("growth_penalty_percent", 0)))
	return {
		"plan": plan,
		"summary": " | ".join(summary_parts),
		"impact_summary": ", ".join(impact_parts),
		"grade": grade,
		"support_radius": support_radius,
		"held_site_count": held_site_count,
		"disrupted_count": disrupted_count,
		"threatened_count": threatened_count,
		"response_count": response_count,
		"delivery_count": delivery_count,
		"held_site_labels": held_site_labels,
		"disrupted_site_labels": disrupted_site_labels,
		"threatened_site_labels": threatened_site_labels,
		"response_site_labels": response_site_labels,
		"delivery_site_labels": delivery_site_labels,
		"family_counts": family_counts,
		"met_requirements": int(requirement_progress.get("met_requirements", 0)),
		"required_total": int(requirement_progress.get("required_total", 0)),
		"support_gap": int(requirement_progress.get("support_gap", 0)),
		"missing_family_labels": missing_family_labels,
		"quality_bonus": quality_bonus,
		"readiness_bonus": readiness_bonus,
		"pressure_bonus": pressure_bonus,
		"growth_bonus_percent": growth_bonus_percent,
		"recovery_relief_bonus": recovery_relief_bonus,
		"response_quality_bonus": response_quality_bonus,
		"response_readiness_bonus": response_readiness_bonus,
		"response_pressure_bonus": response_pressure_bonus,
		"response_recovery_relief_bonus": response_recovery_relief_bonus,
		"response_growth_bonus_percent": response_growth_bonus_percent,
		"response_pressure_guard_bonus": response_pressure_guard_bonus,
		"gap_quality_penalty": int(gap_penalties.get("quality_penalty", 0)),
		"gap_readiness_penalty": int(gap_penalties.get("readiness_penalty", 0)),
		"gap_pressure_penalty": int(gap_penalties.get("pressure_penalty", 0)),
		"gap_growth_penalty_percent": int(gap_penalties.get("growth_penalty_percent", 0)),
	}

static func _town_recovery_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	var pressure = max(0, int(recovery.get("pressure", 0)))
	var relief_rating := _town_recovery_relief_rating(session, town)
	var relief_per_day = max(1, 1 + int(floor(float(relief_rating) / 3.0)))
	var readiness_penalty = pressure * 6
	var quality_penalty = pressure * 4
	var pressure_penalty := int(ceil(float(pressure) / 2.0))
	var growth_penalty_percent = clamp(pressure * 12, 0, 60)
	var days_to_clear := 0 if pressure <= 0 else int(ceil(float(pressure) / float(relief_per_day)))
	var summary := "steady"
	if pressure > 0:
		summary = "%d pressure | -%d readiness | -%d%% recruits | %d/day relief" % [
			pressure,
			readiness_penalty,
			growth_penalty_percent,
			relief_per_day,
		]
	return {
		"active": pressure > 0,
		"pressure": pressure,
		"last_event_day": int(recovery.get("last_event_day", 0)),
		"source": String(recovery.get("source", "")),
		"relief_rating": relief_rating,
		"relief_per_day": relief_per_day,
		"readiness_penalty": readiness_penalty,
		"quality_penalty": quality_penalty,
		"pressure_penalty": pressure_penalty,
		"growth_penalty_percent": growth_penalty_percent,
		"days_to_clear": days_to_clear,
		"summary": summary,
	}

static func _town_strategic_role(town: Dictionary) -> String:
	var role := String(ContentService.get_town(String(town.get("town_id", ""))).get("strategic_role", ""))
	return role if role in ["capital", "stronghold"] else "frontier"

static func _town_strategic_summary(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var summary := String(template.get("strategic_summary", ""))
	if summary != "":
		return summary
	return String(template.get("identity_summary", ""))

static func _faction_identity_surface(faction_id: String) -> String:
	var faction := ContentService.get_faction(faction_id)
	if faction.is_empty():
		return ""
	var pillars = faction.get("design_pillars", {})
	var lines := ["Faction Identity: %s" % String(faction.get("name", faction_id))]
	var identity := String(faction.get("identity_summary", "")).strip_edges()
	if identity != "":
		lines.append("Theme: %s" % identity)
	if pillars is Dictionary:
		var economy_style := String(pillars.get("economy_style", "")).strip_edges()
		if economy_style != "":
			lines.append("Economy: %s" % economy_style)
		var map_pressure := String(pillars.get("map_pressure", "")).strip_edges()
		if map_pressure != "":
			lines.append("Pressure: %s" % map_pressure)
		var battle_style := String(pillars.get("battle_style", "")).strip_edges()
		if battle_style != "":
			lines.append("Strategic cue: %s" % battle_style)
	return "\n".join(lines)

static func _town_identity_surface(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	if town.is_empty():
		return ""
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction_id := String(template.get("faction_id", ""))
	var faction := ContentService.get_faction(faction_id)
	var pillars = faction.get("design_pillars", {})
	var role := _town_strategic_role(town)
	var lines := [
		"Identity: %s | %s | %s" % [
			_town_name(town),
			String(faction.get("name", faction_id if faction_id != "" else "Faction")),
			_town_role_label(role),
		]
	]
	var identity := String(template.get("identity_summary", "")).strip_edges()
	if identity == "":
		identity = String(faction.get("identity_summary", "")).strip_edges()
	if identity != "":
		lines.append("Town: %s" % identity)
	var economy_line := _town_economy_identity_line(town, template, faction, session)
	if economy_line != "":
		lines.append(economy_line)
	var magic_line := _town_magic_identity_line(town, template)
	if magic_line != "":
		lines.append(magic_line)
	var strategic_summary := _town_strategic_summary(town).strip_edges()
	if strategic_summary != "":
		lines.append("Role: %s" % strategic_summary)
	if pillars is Dictionary:
		var map_pressure := String(pillars.get("map_pressure", "")).strip_edges()
		if map_pressure != "":
			lines.append("Pressure identity: %s" % map_pressure)
		var battle_style := String(pillars.get("battle_style", "")).strip_edges()
		if battle_style != "":
			lines.append("Strategic cue: %s" % battle_style)
	return "\n".join(lines)

static func _town_economy_identity_line(
	town: Dictionary,
	template: Dictionary,
	faction: Dictionary,
	session: SessionStateStoreScript.SessionData = null
) -> String:
	var parts := []
	var income := _describe_resource_delta(_calculate_town_income(town, session))
	if income != "":
		parts.append("daily %s" % income)
	var pillars = faction.get("design_pillars", {})
	if pillars is Dictionary:
		var economy_style := String(pillars.get("economy_style", "")).strip_edges()
		if economy_style != "":
			parts.append(economy_style)
	var pressure_output := _town_pressure_output(town, session)
	if pressure_output > 0:
		parts.append("%s %d" % [_town_pressure_label(town).to_lower(), pressure_output])
	if parts.is_empty():
		return ""
	return "Economy: %s" % " | ".join(parts)

static func _town_magic_identity_line(town: Dictionary, template: Dictionary) -> String:
	var spell_names := []
	var max_library_tier := 0
	for tier_value in template.get("spell_library", []):
		if not (tier_value is Dictionary):
			continue
		max_library_tier = max(max_library_tier, int(tier_value.get("tier", 0)))
		for spell_id_value in tier_value.get("spell_ids", []):
			if spell_names.size() >= 3:
				break
			var spell_id := String(spell_id_value)
			var spell := ContentService.get_spell(spell_id)
			var spell_name := String(spell.get("name", spell_id))
			if spell_name != "" and spell_name not in spell_names:
				spell_names.append(spell_name)
	if max_library_tier <= 0 and spell_names.is_empty():
		return ""
	var parts := ["tier %d library" % max(max_library_tier, _town_spell_tier(town))]
	if not spell_names.is_empty():
		parts.append("flavor %s" % ", ".join(spell_names))
	return "Magic: %s" % " | ".join(parts)

static func _town_role_label(role: String) -> String:
	match role:
		"capital":
			return "Capital Anchor"
		"stronghold":
			return "Frontier Stronghold"
		_:
			return "Frontier Town"

static func _town_capital_project_state(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	var project_ids := _town_capital_project_ids(town)
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	var active_ids := []
	var pressure_bonus := 0
	var defense_bonus := 0
	var threshold_reduction := 0
	var max_active_raids_bonus := 0
	var recovery_guard := 0
	var summary := ""
	var support_requirements := {}
	var vulnerability_penalties := _blank_project_vulnerability_penalties()
	var vulnerability_summary := String(_town_logistics_plan(town).get("vulnerability_summary", ""))
	for project_id in project_ids:
		var project_building := ContentService.get_building(project_id)
		var capital_project = project_building.get("capital_project", {})
		if capital_project is Dictionary and support_requirements.is_empty():
			support_requirements = _normalize_support_requirements(capital_project.get("support_requirements", {}))
			var authored_penalties = capital_project.get("vulnerability_penalties", {})
			if authored_penalties is Dictionary:
				for key in vulnerability_penalties.keys():
					vulnerability_penalties[key] = max(0, int(authored_penalties.get(key, vulnerability_penalties[key])))
		if project_id not in built_buildings:
			continue
		active_ids.append(project_id)
		if capital_project is Dictionary:
			pressure_bonus += max(0, int(capital_project.get("pressure_bonus", 0)))
			defense_bonus += max(0, int(capital_project.get("defense_bonus", 0)))
			threshold_reduction += max(0, int(capital_project.get("raid_threshold_reduction", 0)))
			max_active_raids_bonus += max(0, int(capital_project.get("max_active_raids_bonus", 0)))
			recovery_guard += max(0, int(capital_project.get("recovery_guard", 0)))
			if summary == "":
				summary = String(capital_project.get("summary", ""))
	var primary_project_id := String(project_ids[0]) if not project_ids.is_empty() else ""
	var dependency_ids := _project_dependency_ids(primary_project_id)
	var dependency_complete := 0
	var missing_dependency_labels := []
	for dependency_id in dependency_ids:
		if dependency_id in built_buildings:
			dependency_complete += 1
			continue
		var dependency := ContentService.get_building(dependency_id)
		missing_dependency_labels.append(String(dependency.get("name", dependency_id)))
	var progress_total := dependency_ids.size() + (0 if primary_project_id == "" else 1)
	var progress_complete := dependency_complete + (1 if primary_project_id in built_buildings else 0)
	var next_label := ""
	if primary_project_id != "" and primary_project_id not in built_buildings and missing_dependency_labels.is_empty():
		next_label = String(ContentService.get_building(primary_project_id).get("name", primary_project_id))
	elif not missing_dependency_labels.is_empty():
		next_label = String(missing_dependency_labels[0])
	var support_met := 0
	var support_total := 0
	var support_gap := 0
	var missing_support_labels := []
	var vulnerable := false
	var quality_penalty := 0
	var readiness_penalty := 0
	var pressure_penalty := 0
	var growth_penalty_percent := 0
	if session != null:
		if support_requirements.is_empty():
			support_requirements = _normalize_support_requirements(_town_logistics_plan(town).get("support_requirements", {}))
		var logistics := _town_logistics_state(session, town)
		var recovery := _town_recovery_state(session, town)
		var requirement_progress := _support_requirement_progress(
			logistics.get("family_counts", {}),
			support_requirements
		)
		support_met = int(requirement_progress.get("met_requirements", 0))
		support_total = int(requirement_progress.get("required_total", 0))
		support_gap = int(requirement_progress.get("support_gap", 0))
		missing_support_labels = requirement_progress.get("missing_family_labels", [])
		vulnerable = not active_ids.is_empty() and (support_gap > 0 or bool(recovery.get("active", false)))
		if vulnerable:
			var vulnerability_steps = max(1, support_gap + (1 if bool(recovery.get("active", false)) else 0))
			quality_penalty = int(vulnerability_penalties.get("quality_penalty", 0)) * vulnerability_steps
			readiness_penalty = int(vulnerability_penalties.get("readiness_penalty", 0)) * vulnerability_steps
			pressure_penalty = int(vulnerability_penalties.get("pressure_penalty", 0)) * vulnerability_steps
			growth_penalty_percent = int(vulnerability_penalties.get("growth_penalty_percent", 0)) * vulnerability_steps
	return {
		"total": project_ids.size(),
		"active": not active_ids.is_empty(),
		"active_ids": active_ids,
		"pressure_bonus": pressure_bonus,
		"defense_bonus": defense_bonus,
		"quality_bonus": active_ids.size() * 12,
		"recovery_guard": recovery_guard,
		"raid_threshold_reduction": threshold_reduction,
		"max_active_raids_bonus": max_active_raids_bonus,
		"summary": summary,
		"primary_project_id": primary_project_id,
		"progress_complete": progress_complete,
		"progress_total": progress_total,
		"missing_dependency_labels": missing_dependency_labels,
		"next_label": next_label,
		"support_requirements": support_requirements,
		"support_met": support_met,
		"support_total": support_total,
		"support_gap": support_gap,
		"missing_support_labels": missing_support_labels,
		"vulnerable": vulnerable,
		"quality_penalty": quality_penalty,
		"readiness_penalty": readiness_penalty,
		"pressure_penalty": pressure_penalty,
		"growth_penalty_percent": growth_penalty_percent,
		"vulnerability_summary": vulnerability_summary,
	}

static func _town_controller_id(town: Dictionary) -> String:
	if String(town.get("owner", "neutral")) == "player":
		return "player"
	if String(town.get("owner", "neutral")) == "enemy":
		return _town_faction_id(town)
	return ""

static func _town_logistics_plan(town: Dictionary) -> Dictionary:
	var plan = ContentService.get_town(String(town.get("town_id", ""))).get("logistics_plan", {})
	var role := _town_strategic_role(town)
	return {
		"support_radius": max(0, int(plan.get("support_radius", _default_logistics_support_radius(role)))),
		"support_requirements": _normalize_support_requirements(
			plan.get("support_requirements", _default_logistics_requirements_for_role(role))
		),
		"recovery_relief": max(0, int(plan.get("recovery_relief", 0))),
		"vulnerability_summary": String(plan.get("vulnerability_summary", "")),
	}

static func _default_logistics_support_radius(role: String) -> int:
	match role:
		"capital":
			return 7
		"stronghold":
			return 6
		_:
			return 5

static func _default_logistics_requirements_for_role(role: String) -> Dictionary:
	match role:
		"capital":
			return {"neutral_dwelling": 1, "faction_outpost": 1, "frontier_shrine": 1}
		"stronghold":
			return {"faction_outpost": 1, "frontier_shrine": 1}
		_:
			return {"faction_outpost": 1}

static func _normalize_support_requirements(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for family_id_value in value.keys():
			var family_id := String(family_id_value)
			if family_id not in LOGISTICS_SITE_FAMILIES:
				continue
			normalized[family_id] = max(0, int(value.get(family_id, 0)))
	return normalized

static func _support_requirement_progress(family_counts: Variant, requirements: Variant) -> Dictionary:
	var met_requirements := 0
	var required_total := 0
	var missing_family_labels := []
	if not (requirements is Dictionary):
		return {
			"met_requirements": met_requirements,
			"required_total": required_total,
			"support_gap": 0,
			"missing_family_labels": missing_family_labels,
		}
	for family_id_value in requirements.keys():
		var family_id := String(family_id_value)
		var required_count = max(0, int(requirements.get(family_id, 0)))
		if required_count <= 0:
			continue
		required_total += required_count
		var held_count := int(family_counts.get(family_id, 0)) if family_counts is Dictionary else 0
		met_requirements += min(required_count, held_count)
		if held_count < required_count:
			missing_family_labels.append(_resource_site_family_short_label(family_id))
	return {
		"met_requirements": met_requirements,
		"required_total": required_total,
		"support_gap": max(0, required_total - met_requirements),
		"missing_family_labels": missing_family_labels,
	}

static func _empty_town_logistics_state() -> Dictionary:
	return {
		"plan": {"support_radius": 0, "support_requirements": {}, "recovery_relief": 0, "vulnerability_summary": ""},
		"summary": "",
		"impact_summary": "",
		"grade": "stable",
		"support_radius": 0,
		"held_site_count": 0,
		"disrupted_count": 0,
		"threatened_count": 0,
		"response_count": 0,
		"delivery_count": 0,
		"held_site_labels": [],
		"disrupted_site_labels": [],
		"threatened_site_labels": [],
		"response_site_labels": [],
		"delivery_site_labels": [],
		"family_counts": {},
		"met_requirements": 0,
		"required_total": 0,
		"support_gap": 0,
		"missing_family_labels": [],
		"quality_bonus": 0,
		"readiness_bonus": 0,
		"pressure_bonus": 0,
		"growth_bonus_percent": 0,
		"recovery_relief_bonus": 0,
		"response_quality_bonus": 0,
		"response_readiness_bonus": 0,
		"response_pressure_bonus": 0,
		"response_recovery_relief_bonus": 0,
		"response_growth_bonus_percent": 0,
		"response_pressure_guard_bonus": 0,
		"gap_quality_penalty": 0,
		"gap_readiness_penalty": 0,
		"gap_pressure_penalty": 0,
		"gap_growth_penalty_percent": 0,
	}

static func _town_logistics_gap_penalties(town: Dictionary, support_gap: int) -> Dictionary:
	var penalties := {
		"quality_penalty": 0,
		"readiness_penalty": 0,
		"pressure_penalty": 0,
		"growth_penalty_percent": 0,
	}
	if support_gap <= 0:
		return penalties
	match _town_strategic_role(town):
		"capital":
			penalties["quality_penalty"] = support_gap * 4
			penalties["readiness_penalty"] = support_gap * 5
			penalties["pressure_penalty"] = support_gap
			penalties["growth_penalty_percent"] = support_gap * 8
		"stronghold":
			penalties["quality_penalty"] = support_gap * 3
			penalties["readiness_penalty"] = support_gap * 4
			penalties["pressure_penalty"] = support_gap
			penalties["growth_penalty_percent"] = support_gap * 6
	return penalties

static func _normalize_town_recovery_state(value: Variant) -> Dictionary:
	return {
		"pressure": max(0, int(value.get("pressure", 0))) if value is Dictionary else 0,
		"last_event_day": max(0, int(value.get("last_event_day", 0))) if value is Dictionary else 0,
		"source": String(value.get("source", "")) if value is Dictionary else "",
	}

static func _normalize_town_occupation_state(value: Variant) -> Dictionary:
	return {
		"state": String(value.get("state", "")) if value is Dictionary else "",
		"faction_id": String(value.get("faction_id", "")) if value is Dictionary else "",
		"pressure": max(0, int(value.get("pressure", 0))) if value is Dictionary else 0,
		"initial_pressure": max(0, int(value.get("initial_pressure", 0))) if value is Dictionary else 0,
		"start_day": max(0, int(value.get("start_day", 0))) if value is Dictionary else 0,
		"last_event_day": max(0, int(value.get("last_event_day", 0))) if value is Dictionary else 0,
		"last_owner": String(value.get("last_owner", "")) if value is Dictionary else "",
		"source": String(value.get("source", "")) if value is Dictionary else "",
		"locked_recruits": _normalize_recruit_payload(value.get("locked_recruits", {})) if value is Dictionary else {},
	}

static func _normalize_town_front_state(value: Variant) -> Dictionary:
	return {
		"state": String(value.get("state", "")) if value is Dictionary else "",
		"faction_id": String(value.get("faction_id", "")) if value is Dictionary else "",
		"last_change_day": max(0, int(value.get("last_change_day", 0))) if value is Dictionary else 0,
		"stabilize_until_day": max(0, int(value.get("stabilize_until_day", 0))) if value is Dictionary else 0,
		"last_owner": String(value.get("last_owner", "")) if value is Dictionary else "",
		"capture_count": max(0, int(value.get("capture_count", 0))) if value is Dictionary else 0,
		"source": String(value.get("source", "")) if value is Dictionary else "",
	}

static func _town_occupation_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	var faction_id := String(occupation.get("faction_id", ""))
	var pressure: int = max(0, int(occupation.get("pressure", 0)))
	var result := {
		"active": false,
		"mode": "",
		"faction_id": faction_id,
		"enemy_label": String(ContentService.get_faction(faction_id).get("name", faction_id)) if faction_id != "" else "",
		"pressure": pressure,
		"initial_pressure": max(pressure, int(occupation.get("initial_pressure", 0))),
		"days_active": 0,
		"relief_per_day": 0,
		"days_to_clear": 0,
		"income_penalty_percent": 0,
		"growth_penalty_percent": 0,
		"quality_penalty": 0,
		"readiness_penalty": 0,
		"pressure_penalty": 0,
		"locked_recruits": _normalize_recruit_payload(occupation.get("locked_recruits", {})),
		"locked_headcount": 0,
		"summary": "",
		"compact_summary": "",
		"public_clause": "",
		"target_bonus": 0,
		"state": occupation,
	}
	result["locked_headcount"] = _recruit_payload_total(result.get("locked_recruits", {}))
	if session == null:
		return result
	if String(town.get("owner", "neutral")) != "player":
		return result
	if String(occupation.get("state", "")) != "pacifying" or faction_id == "" or pressure <= 0:
		return result
	var logistics := _town_logistics_state(session, town)
	var recovery := _town_recovery_state(session, town)
	var front := _town_occupation_front_proxy(session, town, faction_id)
	var front_active := bool(front.get("active", false)) and String(front.get("faction_id", "")) == faction_id
	var relief_per_day := _town_occupation_relief_per_day(session, town, logistics, recovery, front)
	var days_to_clear := int(ceil(float(pressure) / float(max(1, relief_per_day))))
	var income_penalty := clampi(
		18 + (pressure * 8) + (int(logistics.get("support_gap", 0)) * 6) + (10 if front_active else 0),
		20,
		75
	)
	var growth_penalty := clampi(
		12 + (pressure * 9) + (int(logistics.get("support_gap", 0)) * 5) + (int(recovery.get("pressure", 0)) * 6),
		15,
		80
	)
	var quality_penalty: int = (pressure * 3) + (int(logistics.get("support_gap", 0)) * 2) + (6 if front_active else 0)
	var readiness_penalty: int = (pressure * 4) + (int(logistics.get("support_gap", 0)) * 3) + (8 if front_active else 0)
	var pressure_penalty: int = max(1, int(ceil(float(quality_penalty) / 5.0)))
	var locked_headcount := int(result.get("locked_headcount", 0))
	var reserve_clause := (
		"%d held levy%s" % [locked_headcount, "" if locked_headcount == 1 else "ies"]
		if locked_headcount > 0
		else "musters still sorting under occupation orders"
	)
	result["active"] = true
	result["mode"] = "pacifying"
	result["days_active"] = max(0, session.day - int(occupation.get("start_day", session.day)))
	result["relief_per_day"] = relief_per_day
	result["days_to_clear"] = days_to_clear
	result["income_penalty_percent"] = income_penalty
	result["growth_penalty_percent"] = growth_penalty
	result["quality_penalty"] = quality_penalty
	result["readiness_penalty"] = readiness_penalty
	result["pressure_penalty"] = pressure_penalty
	result["summary"] = "%s remains under pacification for %d day%s | income -%d%% | %s." % [
		_town_name(town),
		days_to_clear,
		"" if days_to_clear == 1 else "s",
		income_penalty,
		reserve_clause,
	]
	result["compact_summary"] = "%s pacifies in %d day%s" % [
		_town_name(town),
		days_to_clear,
		"" if days_to_clear == 1 else "s",
	]
	result["public_clause"] = "occupation still thins the local musters and tax roads"
	result["target_bonus"] = (pressure * 12) + (locked_headcount * 2) + (int(logistics.get("support_gap", 0)) * 10) + (18 if front_active else 0)
	return result

static func _town_occupation_front_proxy(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_id: String
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	front = _retake_front_from_legacy_state(session, town, front)
	var front_faction_id := _normalized_enemy_front_faction_id(session, front, town)
	var active := (
		String(town.get("owner", "neutral")) == "player"
		and String(front.get("state", "")) == "retake"
		and front_faction_id != ""
		and front_faction_id == faction_id
	)
	return {
		"active": active,
		"mode": "retake" if active else "",
		"faction_id": front_faction_id,
	}

static func _town_front_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	front = _retake_front_from_legacy_state(session, town, front)
	var faction_id := _normalized_enemy_front_faction_id(session, front, town)
	var state_id := String(front.get("state", ""))
	var owner := String(town.get("owner", "neutral"))
	var objective_anchor := _town_is_objective_anchor(session, String(town.get("placement_id", "")))
	var role := _town_strategic_role(town)
	var enemy_label := String(ContentService.get_faction(faction_id).get("name", faction_id)) if faction_id != "" else ""
	var logistics := _town_logistics_state(session, town)
	var recovery := _town_recovery_state(session, town)
	var capital_project := _town_capital_project_state(town, session)
	var base_priority := _town_front_priority_seed(role, objective_anchor)
	var result := {
		"active": false,
		"mode": "",
		"faction_id": faction_id,
		"enemy_label": enemy_label,
		"priority_bonus": 0,
		"pressure_bonus": 0,
		"threshold_reduction": 0,
		"garrison_bonus": 0,
		"build_bonus": 0,
		"days_since_change": max(0, session.day - int(front.get("last_change_day", 0))) if session != null else 0,
		"days_remaining": 0,
		"summary": "",
		"compact_summary": "",
		"public_clause": "",
		"state": front,
	}
	if faction_id == "":
		return result
	match state_id:
		"retake":
			if owner != "player":
				return result
			var recency_bonus: int = max(0, 54 - (int(result.get("days_since_change", 0)) * 8))
			var weakness_bonus: int = max(0, 34 - _town_battle_readiness(town, session))
			weakness_bonus += int(recovery.get("pressure", 0)) * 8
			weakness_bonus += int(logistics.get("support_gap", 0)) * 14
			if bool(capital_project.get("vulnerable", false)):
				weakness_bonus += 18
			var priority_bonus: int = base_priority + recency_bonus + weakness_bonus
			var threshold_reduction: int = 1 if priority_bonus >= 140 else 0
			if role == "capital" or objective_anchor:
				threshold_reduction += 1
			result["active"] = true
			result["mode"] = "retake"
			result["priority_bonus"] = priority_bonus
			result["pressure_bonus"] = clampi(int(floor(float(priority_bonus) / 115.0)), 1, 4)
			result["threshold_reduction"] = clampi(threshold_reduction, 0, 2)
			result["summary"] = "%s still treats %s as a retake front." % [enemy_label, _town_name(town)]
			result["compact_summary"] = "retake %s" % _town_name(town)
			result["public_clause"] = "retake orders still center on the lost town"
			return result
		"stabilizing":
			if owner != "enemy":
				return result
			var stabilize_until_day: int = int(front.get("stabilize_until_day", 0))
			var days_remaining: int = max(0, stabilize_until_day - int(session.day) + 1) if session != null else 0
			if days_remaining <= 0 and not bool(recovery.get("active", false)):
				return result
			var pressure_bonus: int = int(recovery.get("pressure", 0)) * 10
			pressure_bonus += int(logistics.get("support_gap", 0)) * 14
			pressure_bonus += int(logistics.get("threatened_count", 0)) * 8
			pressure_bonus += max(0, days_remaining - 1) * 12
			if bool(capital_project.get("vulnerable", false)):
				pressure_bonus += 14
			result["active"] = true
			result["mode"] = "stabilizing"
			result["days_remaining"] = days_remaining
			result["priority_bonus"] = base_priority + pressure_bonus
			result["garrison_bonus"] = 65 + pressure_bonus
			result["build_bonus"] = 45 + int(recovery.get("pressure", 0)) * 10 + max(0, days_remaining - 1) * 8
			result["summary"] = "%s is still stabilizing %s." % [enemy_label, _town_name(town)]
			result["compact_summary"] = "stabilize %s" % _town_name(town)
			result["public_clause"] = (
				"the reclaimed walls stay on stabilization orders for %d day%s"
				% [days_remaining, "" if days_remaining == 1 else "s"]
				if days_remaining > 0
				else "the reclaimed walls are still being stabilized"
			)
			return result
		_:
			return result

static func _normalized_enemy_front_faction_id(
	session: SessionStateStoreScript.SessionData,
	front: Dictionary,
	town: Dictionary
) -> String:
	var faction_id := String(front.get("faction_id", ""))
	if faction_id != "" and not _enemy_state_for_faction(session, faction_id).is_empty():
		return faction_id
	var template_faction_id := _town_faction_id(town)
	if template_faction_id != "" and not _enemy_state_for_faction(session, template_faction_id).is_empty():
		return template_faction_id
	return ""

static func _retake_front_from_legacy_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	front: Dictionary
) -> Dictionary:
	if session == null or town.is_empty():
		return front
	if String(front.get("state", "")) != "":
		return front
	var placement_id := String(town.get("placement_id", ""))
	if String(town.get("owner", "neutral")) != "player" or not _scenario_town_started_enemy(session, placement_id):
		return front
	var faction_id := _town_faction_id(town)
	if faction_id == "" or _enemy_state_for_faction(session, faction_id).is_empty():
		return front
	var inferred := front.duplicate(true)
	inferred["state"] = "retake"
	inferred["faction_id"] = faction_id
	inferred["last_change_day"] = max(
		0,
		int(_normalize_town_recovery_state(town.get("recovery", {})).get("last_event_day", session.day))
	)
	inferred["last_owner"] = "enemy"
	inferred["capture_count"] = max(1, int(inferred.get("capture_count", 0)))
	return inferred

static func _town_front_after_control_change(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	previous_owner: String,
	new_owner: String,
	controlling_faction_id: String,
	source: String
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	var faction_id := controlling_faction_id
	if faction_id == "" and previous_owner == "enemy":
		faction_id = _normalized_enemy_front_faction_id(session, front, town)
	if faction_id == "" and new_owner == "enemy":
		faction_id = _normalized_enemy_front_faction_id(session, front, town)
	if previous_owner == new_owner:
		if new_owner == "enemy" and faction_id != "":
			return _town_front_stabilizing_state(session, town, faction_id, source)
		return front
	if new_owner == "player":
		if faction_id == "":
			return _normalize_town_front_state({})
		front["state"] = "retake"
		front["faction_id"] = faction_id
		front["last_change_day"] = int(session.day)
		front["stabilize_until_day"] = 0
		front["last_owner"] = previous_owner
		front["capture_count"] = max(1, int(front.get("capture_count", 0)) + 1)
		front["source"] = source
		return front
	if new_owner == "enemy":
		if faction_id == "":
			return _normalize_town_front_state({})
		return _town_front_stabilizing_state(session, town, faction_id, source, previous_owner)
	return _normalize_town_front_state({})

static func _town_front_stabilizing_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_id: String,
	source: String,
	previous_owner: String = "",
	bonus_days: int = 0
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	front["state"] = "stabilizing"
	front["faction_id"] = faction_id
	front["last_change_day"] = int(session.day) if session != null else int(front.get("last_change_day", 0))
	front["stabilize_until_day"] = (
		int(session.day) + clampi(_town_front_stabilize_days(session, town) + max(0, bonus_days), 2, 8)
		if session != null
		else max(0, int(front.get("stabilize_until_day", 0)))
	)
	if previous_owner != "":
		front["last_owner"] = previous_owner
	front["capture_count"] = max(1, int(front.get("capture_count", 0)))
	front["source"] = source
	return front

static func _town_front_priority_seed(role: String, objective_anchor: bool) -> int:
	var priority := 88
	match role:
		"capital":
			priority += 92
		"stronghold":
			priority += 54
	if objective_anchor:
		priority += 30
	return priority

static func _town_front_stabilize_days(session: SessionStateStoreScript.SessionData, town: Dictionary) -> int:
	var days := 2
	match _town_strategic_role(town):
		"capital":
			days += 2
		"stronghold":
			days += 1
	if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
		days += 1
	if bool(_town_recovery_state(session, town).get("active", false)):
		days += 1
	return clampi(days, 2, 6)

static func _town_occupation_relief_per_day(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	logistics: Dictionary = {},
	recovery: Dictionary = {},
	front: Dictionary = {}
) -> int:
	if session == null:
		return 1
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town)
	if front.is_empty():
		front = _town_front_state(session, town)
	var relief := 1 + int(floor(float(_town_recovery_relief_rating(session, town)) / 4.0))
	relief += min(2, int(logistics.get("met_requirements", 0)))
	relief -= int(logistics.get("support_gap", 0))
	if bool(recovery.get("active", false)):
		relief -= 1
	if bool(front.get("active", false)) and String(front.get("mode", "")) == "retake":
		relief -= 1
	return clampi(relief, 1, 4)

static func _town_occupation_after_control_change(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	previous_owner: String,
	new_owner: String,
	controlling_faction_id: String,
	source: String
) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	if previous_owner == new_owner:
		if new_owner != "player":
			return _normalize_town_occupation_state({})
		return occupation
	if new_owner != "player":
		return _normalize_town_occupation_state({})
	if previous_owner != "enemy":
		return _normalize_town_occupation_state({})
	var faction_id := controlling_faction_id
	if faction_id == "":
		faction_id = _town_faction_id(town)
	if faction_id == "":
		return _normalize_town_occupation_state({})
	var pressure := _town_occupation_seed_pressure(session, town)
	occupation["state"] = "pacifying"
	occupation["faction_id"] = faction_id
	occupation["pressure"] = pressure
	occupation["initial_pressure"] = pressure
	occupation["start_day"] = session.day if session != null else 0
	occupation["last_event_day"] = session.day if session != null else 0
	occupation["last_owner"] = previous_owner
	occupation["source"] = source
	occupation["locked_recruits"] = {}
	_lock_town_occupation_reserves(town, occupation)
	return occupation

static func _town_occupation_seed_pressure(session: SessionStateStoreScript.SessionData, town: Dictionary) -> int:
	var pressure := 3
	match _town_strategic_role(town):
		"capital":
			pressure += 4
		"stronghold":
			pressure += 2
		_:
			pressure += 1
	if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
		pressure += 1
	if _town_garrison_headcount(town) > 0:
		pressure += 1
	return clampi(pressure, 4, 10)

static func _lock_town_occupation_reserves(town: Dictionary, occupation: Dictionary) -> void:
	if town.is_empty():
		return
	var available := _normalize_recruit_payload(town.get("available_recruits", {}))
	if available.is_empty():
		occupation["locked_recruits"] = {}
		return
	var access_percent := clampi(80 - (int(occupation.get("initial_pressure", 0)) * 8), 20, 55)
	var accessible := {}
	var locked := {}
	for unit_id_value in available.keys():
		var unit_id := String(unit_id_value)
		var count: int = max(0, int(available.get(unit_id, 0)))
		if unit_id == "" or count <= 0:
			continue
		var released := int(floor(float(count) * float(access_percent) / 100.0))
		if released <= 0:
			released = 1
		released = clampi(released, 0, count)
		if released > 0:
			accessible[unit_id] = released
		if count > released:
			locked[unit_id] = count - released
	town["available_recruits"] = accessible
	occupation["locked_recruits"] = locked

static func _release_town_occupation_reserves(town: Dictionary) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	var locked := _normalize_recruit_payload(occupation.get("locked_recruits", {}))
	if locked.is_empty():
		town["occupation"] = _normalize_town_occupation_state({})
		return town
	town["available_recruits"] = _add_recruit_growth(town.get("available_recruits", {}), locked)
	town["occupation"] = _normalize_town_occupation_state({})
	return town

static func _town_recovery_relief_rating(session: SessionStateStoreScript.SessionData, town: Dictionary) -> int:
	var relief := int(_town_logistics_plan(town).get("recovery_relief", 0))
	var logistics := _town_logistics_state(session, town)
	relief += _town_building_bonus_total(town, "recovery_relief")
	relief += int(logistics.get("recovery_relief_bonus", 0))
	relief += int(logistics.get("response_recovery_relief_bonus", 0))
	relief += _town_capital_project_recovery_relief(town)
	return max(0, relief)

static func _town_capital_project_recovery_relief(town: Dictionary) -> int:
	var total := 0
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		var capital_project = ContentService.get_building(String(building_id_value)).get("capital_project", {})
		if capital_project is Dictionary:
			total += max(0, int(capital_project.get("recovery_guard", 0)))
	return total

static func _project_dependency_ids(project_id: String) -> Array:
	var dependency_ids := []
	var building := ContentService.get_building(project_id)
	if building.is_empty():
		return dependency_ids
	for dependency_id_value in building.get("requires", []):
		var dependency_id := String(dependency_id_value)
		if dependency_id != "" and dependency_id not in dependency_ids:
			dependency_ids.append(dependency_id)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and upgrade_from not in dependency_ids:
		dependency_ids.append(upgrade_from)
	return dependency_ids

static func _blank_project_vulnerability_penalties() -> Dictionary:
	return {
		"quality_penalty": 0,
		"readiness_penalty": 0,
		"pressure_penalty": 0,
		"growth_penalty_percent": 0,
	}

static func _resource_site_town_support(site: Dictionary) -> Dictionary:
	var support := {
		"quality_bonus": 0,
		"readiness_bonus": 0,
		"pressure_bonus": 0,
		"growth_bonus_percent": 0,
		"recovery_relief": 0,
		"disruption_pressure": 0,
	}
	var authored_support = site.get("town_support", {})
	if authored_support is Dictionary and not authored_support.is_empty():
		for key in support.keys():
			support[key] = max(0, int(authored_support.get(key, support[key])))
		return support
	match String(site.get("family", "")):
		"mine":
			support["growth_bonus_percent"] = 3
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"neutral_dwelling":
			support["quality_bonus"] = max(2, int(round(float(_weighted_recruit_value(_resource_site_weekly_recruits(site))) / 28.0)))
			support["growth_bonus_percent"] = 12
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"faction_outpost":
			support["readiness_bonus"] = max(2, max(0, int(site.get("vision_radius", 0))) * 2)
			support["pressure_bonus"] = max(0, int(site.get("pressure_bonus", 0)))
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"frontier_shrine":
			support["quality_bonus"] = 2
			support["pressure_bonus"] = 1
			support["growth_bonus_percent"] = 6
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"scouting_structure":
			support["readiness_bonus"] = max(1, max(0, int(site.get("vision_radius", 0))))
			support["pressure_bonus"] = 1
			support["disruption_pressure"] = 1
		"transit_object":
			support["readiness_bonus"] = 1
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"repeatable_service":
			support["recovery_relief"] = 1
	return support

static func _resource_site_under_threat(session: SessionStateStoreScript.SessionData, node: Dictionary, controller_id: String) -> bool:
	if session == null:
		return false
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var response_active := bool(_resource_site_response_state(session, node, site).get("active", false))
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if String(encounter.get("spawned_by_faction_id", "")) in ["", controller_id]:
			continue
		if String(encounter.get("target_kind", "")) == "resource" and String(encounter.get("target_placement_id", "")) == String(node.get("placement_id", "")):
			return true
		if response_active:
			continue
		var distance = abs(int(encounter.get("x", 0)) - int(node.get("x", 0))) + abs(int(encounter.get("y", 0)) - int(node.get("y", 0)))
		if distance <= 2 and (bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) <= 2):
			return true
	return false

static func _apply_recruit_percent(recruits: Variant, percent_modifier: int) -> Dictionary:
	var adjusted := {}
	if not (recruits is Dictionary):
		return adjusted
	for unit_id_value in recruits.keys():
		var unit_id := String(unit_id_value)
		var base_count = max(0, int(recruits.get(unit_id, 0)))
		if unit_id == "":
			continue
		if base_count <= 0:
			adjusted[unit_id] = 0
			continue
		adjusted[unit_id] = max(0, int(round(float(base_count) * max(0.0, float(100 + percent_modifier)) / 100.0)))
	return adjusted

static func _apply_resource_percent_scale(resources: Variant, percent: int) -> Dictionary:
	var scaled := _normalize_resource_dict(resources)
	var applied_percent: int = max(0, percent)
	for resource_id in scaled.keys():
		scaled[resource_id] = max(
			0,
			int(round(float(int(scaled.get(resource_id, 0))) * float(applied_percent) / 100.0))
		)
	return scaled

static func _resource_site_family_short_label(family_id: String) -> String:
	match family_id:
		"neutral_dwelling":
			return "dwelling"
		"faction_outpost":
			return "outpost"
		"frontier_shrine":
			return "shrine"
		_:
			return family_id

static func _town_response_panel_lines(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var lines := ["Strategic Response"]
	var logistics := _town_logistics_state(session, town)
	var recovery := _town_recovery_state(session, town)
	var capital_project := _town_capital_project_state(town, session)
	if bool(recovery.get("active", false)):
		lines.append("- Recovery %s" % String(recovery.get("summary", "")))
	else:
		lines.append("- Recovery steady | %d/day relief" % int(recovery.get("relief_per_day", 1)))
	lines.append("- Logistics %s" % String(logistics.get("summary", "No linked routes.")))
	if logistics.get("response_site_labels", []) is Array and not logistics.get("response_site_labels", []).is_empty():
		lines.append("- Active route orders: %s" % ", ".join(logistics.get("response_site_labels", [])))
	if logistics.get("delivery_site_labels", []) is Array and not logistics.get("delivery_site_labels", []).is_empty():
		lines.append("- Reserve deliveries: %s" % ", ".join(logistics.get("delivery_site_labels", [])))
	if logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
		lines.append("- Threat lanes: %s" % ", ".join(logistics.get("threatened_site_labels", [])))
	if logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
		lines.append("- Denied routes: %s" % ", ".join(logistics.get("disrupted_site_labels", [])))
	if bool(capital_project.get("vulnerable", false)):
		lines.append("- Capital project is vulnerable while chains stay cut or recovery pressure remains.")
	var action_count := _town_response_actions(session, town).size()
	if action_count > 0:
		lines.append("- %d active order%s ready. Response orders spend commander movement plus stores." % [action_count, "" if action_count == 1 else "s"])
	else:
		lines.append("- No immediate response order is ready. Reclaim denied sites or wait for new threat pressure.")
	return lines

static func _town_response_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var actions := []
	if session == null or town.is_empty() or String(town.get("owner", "neutral")) != "player":
		return actions
	var recovery := _town_recovery_state(session, town)
	var logistics := _town_logistics_state(session, town)
	var capital_project := _town_capital_project_state(town, session)
	var stabilize_profile := _town_recovery_stabilize_profile(town)
	var movement_left := int(session.overworld.get("movement", {}).get("current", 0))
	if bool(recovery.get("active", false)):
		var stabilize_cost = stabilize_profile.get("resource_cost", {})
		var stabilize_readiness := town_cost_readiness(town, session.overworld.get("resources", {}), stabilize_cost)
		var stabilize_market_summary := ""
		if bool(stabilize_readiness.get("market_affordable", false)) and not bool(stabilize_readiness.get("direct_affordable", false)):
			stabilize_market_summary = _summarize_market_actions(stabilize_readiness.get("market_actions", []))
		actions.append(
			{
				"id": "stabilize_recovery",
				"label": String(stabilize_profile.get("label", "Stabilize Recovery")),
				"summary": "%s | %s | Cost %s | Move -%d" % [
					String(stabilize_profile.get("summary", "Push reserve labor back onto the damaged line.")),
					"Recovery -%d" % int(stabilize_profile.get("relief_amount", 1)),
					_describe_resource_delta(stabilize_cost),
					int(stabilize_profile.get("movement_cost", 0)),
				],
				"disabled": (not _can_afford(session, stabilize_cost)) or movement_left < int(stabilize_profile.get("movement_cost", 0)),
				"resource_cost": stabilize_cost,
				"movement_cost": int(stabilize_profile.get("movement_cost", 0)),
				"remaining_movement_after_order": max(0, movement_left - int(stabilize_profile.get("movement_cost", 0))),
				"market_coverable": bool(stabilize_readiness.get("market_affordable", false)) and not bool(stabilize_readiness.get("direct_affordable", false)),
				"market_summary": stabilize_market_summary,
				"resource_blocked": not bool(stabilize_readiness.get("direct_affordable", false)),
				"movement_blocked": movement_left < int(stabilize_profile.get("movement_cost", 0)),
			}
		)

	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or String(node.get("collected_by_faction_id", "")) != "player":
			continue
		var linked_town_result := _resource_node_linked_town(session, node, "player")
		if String(linked_town_result.get("town", {}).get("placement_id", "")) != String(town.get("placement_id", "")):
			continue
		var response_state := _resource_site_response_state(session, node, site)
		if int(response_state.get("watch_days", 0)) <= 0 or bool(response_state.get("active", false)):
			continue
		var threatened := _resource_site_under_threat(session, node, "player")
		if not threatened and not bool(recovery.get("active", false)) and int(logistics.get("support_gap", 0)) <= 0 and not bool(capital_project.get("vulnerable", false)):
			continue
		var cost = response_state.get("resource_cost", {})
		var readiness := town_cost_readiness(town, session.overworld.get("resources", {}), cost)
		var market_summary := ""
		if bool(readiness.get("market_affordable", false)) and not bool(readiness.get("direct_affordable", false)):
			market_summary = _summarize_market_actions(readiness.get("market_actions", []))
		var delivery_plan := _player_reserve_delivery_plan(session, town, response_state)
		var delivery_summary := ""
		if not delivery_plan.is_empty():
			delivery_summary = "Load %s for %s (%d day%s)" % [
				_describe_recruit_delta(delivery_plan.get("manifest", {})),
				String(delivery_plan.get("target_label", "the front")),
				int(delivery_plan.get("eta_days", 1)),
				"" if int(delivery_plan.get("eta_days", 1)) == 1 else "s",
			]
		var site_summary_parts := [
			String(response_state.get("summary", "")),
			"Site %s" % String(site.get("name", "Frontier site")),
		]
		if delivery_summary != "":
			site_summary_parts.append(delivery_summary)
		var impact_summary := _resource_site_response_effect_summary(response_state)
		if impact_summary != "":
			site_summary_parts.append(impact_summary)
		var cost_summary := _describe_resource_delta(cost)
		if cost_summary != "":
			site_summary_parts.append("Cost %s" % cost_summary)
		site_summary_parts.append("Move -%d" % int(response_state.get("movement_cost", 0)))
		site_summary_parts.append("%d day%s" % [
			int(response_state.get("watch_days", 0)),
			"" if int(response_state.get("watch_days", 0)) == 1 else "s",
		])
		actions.append(
			{
				"id": "site_response:%s" % String(node.get("placement_id", "")),
				"label": "%s: %s" % [String(response_state.get("action_label", "Secure Route")), String(site.get("name", "Frontier site"))],
				"summary": " | ".join(site_summary_parts),
				"disabled": (not _can_afford(session, cost)) or movement_left < int(response_state.get("movement_cost", 0)),
				"resource_cost": cost,
				"movement_cost": int(response_state.get("movement_cost", 0)),
				"remaining_movement_after_order": max(0, movement_left - int(response_state.get("movement_cost", 0))),
				"market_coverable": bool(readiness.get("market_affordable", false)) and not bool(readiness.get("direct_affordable", false)),
				"market_summary": market_summary,
				"delivery_summary": delivery_summary,
				"resource_blocked": not bool(readiness.get("direct_affordable", false)),
				"movement_blocked": movement_left < int(response_state.get("movement_cost", 0)),
			}
		)
	return actions

static func _execute_town_response_action(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	action_id: String
) -> Dictionary:
	if session == null or town.is_empty():
		return {"ok": false, "message": "No town is available for strategic response orders."}
	if action_id == "stabilize_recovery":
		return _stabilize_town_recovery(session, town)
	if action_id.begins_with("site_response:"):
		var placement_id := action_id.trim_prefix("site_response:")
		var node_result := _find_resource_node_by_placement(session, placement_id)
		if int(node_result.get("index", -1)) < 0:
			return {"ok": false, "message": "That route order no longer has a valid site."}
		var linked_town_result := _resource_node_linked_town(session, node_result.get("node", {}), "player")
		if String(linked_town_result.get("town", {}).get("placement_id", "")) != String(town.get("placement_id", "")):
			return {"ok": false, "message": "That site is no longer linked to %s." % _town_name(town)}
		return _issue_resource_site_response(session, placement_id, "town")
	return {"ok": false, "message": "That response order is not recognized."}

static func _town_recovery_stabilize_profile(town: Dictionary) -> Dictionary:
	match _town_strategic_role(town):
		"capital":
			return {
				"label": "Stabilize Recovery",
				"summary": "Pull charter labor, reserve wagons, and watch captains back onto the damaged line.",
				"movement_cost": 4,
				"resource_cost": {"gold": 220, "wood": 1, "ore": 1},
				"relief_amount": 2,
			}
		"stronghold":
			return {
				"label": "Stabilize Recovery",
				"summary": "Cycle garrison crews and line labor to steady the battered approaches.",
				"movement_cost": 3,
				"resource_cost": {"gold": 170, "wood": 1},
				"relief_amount": 1,
			}
		_:
			return {
				"label": "Stabilize Recovery",
				"summary": "Push local labor and reserve stores back into the town's damaged routes.",
				"movement_cost": 2,
				"resource_cost": {"gold": 140},
				"relief_amount": 1,
			}

static func _stabilize_town_recovery(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var recovery := _town_recovery_state(session, town)
	if not bool(recovery.get("active", false)):
		return {"ok": false, "message": "%s has no active recovery pressure." % _town_name(town)}
	var profile := _town_recovery_stabilize_profile(town)
	var cost = profile.get("resource_cost", {})
	if not _can_afford(session, cost):
		return {"ok": false, "message": "Insufficient resources to stabilize %s." % _town_name(town)}
	var movement_result := HeroCommandRulesScript.spend_active_hero_movement(
		session,
		int(profile.get("movement_cost", 0)),
		"recovery stabilization"
	)
	if not bool(movement_result.get("ok", false)):
		return movement_result
	if cost is Dictionary and not cost.is_empty():
		_spend_resources(session, cost)
	var relief_message := relieve_town_recovery_pressure(
		session,
		String(town.get("placement_id", "")),
		int(profile.get("relief_amount", 1)),
		_town_name(town)
	)
	var messages := ["Ordered recovery stabilization in %s." % _town_name(town)]
	var cost_summary := _describe_resource_delta(cost)
	if cost_summary != "":
		messages.append("Spent %s." % cost_summary)
	if relief_message != "":
		messages.append(relief_message)
	return _finalize_action_result(session, true, " ".join(messages))

static func _town_market_panel_lines(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var state := _town_market_state(town)
	var lines := ["Exchange Hall"]
	if not bool(state.get("active", false)):
		lines.append("- No market square stands here. Build a market to liquidate spare stock or buy scarce wood and ore.")
		return lines
	var buy_rates: Dictionary = state.get("buy_rates", {})
	var sell_rates: Dictionary = state.get("sell_rates", {})
	lines.append(
		"- %s | Buy wood %d gold, ore %d gold | Sell wood %d gold, ore %d gold" % [
			String(state.get("building_name", "Market")),
			int(buy_rates.get("wood", 0)),
			int(buy_rates.get("ore", 0)),
			int(sell_rates.get("wood", 0)),
			int(sell_rates.get("ore", 0)),
		]
	)
	var specialty_summary := String(state.get("specialty_summary", ""))
	if specialty_summary != "":
		lines.append("- %s" % specialty_summary)
	var bulk_resource := String(state.get("bulk_resource", ""))
	var bulk_amount := int(state.get("bulk_amount", 0))
	if bulk_resource != "" and bulk_amount > 1:
		var bulk_buy := _market_quote_from_state(state, "buy", bulk_resource, bulk_amount)
		var bulk_sell := _market_quote_from_state(state, "sell", bulk_resource, bulk_amount)
		lines.append(
			"- Bulk %s lot: buy %d for %d gold or liquidate for %d gold" % [
				bulk_resource,
				bulk_amount,
				int(bulk_buy.get("gold_value", 0)),
				int(bulk_sell.get("gold_value", 0)),
			]
		)
	var action_count := _town_market_actions(session, town).size()
	lines.append("- %d exchange order%s ready." % [action_count, "" if action_count == 1 else "s"])
	return lines

static func _town_market_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var actions := []
	if session == null or town.is_empty() or String(town.get("owner", "neutral")) != "player":
		return actions
	var state := _town_market_state(town)
	if not bool(state.get("active", false)):
		return actions
	var resource_order := ["wood", "ore"]
	var bulk_resource := String(state.get("bulk_resource", ""))
	if bulk_resource != "" and bulk_resource in resource_order:
		resource_order.erase(bulk_resource)
		resource_order.push_front(bulk_resource)
	for resource_key in resource_order:
		for action_type in ["buy", "sell"]:
			var quote := _market_quote_from_state(state, action_type, resource_key, 1)
			if quote.is_empty():
				continue
			actions.append(_market_action_entry(session, state, quote))
	if bulk_resource != "" and int(state.get("bulk_amount", 0)) > 1:
		for action_type in ["buy", "sell"]:
			var bulk_quote := _market_quote_from_state(state, action_type, bulk_resource, int(state.get("bulk_amount", 0)))
			if bulk_quote.is_empty():
				continue
			actions.append(_market_action_entry(session, state, bulk_quote))
	return actions

static func _market_action_entry(session: SessionStateStoreScript.SessionData, state: Dictionary, quote: Dictionary) -> Dictionary:
	var action_type := String(quote.get("action_type", ""))
	var resource_key := String(quote.get("resource", ""))
	var amount := int(quote.get("amount", 0))
	var disabled := false
	var summary := "%s | %s | %s" % [
		String(quote.get("summary", "")),
		String(quote.get("rate_summary", "")),
		String(quote.get("building_summary", "")),
	]
	if action_type == "buy":
		disabled = not _can_afford(session, quote.get("cost", {}))
	else:
		disabled = not _can_afford(session, quote.get("cost", {}))
	return {
		"id": "market:%s:%s:%d" % [action_type, resource_key, amount],
		"label": "%s %d %s" % [
			"Buy" if action_type == "buy" else "Sell",
			amount,
			resource_key.capitalize(),
		],
		"summary": summary,
		"disabled": disabled,
	}

static func _execute_town_market_action(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	action_id: String
) -> Dictionary:
	if session == null or town.is_empty():
		return {"ok": false, "message": "No town is available for exchange orders."}
	var parts := action_id.split(":")
	if parts.size() != 4 or parts[0] != "market":
		return {"ok": false, "message": "That exchange order is invalid."}
	var action_type := String(parts[1])
	var resource_key := String(parts[2])
	var amount = max(0, int(parts[3]))
	var quote := _town_market_quote(town, action_type, resource_key, amount)
	if quote.is_empty():
		return {"ok": false, "message": "That exchange order is not available in %s." % _town_name(town)}
	var cost = quote.get("cost", {})
	if not _can_afford(session, cost):
		var verb := "buy" if action_type == "buy" else "sell"
		return {"ok": false, "message": "Insufficient reserves to %s through %s." % [verb, _town_name(town)]}
	_spend_resources(session, cost)
	_add_resources(session, quote.get("gain", {}))
	var amount_label := "%d %s" % [amount, resource_key]
	if action_type == "buy":
		return _finalize_action_result(
			session,
			true,
			"Bought %s in %s for %d gold through %s." % [
				amount_label,
				_town_name(town),
				int(quote.get("gold_value", 0)),
				String(quote.get("building_name", "the exchange")),
			]
		)
	return _finalize_action_result(
		session,
		true,
		"Sold %s in %s for %d gold through %s." % [
			amount_label,
			_town_name(town),
			int(quote.get("gold_value", 0)),
			String(quote.get("building_name", "the exchange")),
		]
	)

static func _town_market_state(town: Dictionary) -> Dictionary:
	var inactive := {
		"active": false,
		"tier": 0,
		"profile": "none",
		"building_id": "",
		"building_name": "",
		"buy_rates": {"wood": 0, "ore": 0},
		"sell_rates": {"wood": 0, "ore": 0},
		"bulk_resource": "",
		"bulk_amount": 0,
		"specialty_summary": "",
		"exchange_value": 0,
	}
	if town.is_empty():
		return inactive
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	var market_building_id := ""
	var profile_id := "none"
	var tier := 0
	if "building_resonant_exchange" in built_buildings:
		market_building_id = "building_resonant_exchange"
		profile_id = "resonant"
		tier = 2
	elif "building_river_granary_exchange" in built_buildings:
		market_building_id = "building_river_granary_exchange"
		profile_id = "river"
		tier = 2
	elif "building_market_square" in built_buildings:
		market_building_id = "building_market_square"
		profile_id = "square"
		tier = 1
	else:
		return inactive

	var market_building := ContentService.get_building(market_building_id)
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var buy_rates := {}
	var sell_rates := {}
	for resource_key in ["wood", "ore"]:
		var abundance := _market_resource_abundance_score(faction.get("economy", {}), town_template.get("economy", {}), resource_key)
		var buy_rate := 740 - (abundance * 35)
		var sell_rate := 280 + (abundance * 30)
		match profile_id:
			"river":
				if resource_key == "wood":
					buy_rate -= 80
					sell_rate += 90
				else:
					buy_rate -= 25
					sell_rate += 25
			"resonant":
				if resource_key == "ore":
					buy_rate -= 80
					sell_rate += 90
				else:
					buy_rate -= 25
					sell_rate += 25
			_:
				buy_rate -= 20
				sell_rate += 10
		buy_rate = clampi(buy_rate, 500, 760)
		sell_rate = clampi(sell_rate, 260, max(260, buy_rate - 120))
		buy_rates[resource_key] = buy_rate
		sell_rates[resource_key] = sell_rate
	var bulk_resource := ""
	var specialty_summary := "Standard brokers can move one crate at a time between raw stock and hard coin."
	if profile_id == "river":
		bulk_resource = "wood"
		specialty_summary = "River barges tighten wood rates and open double-wood convoy trades for construction or levy recovery."
	elif profile_id == "resonant":
		bulk_resource = "ore"
		specialty_summary = "Resonant relay brokers tighten ore rates and open double-ore lots for crystal feed and battery upkeep."
	var exchange_value := 0
	for resource_key in ["wood", "ore"]:
		exchange_value += int(sell_rates.get(resource_key, 0))
		exchange_value += max(0, 900 - int(buy_rates.get(resource_key, 0)))
	if bulk_resource != "":
		exchange_value += 120
	return {
		"active": true,
		"tier": tier,
		"profile": profile_id,
		"building_id": market_building_id,
		"building_name": String(market_building.get("name", market_building_id)),
		"buy_rates": buy_rates,
		"sell_rates": sell_rates,
		"bulk_resource": bulk_resource,
		"bulk_amount": 2 if bulk_resource != "" else 0,
		"specialty_summary": specialty_summary,
		"exchange_value": exchange_value,
	}

static func _market_resource_abundance_score(faction_economy: Variant, town_economy: Variant, resource_key: String) -> int:
	var score := 0
	var faction_base = faction_economy.get("base_income", {}) if faction_economy is Dictionary else {}
	var town_base = town_economy.get("base_income", {}) if town_economy is Dictionary else {}
	var faction_categories = faction_economy.get("per_category_income", {}) if faction_economy is Dictionary else {}
	var town_categories = town_economy.get("per_category_income", {}) if town_economy is Dictionary else {}
	var faction_economy_bucket = faction_categories.get("economy", {}) if faction_categories is Dictionary else {}
	var town_economy_bucket = town_categories.get("economy", {}) if town_categories is Dictionary else {}
	score += 1 if faction_base is Dictionary and int(faction_base.get(resource_key, 0)) > 0 else 0
	score += 1 if town_base is Dictionary and int(town_base.get(resource_key, 0)) > 0 else 0
	score += 1 if faction_economy_bucket is Dictionary and int(faction_economy_bucket.get(resource_key, 0)) > 0 else 0
	score += 1 if town_economy_bucket is Dictionary and int(town_economy_bucket.get(resource_key, 0)) > 0 else 0
	return score

static func _town_market_quote(town: Dictionary, action_type: String, resource_key: String, amount: int) -> Dictionary:
	return _market_quote_from_state(_town_market_state(town), action_type, resource_key, amount)

static func _market_quote_from_state(state: Dictionary, action_type: String, resource_key: String, amount: int) -> Dictionary:
	if not bool(state.get("active", false)):
		return {}
	if resource_key not in ["wood", "ore"]:
		return {}
	var normalized_amount = max(0, amount)
	if normalized_amount <= 0:
		return {}
	var rates: Dictionary = state.get("buy_rates", {}) if action_type == "buy" else state.get("sell_rates", {})
	var unit_rate := int(rates.get(resource_key, 0))
	if unit_rate <= 0:
		return {}
	var total_value = unit_rate * normalized_amount
	if normalized_amount > 1 and normalized_amount == int(state.get("bulk_amount", 0)) and String(state.get("bulk_resource", "")) == resource_key:
		if action_type == "buy":
			total_value = max(1, int(round(float(total_value) * 0.9)))
		else:
			total_value = max(1, int(round(float(total_value) * 1.1)))
	var cost := {}
	var gain := {}
	if action_type == "buy":
		cost["gold"] = total_value
		gain[resource_key] = normalized_amount
	else:
		cost[resource_key] = normalized_amount
		gain["gold"] = total_value
	var rate_summary := "%s %d gold per %s" % [
		"Pays" if action_type == "buy" else "Yields",
		int(round(float(total_value) / float(normalized_amount))),
		resource_key,
	]
	if normalized_amount > 1 and normalized_amount == int(state.get("bulk_amount", 0)) and String(state.get("bulk_resource", "")) == resource_key:
		rate_summary += " in bulk"
	var summary := ""
	if action_type == "buy":
		summary = "Pay %d gold for %d %s" % [total_value, normalized_amount, resource_key]
	else:
		summary = "Trade %d %s for %d gold" % [normalized_amount, resource_key, total_value]
	return {
		"action_type": action_type,
		"resource": resource_key,
		"amount": normalized_amount,
		"cost": cost,
		"gain": gain,
		"gold_value": total_value,
		"building_name": String(state.get("building_name", "Market")),
		"building_summary": String(state.get("specialty_summary", "")),
		"summary": summary,
		"rate_summary": rate_summary,
	}

static func _town_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant) -> Dictionary:
	var state := _town_market_state(town)
	var normalized_pool := _add_resource_sets({"gold": 0, "wood": 0, "ore": 0}, _normalize_resource_dict(pool))
	var normalized_cost := _add_resource_sets({"gold": 0, "wood": 0, "ore": 0}, _normalize_resource_dict(cost))
	var direct_affordable := _resource_pool_meets_cost(normalized_pool, normalized_cost)
	var market_active := bool(state.get("active", false))
	var direct_shortfall := _resource_pool_shortfall(normalized_pool, normalized_cost)
	if not bool(state.get("active", false)):
		return {
			"affordable": direct_affordable,
			"direct_affordable": direct_affordable,
			"market_affordable": direct_affordable,
			"market_active": market_active,
			"pool": normalized_pool,
			"cost": normalized_cost,
			"direct_shortfall": direct_shortfall,
			"liquidatable_gold": 0,
			"available_gold_total": int(normalized_pool.get("gold", 0)),
			"required_gold_total": int(normalized_cost.get("gold", 0)),
		}
	var required_gold_total := int(normalized_cost.get("gold", 0))
	var liquidatable_gold := 0
	for resource_key in ["wood", "ore"]:
		var required_amount := int(normalized_cost.get(resource_key, 0))
		var current_amount := int(normalized_pool.get(resource_key, 0))
		var deficit = max(0, required_amount - current_amount)
		var surplus = max(0, current_amount - required_amount)
		if deficit > 0:
			required_gold_total += deficit * int(state.get("buy_rates", {}).get(resource_key, 0))
		if surplus > 0:
			liquidatable_gold += surplus * int(state.get("sell_rates", {}).get(resource_key, 0))
	var available_gold_total := int(normalized_pool.get("gold", 0)) + liquidatable_gold
	var market_affordable := available_gold_total >= required_gold_total
	return {
		"affordable": market_affordable,
		"direct_affordable": direct_affordable,
		"market_affordable": market_affordable,
		"market_active": market_active,
		"pool": normalized_pool,
		"cost": normalized_cost,
		"direct_shortfall": direct_shortfall,
		"liquidatable_gold": liquidatable_gold,
		"available_gold_total": available_gold_total,
		"required_gold_total": required_gold_total,
	}

static func _apply_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant) -> Array:
	var coverage := _town_market_cost_coverage(town, pool, cost)
	if not bool(coverage.get("affordable", false)):
		return []
	var state := _town_market_state(town)
	if not bool(state.get("active", false)):
		return []
	var normalized_cost: Dictionary = coverage.get("cost", {})
	var required_gold_total := int(coverage.get("required_gold_total", 0))
	var actions := []
	var sell_order := ["wood", "ore"]
	sell_order.sort_custom(func(a: String, b: String) -> bool:
		return int(state.get("sell_rates", {}).get(a, 0)) > int(state.get("sell_rates", {}).get(b, 0))
	)
	for resource_key in sell_order:
		var surplus = max(0, int(pool.get(resource_key, 0)) - int(normalized_cost.get(resource_key, 0)))
		while int(pool.get("gold", 0)) < required_gold_total and surplus > 0:
			var sell_quote := _market_quote_from_state(state, "sell", resource_key, 1)
			if sell_quote.is_empty():
				break
			_apply_resource_transaction_to_pool(pool, sell_quote.get("cost", {}), sell_quote.get("gain", {}))
			surplus -= 1
			actions.append("%s sold 1 %s for %d gold" % [_town_name(town), resource_key, int(sell_quote.get("gold_value", 0))])
		if int(pool.get("gold", 0)) >= required_gold_total:
			break
	for resource_key in ["wood", "ore"]:
		var deficit = max(0, int(normalized_cost.get(resource_key, 0)) - int(pool.get(resource_key, 0)))
		while deficit > 0:
			var buy_quote := _market_quote_from_state(state, "buy", resource_key, 1)
			if buy_quote.is_empty() or int(pool.get("gold", 0)) < int(buy_quote.get("gold_value", 0)):
				return actions
			_apply_resource_transaction_to_pool(pool, buy_quote.get("cost", {}), buy_quote.get("gain", {}))
			deficit -= 1
			actions.append("%s bought 1 %s for %d gold" % [_town_name(town), resource_key, int(buy_quote.get("gold_value", 0))])
	return actions

static func _town_battlefront_profile(town: Dictionary) -> Dictionary:
	var role := _town_strategic_role(town)
	var faction_id := _town_faction_id(town)
	var capital_project := _town_capital_project_state(town)
	var project_active := bool(capital_project.get("active", false))
	var tags := []
	var label := ""
	var summary := ""
	match faction_id:
		"faction_embercourt":
			label = "Fortress lanes"
			tags.append("fortress_lane")
			summary = "Fortress lanes compress the approach and reward braced pike screens."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				summary = "Fortress lanes compress the approach while reserve columns harden the line after the first exchanges."
		"faction_mireclaw":
			label = "Wall pressure"
			tags.append("wall_pressure")
			summary = "Flooded breach lanes reward late pack surges once the first wall break opens."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("bog_channels")
				summary = "Flooded breach lanes and reserve packs turn a stalled assault into a late marsh surge."
		"faction_sunvault":
			label = "Battery nests"
			tags.append("battery_nest")
			summary = "Battery nests lengthen the approach and reward shielded relay fire."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("elevated_fire")
				summary = "Battery nests lengthen the approach while reserve crews rotate fresh arrays into the line."
		"faction_thornwake":
			label = "Rooted roads"
			tags.append("chokepoint")
			summary = "Rooted roads slow the approach and reward bramble-backed holding actions."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("ambush_cover")
				summary = "Rooted roads and nursery reserves make every breach a slow recovery fight."
		"faction_brasshollow":
			label = "Siege stages"
			tags.append("fortress_lane")
			summary = "Siege stages compress the approach around armor, heat, and engine setup."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("wall_pressure")
				summary = "Siege stages and foundry reserves turn the town front into a pressure-engine kill lane."
		"faction_veilmourn":
			label = "Fog lanes"
			tags.append("fog_bank")
			summary = "Fog lanes break clean approaches and reward marked, isolated attackers."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("ambush_cover")
				summary = "Fog lanes and black-sail reserves let defenders slip behind a stalled assault."
	if role == "capital" and "reserve_wave" not in tags:
		tags.append("reserve_wave")
	elif role == "stronghold" and project_active and "reserve_wave" not in tags:
		tags.append("reserve_wave")
	var normalized_tags := []
	for tag_id in tags:
		if tag_id != "" and tag_id not in normalized_tags:
			normalized_tags.append(tag_id)
	return {
		"role": role,
		"faction_id": faction_id,
		"project_active": project_active,
		"label": label,
		"summary": summary,
		"tags": normalized_tags,
	}

static func _town_capital_project_ids(town: Dictionary) -> Array:
	var ids := []
	var template := ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id == "":
			continue
		if ContentService.get_building(building_id).get("capital_project", {}) is Dictionary:
			ids.append(building_id)
	return ids

static func _town_role_quality_bonus(role: String) -> int:
	match role:
		"capital":
			return 10
		"stronghold":
			return 5
		_:
			return 0

static func _town_role_readiness_bonus(role: String) -> int:
	match role:
		"capital":
			return 12
		"stronghold":
			return 6
		_:
			return 0

static func _town_role_pressure_bonus(role: String) -> int:
	match role:
		"capital":
			return 1
		"stronghold":
			return 1
		_:
			return 0

static func _building_growth_payload(building_id: String) -> Dictionary:
	var building := ContentService.get_building(building_id)
	var payload := {}
	var unlock_unit_id := String(building.get("unlock_unit_id", ""))
	if unlock_unit_id != "":
		payload[unlock_unit_id] = _scenario_unit_growth(unlock_unit_id)
	var growth_bonus = building.get("growth_bonus", {})
	if growth_bonus is Dictionary:
		for unit_id in growth_bonus.keys():
			payload[String(unit_id)] = int(payload.get(String(unit_id), 0)) + int(growth_bonus[unit_id])
	return payload

static func _add_recruit_growth(base_recruits: Variant, delta_recruits: Variant) -> Dictionary:
	var merged := {}
	if base_recruits is Dictionary:
		for unit_id in base_recruits.keys():
			merged[String(unit_id)] = max(0, int(base_recruits[unit_id]))
	if delta_recruits is Dictionary:
		for unit_id in delta_recruits.keys():
			merged[String(unit_id)] = int(merged.get(String(unit_id), 0)) + max(0, int(delta_recruits[unit_id]))
	return merged

static func _weighted_recruit_value(recruits: Variant) -> int:
	var total := 0
	if not (recruits is Dictionary):
		return total
	for unit_id_value in recruits.keys():
		var unit_id := String(unit_id_value)
		var count = max(0, int(recruits[unit_id_value]))
		if unit_id == "" or count <= 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		var tier = max(1, int(unit.get("tier", 1)))
		total += count * (4 + (tier * 3))
		total += count * max(0, int(unit.get("attack", 0)) + int(unit.get("defense", 0)) - 6)
		if bool(unit.get("ranged", false)):
			total += count
	return total

static func _award_experience(session: SessionStateStoreScript.SessionData, amount: int) -> Array:
	if amount <= 0:
		return []

	var previous_movement_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var previous_mana_max := int(session.overworld.get("hero", {}).get("spellbook", {}).get("mana", {}).get("max", SpellRulesScript.mana_max_from_hero(session.overworld.get("hero", {}))))
	var result := HeroProgressionRulesScript.add_experience(session.overworld.get("hero", {}), amount)
	session.overworld["hero"] = ArtifactRulesScript.ensure_hero_artifacts(
		SpellRulesScript.ensure_hero_spellbook(result.get("hero", session.overworld.get("hero", {})))
	)
	_sync_movement_to_hero(session, previous_movement_max)
	_sync_spellbook_to_hero(session, previous_mana_max)
	return result.get("messages", [])

static func _town_name(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("name", town.get("town_id", "Town")))

static func _town_faction_id(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("faction_id", ""))

static func _normalize_built_buildings_for_town_state(town: Dictionary) -> Array:
	var normalized := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in town_template.get("starting_building_ids", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	for building_id_value in town.get("built_buildings", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	return normalized

static func _append_building_with_requirements(target: Array, building_id: String, trail: Array = []) -> void:
	if building_id == "" or building_id in target or building_id in trail:
		return
	var next_trail := trail.duplicate(true)
	next_trail.append(building_id)
	var building := ContentService.get_building(building_id)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		_append_building_with_requirements(target, upgrade_from, next_trail)
	for requirement_value in building.get("requires", []):
		_append_building_with_requirements(target, String(requirement_value), next_trail)
	target.append(building_id)

static func _economy_profile_income(profile: Variant, built_buildings: Array) -> Dictionary:
	var income := {"gold": 0, "wood": 0, "ore": 0}
	if not (profile is Dictionary):
		return income
	income = _add_resource_sets(income, profile.get("base_income", {}))
	var per_category_income = profile.get("per_category_income", {})
	if not (per_category_income is Dictionary):
		return income
	var category_counts := _building_category_counts(built_buildings)
	for category_value in per_category_income.keys():
		var category := String(category_value)
		income = _add_resource_sets(
			income,
			_multiply_cost(per_category_income[category], int(category_counts.get(category, 0)))
		)
	return income

static func _pressure_bonus_from_profile(profile: Variant) -> int:
	if not (profile is Dictionary):
		return 0
	return max(0, int(profile.get("pressure_bonus", 0)))

static func _readiness_bonus_from_profile(profile: Variant) -> int:
	if not (profile is Dictionary):
		return 0
	return max(0, int(profile.get("readiness_bonus", 0)))

static func _building_category_counts(built_buildings: Array) -> Dictionary:
	var counts := {}
	for category in BUILDING_CATEGORIES:
		counts[category] = 0
	for building_id_value in built_buildings:
		var category := _building_category(String(building_id_value))
		counts[category] = int(counts.get(category, 0)) + 1
	return counts

static func _building_category(building_id: String) -> String:
	var category := String(ContentService.get_building(building_id).get("category", "support"))
	return category if category in BUILDING_CATEGORIES else "support"

static func _town_building_bonus_total(town: Dictionary, key: String) -> int:
	var total := 0
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		total += max(0, int(ContentService.get_building(String(building_id_value)).get(key, 0)))
	return total

static func _town_spell_tier(town: Dictionary) -> int:
	var max_tier := 0
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		max_tier = max(max_tier, int(ContentService.get_building(String(building_id_value)).get("spell_tier", 0)))
	return max_tier

static func _town_garrison_strength(town: Dictionary) -> int:
	var total_strength := 0
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		var count = max(0, int(stack.get("count", 0)))
		total_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total_strength

static func _town_pressure_label(town: Dictionary) -> String:
	match _town_faction_id(town):
		"faction_embercourt":
			return "Frontier leverage"
		"faction_mireclaw":
			return "Raid pressure"
		"faction_sunvault":
			return "Relay reach"
		"faction_thornwake":
			return "Root pressure"
		"faction_brasshollow":
			return "Siege pressure"
		"faction_veilmourn":
			return "Fog pressure"
		_:
			return "Pressure"

static func _missing_build_requirements(building: Dictionary, built_buildings: Variant) -> Array:
	var missing := []
	if not (built_buildings is Array):
		return missing
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and upgrade_from not in built_buildings:
		missing.append(upgrade_from)
	for requirement_value in building.get("requires", []):
		var requirement := String(requirement_value)
		if requirement == "" or requirement in built_buildings or requirement in missing:
			continue
		missing.append(requirement)
	return missing

static func _requirements_met(building: Dictionary, built_buildings: Variant) -> bool:
	return _missing_build_requirements(building, built_buildings).is_empty()

static func _can_afford(session: SessionStateStoreScript.SessionData, cost: Variant) -> bool:
	var resources = session.overworld.get("resources", {})
	if not (cost is Dictionary):
		return true
	for key in cost.keys():
		if int(resources.get(String(key), 0)) < int(cost[key]):
			return false
	return true

static func _max_affordable_count(session: SessionStateStoreScript.SessionData, unit_cost: Variant) -> int:
	if not (unit_cost is Dictionary) or unit_cost.is_empty():
		return 999
	var resources = session.overworld.get("resources", {})
	var max_affordable := 999
	for key in unit_cost.keys():
			var price = max(1, int(unit_cost[key]))
			max_affordable = min(max_affordable, int(int(resources.get(String(key), 0)) / price))
	return max_affordable

static func _resource_pool_meets_cost(pool: Dictionary, cost: Dictionary) -> bool:
	for resource_key in ["gold", "wood", "ore"]:
		if int(pool.get(resource_key, 0)) < int(cost.get(resource_key, 0)):
			return false
	return true

static func _resource_pool_shortfall(pool: Dictionary, cost: Dictionary) -> Dictionary:
	var shortfall := {}
	for resource_key in ["gold", "wood", "ore"]:
		var missing = max(0, int(cost.get(resource_key, 0)) - int(pool.get(resource_key, 0)))
		if missing > 0:
			shortfall[resource_key] = missing
	return shortfall

static func _multiply_cost(cost: Variant, multiplier: int) -> Dictionary:
	var scaled := {}
	if cost is Dictionary:
		for key in cost.keys():
			scaled[String(key)] = int(cost[key]) * multiplier
	return scaled

static func _apply_percent_discount(cost: Variant, discount_percent: int) -> Dictionary:
	var discounted := {}
	var clamped_discount = clamp(discount_percent, 0, 75)
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key := String(key)
			var base_amount = max(0, int(cost[key]))
			discounted[resource_key] = int(ceili(float(base_amount * (100 - clamped_discount)) / 100.0))
	return discounted

static func _recruitment_discount_percent(town: Dictionary, unit_id: String) -> int:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var total_discount := _cost_discount_from_profile(town_template.get("recruitment", {}), unit_id)
	total_discount += _cost_discount_from_profile(
		ContentService.get_faction(String(town_template.get("faction_id", ""))).get("recruitment", {}),
		unit_id
	)
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		var building := ContentService.get_building(String(building_id_value))
		var building_discount = building.get("recruitment_discount_percent", {})
		if building_discount is Dictionary:
			total_discount += int(building_discount.get(unit_id, 0))
	return total_discount

static func _cost_discount_from_profile(profile: Variant, unit_id: String) -> int:
	if not (profile is Dictionary):
		return 0
	var discounts = profile.get("cost_discount_percent", {})
	if not (discounts is Dictionary):
		return 0
	return int(discounts.get(unit_id, 0))

static func _spend_resources(session: SessionStateStoreScript.SessionData, cost: Variant) -> void:
	var resources = session.overworld.get("resources", {}).duplicate(true)
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key := String(key)
			resources[resource_key] = max(0, int(resources.get(resource_key, 0)) - int(cost[key]))
	session.overworld["resources"] = resources

static func _add_resources(session: SessionStateStoreScript.SessionData, delta: Variant) -> void:
	var resources = session.overworld.get("resources", {}).duplicate(true)
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			resources[resource_key] = max(0, int(resources.get(resource_key, 0)) + int(delta[key]))
	session.overworld["resources"] = resources

static func _apply_resource_transaction_to_pool(pool: Dictionary, cost: Variant, gain: Variant) -> void:
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key := String(key)
			pool[resource_key] = max(0, int(pool.get(resource_key, 0)) - int(cost[key]))
	if gain is Dictionary:
		for key in gain.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			pool[resource_key] = max(0, int(pool.get(resource_key, 0)) + int(gain[key]))

static func _add_resource_sets(base: Variant, delta: Variant) -> Dictionary:
	var merged := {"gold": 0, "wood": 0, "ore": 0}
	if base is Dictionary:
		for key in merged.keys():
			merged[key] = int(base.get(key, 0))
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			merged[resource_key] = int(merged.get(resource_key, 0)) + int(delta[key])
	return merged

static func _normalize_resource_dict(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for key in value.keys():
			normalized[String(key)] = max(0, int(value[key]))
	return normalized

static func _normalize_recruit_payload(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for unit_id_value in value.keys():
			var unit_id := String(unit_id_value)
			var count = max(0, int(value.get(unit_id_value, 0)))
			if unit_id == "" or count <= 0:
				continue
			normalized[unit_id] = count
	return normalized

static func _recruit_payload_total(value: Variant) -> int:
	var total := 0
	if value is Dictionary:
		for unit_id_value in value.keys():
			total += max(0, int(value.get(unit_id_value, 0)))
	return total

static func _describe_resource_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	for key in ["gold", "wood", "ore"]:
		var amount := int(delta.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts)

static func _describe_resource_change(before: Variant, after: Variant) -> String:
	if not (after is Dictionary):
		return ""
	var parts := []
	for key in ["gold", "wood", "ore"]:
		var previous := int(before.get(key, 0)) if before is Dictionary else 0
		var current := int(after.get(key, 0))
		var delta := current - previous
		if delta != 0:
			parts.append("%+d %s" % [delta, key])
	return ", ".join(parts)

static func _describe_cost_shortfall(readiness: Dictionary) -> String:
	var shortfall_summary := _describe_resource_delta(readiness.get("direct_shortfall", {}))
	var gold_short = max(
		0,
		int(readiness.get("required_gold_total", 0)) - int(readiness.get("available_gold_total", 0))
	)
	if shortfall_summary != "":
		if bool(readiness.get("market_active", false)) and gold_short > 0:
			return "%s; even full exchange leaves %d gold short" % [shortfall_summary, gold_short]
		return shortfall_summary
	if gold_short > 0:
		return "%d gold after exchange" % gold_short if bool(readiness.get("market_active", false)) else "%d gold" % gold_short
	return ""

static func _describe_reward_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	var resource_summary := _describe_resource_delta(delta)
	if resource_summary != "":
		parts.append(resource_summary)
	var experience := int(delta.get("experience", 0))
	if experience > 0:
		parts.append("%d xp" % experience)
	for key in delta.keys():
		var resource_key := String(key)
		if resource_key in ["gold", "wood", "ore", "experience"]:
			continue
		var amount := int(delta.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, resource_key])
	return ", ".join(parts)

static func _summarize_market_actions(actions: Variant, max_steps: int = 2) -> String:
	if not (actions is Array) or actions.is_empty():
		return ""
	var shown := []
	for index in range(min(max_steps, actions.size())):
		shown.append(String(actions[index]))
	var summary := "; ".join(shown)
	if actions.size() > max_steps:
		summary += "; %d more step%s" % [
			actions.size() - max_steps,
			"" if actions.size() - max_steps == 1 else "s",
		]
	return summary

static func _describe_recruit_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	var unit_ids := []
	for unit_id_value in delta.keys():
		unit_ids.append(String(unit_id_value))
	unit_ids.sort()
	for unit_id in unit_ids:
		var amount := int(delta.get(unit_id, 0))
		if amount <= 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		parts.append("+%d %s" % [amount, String(unit.get("name", unit_id))])
	return ", ".join(parts)

static func _describe_recruit_projection(current: Variant, projected: Variant) -> String:
	if not (projected is Dictionary):
		return ""
	var unit_ids := []
	if current is Dictionary:
		for unit_id_value in current.keys():
			var unit_id := String(unit_id_value)
			if unit_id != "" and unit_id not in unit_ids:
				unit_ids.append(unit_id)
	for unit_id_value in projected.keys():
		var unit_id := String(unit_id_value)
		if unit_id != "" and unit_id not in unit_ids:
			unit_ids.append(unit_id)
	unit_ids.sort()
	var parts := []
	for unit_id in unit_ids:
		var before := int(current.get(unit_id, 0)) if current is Dictionary else 0
		var after := int(projected.get(unit_id, 0))
		var delta := after - before
		if delta == 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		parts.append("%s %s" % [_describe_signed_int(delta), String(unit.get("name", unit_id))])
	return ", ".join(parts)

static func _describe_signed_int(value: int) -> String:
	return "%+d" % value

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "town": {}}
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "encounter": {}}
	var encounters = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return {"index": index, "encounter": encounter}
	return {"index": -1, "encounter": {}}

static func _advance_all_town_occupations(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		var result := _advance_town_occupation(session, town)
		town = result.get("town", town)
		towns[index] = town
		var message := String(result.get("message", ""))
		if message != "":
			messages.append(message)
	session.overworld["towns"] = towns
	return messages

static func _advance_town_occupation(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	if String(town.get("owner", "neutral")) != "player":
		town["occupation"] = _normalize_town_occupation_state({})
		return {"town": town, "message": ""}
	if String(occupation.get("state", "")) != "pacifying" or int(occupation.get("pressure", 0)) <= 0:
		town["occupation"] = occupation
		return {"town": town, "message": ""}
	var occupation_state: Dictionary = _town_occupation_state(session, town)
	var relief_per_day: int = max(1, int(occupation_state.get("relief_per_day", 1)))
	var pressure: int = max(0, int(occupation.get("pressure", 0)))
	var relieved: int = min(pressure, relief_per_day)
	occupation["pressure"] = max(0, pressure - relieved)
	occupation["last_event_day"] = session.day if session != null else int(occupation.get("last_event_day", 0))
	town["occupation"] = occupation
	if int(occupation.get("pressure", 0)) <= 0:
		var locked_headcount := _recruit_payload_total(occupation.get("locked_recruits", {}))
		town = _release_town_occupation_reserves(town)
		var release_clause := ""
		if locked_headcount > 0:
			release_clause = " %d held levy%s now answer the banner." % [
				locked_headcount,
				"y" if locked_headcount == 1 else "ies",
			]
		return {
			"town": town,
			"message": "%s pacifies into secure control.%s" % [_town_name(town), release_clause],
		}
	return {
		"town": town,
		"message": "%s pacification sheds %d unrest." % [_town_name(town), relieved],
	}

static func _advance_all_town_recovery(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		var result := _advance_town_recovery(session, town)
		town = result.get("town", town)
		towns[index] = town
		var message := String(result.get("message", ""))
		if message != "":
			messages.append(message)
	session.overworld["towns"] = towns
	return messages

static func _advance_town_recovery(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	var pressure := int(recovery.get("pressure", 0))
	if pressure <= 0:
		town["recovery"] = recovery
		return {"town": town, "message": ""}
	var recovery_state := _town_recovery_state(session, town)
	var relief_per_day = max(1, int(recovery_state.get("relief_per_day", 1)))
	var relieved = min(pressure, relief_per_day)
	recovery["pressure"] = max(0, pressure - relieved)
	if int(recovery.get("pressure", 0)) <= 0:
		recovery["source"] = ""
	town["recovery"] = recovery
	if String(town.get("owner", "neutral")) != "player":
		return {"town": town, "message": ""}
	if int(recovery.get("pressure", 0)) <= 0:
		return {"town": town, "message": "%s stabilize." % _town_name(town)}
	return {
		"town": town,
		"message": "%s shed %d recovery pressure." % [_town_name(town), relieved],
	}

static func _town_defense_summary(town: Dictionary) -> String:
	var garrison_strength := 0
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		var count = max(0, int(stack.get("count", 0)))
		garrison_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	if garrison_strength <= 0:
		return ""
	if garrison_strength >= 260:
		return "fortified walls"
	if garrison_strength >= 140:
		return "steady watch"
	return "thin watch"

static func _sync_movement_to_hero(session: SessionStateStoreScript.SessionData, previous_max: int) -> void:
	var movement_state = session.overworld.get("movement", {})
	if not (movement_state is Dictionary):
		movement_state = {}
	var new_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var current := int(movement_state.get("current", new_max))
	current = clamp(current + (new_max - previous_max), 0, new_max)
	movement_state["current"] = current
	movement_state["max"] = new_max
	session.overworld["movement"] = movement_state

static func _sync_spellbook_to_hero(session: SessionStateStoreScript.SessionData, previous_max: int) -> void:
	var hero = session.overworld.get("hero", {})
	var spellbook = hero.get("spellbook", {})
	if not (spellbook is Dictionary):
		return
	var mana = spellbook.get("mana", {})
	if not (mana is Dictionary):
		return
	var new_max := int(mana.get("max", SpellRulesScript.mana_max_from_hero(hero)))
	var current := int(mana.get("current", new_max))
	current = clamp(current + (new_max - previous_max), 0, new_max)
	mana["current"] = current
	mana["max"] = new_max
	spellbook["mana"] = mana
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero

static func _apply_artifact_claim(
	session: SessionStateStoreScript.SessionData,
	artifact_id: String,
	source_verb: String,
	auto_equip: bool
) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.claim_artifact(
		session.overworld.get("hero", {}),
		artifact_id,
		source_verb,
		auto_equip
	)
	if not bool(result.get("ok", false)):
		return result

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return result

static func _begin_town_assault(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var town_name := _town_name(town)
	var payload = _battle_rules().create_town_assault_payload(session, String(town.get("placement_id", "")))
	if payload.is_empty():
		return {"ok": false, "message": "The assault on %s cannot be staged." % town_name}
	session.battle = payload
	return {
		"ok": true,
		"message": "The assault on %s begins." % town_name,
		"route": "battle",
		"scenario_status": session.scenario_status,
	}

static func _claim_town(session: SessionStateStoreScript.SessionData, town_result: Dictionary) -> String:
	var town = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or town.is_empty():
		return ""
	var transition := transition_town_control(
		session,
		String(town.get("placement_id", "")),
		"player",
		"",
		"captured town"
	)
	town = transition.get("town", town)
	town["recovery"] = _normalize_town_recovery_state(town.get("recovery", {}))
	town["occupation"] = _normalize_town_occupation_state(town.get("occupation", {}))
	var towns = session.overworld.get("towns", [])
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return "Captured %s." % _town_name(town)

static func _town_garrison_company_count(town: Dictionary) -> int:
	var companies := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			companies += 1
	return companies

static func _town_garrison_headcount(town: Dictionary) -> int:
	var headcount := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary:
			headcount += max(0, int(stack.get("count", 0)))
	return headcount

static func _town_requires_assault(town: Dictionary) -> bool:
	return String(town.get("owner", "neutral")) == "enemy" and _town_garrison_headcount(town) > 0

static func _normalize_fog_of_war(session: SessionStateStoreScript.SessionData) -> void:
	var map_size := derive_map_size(session)
	var fog = session.overworld.get(FOG_KEY, {})
	if not (fog is Dictionary):
		fog = {}
	var explored_tiles := []
	if fog.has(EXPLORED_TILES_KEY):
		explored_tiles = _normalize_visibility_grid(fog.get(EXPLORED_TILES_KEY, []), map_size)
	else:
		explored_tiles = _blank_visibility_grid(map_size)
	var visible_tiles := _blank_visibility_grid(map_size)
	var heroes = session.overworld.get("player_heroes", [])
	if heroes is Array:
		for hero in heroes:
			if hero is Dictionary:
				_apply_hero_reveal(visible_tiles, explored_tiles, hero, map_size)
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		if String(node.get("collected_by_faction_id", "")) != "player":
			continue
		_apply_site_reveal(visible_tiles, explored_tiles, node, max(0, int(site.get("vision_radius", 0))), map_size)
	session.overworld[FOG_KEY] = _build_fog_payload(visible_tiles, explored_tiles, map_size)

static func _fog_state_ready(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null:
		return false
	var fog = session.overworld.get(FOG_KEY, {})
	if not (fog is Dictionary):
		return false
	var visible_tiles = fog.get(VISIBLE_TILES_KEY, [])
	var explored_tiles = fog.get(EXPLORED_TILES_KEY, [])
	var map_size := derive_map_size(session)
	return (
		visible_tiles is Array
		and explored_tiles is Array
		and visible_tiles.size() == map_size.y
		and explored_tiles.size() == map_size.y
	)

static func _build_fog_payload(visible_tiles: Array, explored_tiles: Array, map_size: Vector2i) -> Dictionary:
	return {
		VISIBLE_TILES_KEY: visible_tiles,
		EXPLORED_TILES_KEY: explored_tiles,
		"visible_count": _count_grid(visible_tiles),
		"explored_count": _count_grid(explored_tiles),
		"total_tiles": max(map_size.x, 0) * max(map_size.y, 0),
	}

static func _normalize_visibility_grid(value: Variant, map_size: Vector2i) -> Array:
	var normalized := _blank_visibility_grid(map_size)
	if not (value is Array):
		return normalized
	for y in range(min(value.size(), map_size.y)):
		var row = value[y]
		if not (row is Array):
			continue
		for x in range(min(row.size(), map_size.x)):
			normalized[y][x] = bool(row[x])
	return normalized

static func _blank_visibility_grid(map_size: Vector2i, fill_value: bool = false) -> Array:
	var grid := []
	for y in range(max(map_size.y, 0)):
		var row := []
		for x in range(max(map_size.x, 0)):
			row.append(fill_value)
		grid.append(row)
	return grid

static func _apply_hero_reveal(visible_tiles: Array, explored_tiles: Array, hero: Dictionary, map_size: Vector2i) -> void:
	var position = hero.get("position", {})
	var position_dict = position if position is Dictionary else {}
	var origin := Vector2i(int(position_dict.get("x", 0)), int(position_dict.get("y", 0)))
	var radius := HeroCommandRulesScript.scouting_radius_for_hero(hero)
	_apply_site_reveal(visible_tiles, explored_tiles, {"x": origin.x, "y": origin.y}, radius, map_size)

static func _apply_site_reveal(visible_tiles: Array, explored_tiles: Array, site_state: Dictionary, radius: int, map_size: Vector2i) -> void:
	if radius <= 0:
		return
	var origin := Vector2i(int(site_state.get("x", 0)), int(site_state.get("y", 0)))
	for y in range(max(0, origin.y - radius), min(map_size.y - 1, origin.y + radius) + 1):
		for x in range(max(0, origin.x - radius), min(map_size.x - 1, origin.x + radius) + 1):
			if abs(x - origin.x) + abs(y - origin.y) > radius:
				continue
			_set_grid_cell(visible_tiles, x, y, true)
			_set_grid_cell(explored_tiles, x, y, true)

static func _grid_cell(grid: Variant, x: int, y: int) -> bool:
	if not (grid is Array) or y < 0 or y >= grid.size():
		return false
	var row = grid[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return false
	return bool(row[x])

static func _set_grid_cell(grid: Array, x: int, y: int, value: bool) -> void:
	if y < 0 or y >= grid.size():
		return
	var row = grid[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return
	row[x] = value
	grid[y] = row

static func _count_grid(grid: Variant) -> int:
	if not (grid is Array):
		return 0
	var count := 0
	for row in grid:
		if not (row is Array):
			continue
		for value in row:
			if bool(value):
				count += 1
	return count

static func _attach_post_action_recap(
	result: Dictionary,
	session: SessionStateStoreScript.SessionData,
	action_kind: String,
	context: Dictionary = {}
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return result
	var recap := _build_post_action_recap(session, action_kind, context, String(result.get("message", "")))
	if not recap.is_empty():
		result["post_action_recap"] = recap
	return result

static func _build_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	action_kind: String,
	context: Dictionary,
	message: String
) -> Dictionary:
	match action_kind:
		"move":
			return _movement_post_action_recap(session, context, message)
		"resource_site":
			return _resource_site_post_action_recap(session, context, message)
		"artifact":
			return _artifact_post_action_recap(session, context, message)
		"site_response":
			return _site_response_post_action_recap(session, context, message)
		"spell":
			return _spell_post_action_recap(session, context, message)
		"town_capture":
			return _town_capture_post_action_recap(session, context, message)
		_:
			return _generic_post_action_recap(session, action_kind, context, message)

static func _movement_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var target_context: Dictionary = context.get("target_context", {}) if context.get("target_context", {}) is Dictionary else {}
	match String(target_context.get("type", "")):
		"resource":
			var site_context := target_context.duplicate(true)
			site_context["moved_from"] = "%d,%d" % [int(context.get("from_x", 0)), int(context.get("from_y", 0))]
			return _resource_site_post_action_recap(session, site_context, message)
		"artifact":
			var artifact_context := target_context.duplicate(true)
			artifact_context["moved_from"] = "%d,%d" % [int(context.get("from_x", 0)), int(context.get("from_y", 0))]
			return _artifact_post_action_recap(session, artifact_context, message)
		"encounter":
			return _battle_post_action_recap(session, target_context, message)
		"town":
			if String(context.get("route", "")) == "town":
				return _town_visit_post_action_recap(session, target_context, message)

	var to_x := int(context.get("to_x", 0))
	var to_y := int(context.get("to_y", 0))
	var movement = session.overworld.get("movement", {})
	var terrain := _terrain_name_at(session, to_x, to_y)
	var happened := "Moved from %d,%d to %d,%d; Move %d/%d remains." % [
		int(context.get("from_x", 0)),
		int(context.get("from_y", 0)),
		to_x,
		to_y,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
	]
	var affected := "Tile %d,%d on %s; scout net now shows %d tiles and has mapped %d." % [
		to_x,
		to_y,
		terrain,
		_visible_tile_count(session),
		_explored_tile_count(session),
	]
	return _post_action_recap_payload(
		"move",
		happened,
		affected,
		"Movement spends route tempo, updates scouting, and changes which sites or threats can be reached before daybreak.",
		_post_action_next_step(session),
		"%d,%d | Move %d/%d | scout net updated" % [
			to_x,
			to_y,
			int(movement.get("current", 0)),
			int(movement.get("max", 0)),
		]
	)

static func _resource_site_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var node := _post_action_resource_node(session, context)
	var site := ContentService.get_resource_site(String(context.get("site_id", node.get("site_id", ""))))
	var site_name := String(site.get("name", "the site"))
	var tile := _post_action_tile_label(context, node)
	var surface := describe_resource_site_surface(session, node, site)
	var control := describe_resource_site_control_summary(session, node, site)
	var reward := _describe_reward_delta(context.get("rewards", _resource_site_claim_rewards(site)))
	var happened := _sentence_with_keyword_or_default(message, site_name, "Secured %s." % site_name)
	var affected_parts := [site_name, tile, surface]
	if control != "":
		affected_parts.append(control)
	if reward != "":
		affected_parts.append("Reward %s" % reward)
	return _post_action_recap_payload(
		"resource_site",
		happened,
		" | ".join(_non_empty_strings(affected_parts)),
		_resource_site_post_action_why(site),
		_post_action_next_step(session),
		"%s secured | %s" % [site_name, _short_player_text(control if control != "" else surface, 46)]
	)

static func _artifact_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var artifact_id := String(context.get("artifact_id", ""))
	var artifact_name := ArtifactRulesScript.artifact_name(artifact_id)
	var happened := _sentence_with_keyword_or_default(message, artifact_name, "Recovered %s." % artifact_name)
	var affected := "%s at %s | %s | %s" % [
		artifact_name,
		_post_action_tile_label(context, {}),
		ArtifactRulesScript.artifact_reward_role(artifact_id),
		ArtifactRulesScript.artifact_effect_summary(artifact_id),
	]
	return _post_action_recap_payload(
		"artifact",
		happened,
		affected,
		"Artifacts change the hero's field tempo, command profile, or next battle odds immediately after pickup.",
		_post_action_next_step(session),
		"%s recovered | %s" % [artifact_name, _short_player_text(ArtifactRulesScript.artifact_effect_summary(artifact_id), 46)]
	)

static func _site_response_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var node := _post_action_resource_node(session, context)
	var site := ContentService.get_resource_site(String(context.get("site_id", node.get("site_id", ""))))
	var response_state := _resource_site_response_state(session, node, site)
	var site_name := String(site.get("name", "the site"))
	var affected := "%s at %s | %s" % [
		site_name,
		_post_action_tile_label(context, node),
		_resource_site_context_summary(session, node, site),
	]
	var impact_summary := _resource_site_response_effect_summary(response_state)
	return _post_action_recap_payload(
		"site_response",
		_first_sentence_or_default(message, "%s response order issued." % site_name),
		affected,
		"Response orders turn site control into route security%s before enemy pressure resolves." % ("" if impact_summary == "" else " and %s" % impact_summary),
		_post_action_next_step(session),
		"%s response active | %s" % [site_name, _short_player_text(impact_summary, 46)]
	)

static func _spell_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var spell_name := String(context.get("spell_name", "Field spell"))
	var target_contract: Dictionary = context.get("target_contract", {}) if context.get("target_contract", {}) is Dictionary else {}
	var consequence_preview: Dictionary = context.get("consequence_preview", {}) if context.get("consequence_preview", {}) is Dictionary else {}
	var movement = session.overworld.get("movement", {})
	var happened := _first_sentence_or_default(message, "%s resolved." % spell_name)
	var target_text := String(target_contract.get("public_text", "Active hero was the target."))
	var consequence_text := String(consequence_preview.get("public_text", "Field state changed."))
	var affected := "%s | %s | Move %d/%d" % [
		target_text,
		consequence_text,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
	]
	return _post_action_recap_payload(
		"spell",
		happened,
		affected,
		"Field magic converts mana into bounded route tempo without changing resources, sites, or scouting unless a later spell contract explicitly says so.",
		_post_action_next_step(session),
		"%s cast | Move %d/%d" % [
			spell_name,
			int(movement.get("current", 0)),
			int(movement.get("max", 0)),
		]
	)

static func _town_capture_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var town_result := _find_town_by_placement(session, String(context.get("placement_id", "")))
	var town: Dictionary = town_result.get("town", {})
	var town_name := _town_name(town) if not town.is_empty() else "the town"
	return _post_action_recap_payload(
		"town_capture",
		_first_sentence_or_default(message, "Captured %s." % town_name),
		"%s at %s | %s" % [town_name, _post_action_tile_label(context, town), describe_town_context(town, session) if not town.is_empty() else "Control changed"],
		"Town control changes recruitment, economy, defense posture, and objective progress.",
		_post_action_next_step(session),
		"%s captured | check town orders" % town_name
	)

static func _town_visit_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var town_result := _find_town_by_placement(session, String(context.get("placement_id", "")))
	var town: Dictionary = town_result.get("town", {})
	var town_name := _town_name(town) if not town.is_empty() else String(context.get("label", "the town"))
	return _post_action_recap_payload(
		"town_visit",
		_first_sentence_or_default(message, "%s opens its gates." % town_name),
		"%s at %s" % [town_name, _post_action_tile_label(context, town)],
		"Entering town converts field position into construction, recruitment, market, and recovery decisions.",
		"Review build or recruit orders, then return to the field route.",
		"%s opened | choose town orders" % town_name
	)

static func _battle_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	message: String
) -> Dictionary:
	var placement_id := String(context.get("placement_id", ""))
	var encounter_result := _find_encounter_by_placement(session, placement_id)
	var encounter: Dictionary = encounter_result.get("encounter", context)
	var label := encounter_display_name(encounter)
	var consequence := describe_encounter_consequence_surface(session, encounter, true)
	return _post_action_recap_payload(
		"battle",
		_sentence_with_keyword_or_default(message, label, "Battle is joined against %s." % label),
		"%s at %s | %s" % [label, _post_action_tile_label(context, encounter), describe_encounter_compact_readability(session, encounter)],
		"Clearing the guard can open routes, rewards, scouting, or objective progress%s." % ("" if consequence == "" else " (%s)" % consequence),
		"Resolve the battle, then check the returned field report before spending the next move.",
		"%s engaged | resolve battle" % label
	)

static func _generic_post_action_recap(
	session: SessionStateStoreScript.SessionData,
	action_kind: String,
	context: Dictionary,
	message: String
) -> Dictionary:
	var pos := hero_position(session)
	return _post_action_recap_payload(
		action_kind,
		_first_sentence_or_default(message, "Order resolved."),
		_dispatch_context_brief(session),
		"Resolved orders change the live route, economy, objective, or next-turn risk surface.",
		_post_action_next_step(session),
		"%s | %d,%d" % [_short_player_text(_first_sentence_or_default(message, "Order resolved."), 52), pos.x, pos.y]
	)

static func _post_action_recap_payload(
	kind: String,
	happened: String,
	affected: String,
	why_it_matters: String,
	next_step: String,
	cue_text: String
) -> Dictionary:
	var recap := {
		"kind": kind,
		"happened": _short_player_text(happened.strip_edges(), 180),
		"affected": _short_player_text(affected.strip_edges(), 180),
		"why_it_matters": _short_player_text(why_it_matters.strip_edges(), 180),
		"next_step": _short_player_text(next_step.strip_edges(), 140),
		"cue_text": _short_player_text(cue_text.strip_edges(), 96),
	}
	recap["tooltip_text"] = "Action Recap\n- Happened: %s\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [
		String(recap.get("happened", "")),
		String(recap.get("affected", "")),
		String(recap.get("why_it_matters", "")),
		String(recap.get("next_step", "")),
	]
	return _normalize_post_action_recap(recap)

static func _normalize_post_action_recap(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var recap: Dictionary = value
	var happened := String(recap.get("happened", "")).strip_edges()
	var affected := String(recap.get("affected", "")).strip_edges()
	var why := String(recap.get("why_it_matters", "")).strip_edges()
	var next_step := String(recap.get("next_step", "")).strip_edges()
	if happened == "" or affected == "" or why == "" or next_step == "":
		return {}
	var cue_text := String(recap.get("cue_text", happened)).strip_edges()
	var tooltip_text := String(recap.get("tooltip_text", "")).strip_edges()
	if tooltip_text == "":
		tooltip_text = "Action Recap\n- Happened: %s\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [happened, affected, why, next_step]
	return {
		"kind": String(recap.get("kind", "action")),
		"happened": happened,
		"affected": affected,
		"why_it_matters": why,
		"next_step": next_step,
		"cue_text": cue_text,
		"tooltip_text": tooltip_text,
	}

static func _post_action_tile_context(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y:
			return {
				"type": "resource",
				"placement_id": String(node.get("placement_id", "")),
				"site_id": String(node.get("site_id", "")),
				"x": tile.x,
				"y": tile.y,
			}
	for node_value in session.overworld.get("artifact_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y:
			return {
				"type": "artifact",
				"artifact_id": String(node.get("artifact_id", "")),
				"x": tile.x,
				"y": tile.y,
			}
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if int(encounter.get("x", -1)) == tile.x and int(encounter.get("y", -1)) == tile.y:
			return {
				"type": "encounter",
				"placement_id": String(encounter.get("placement_id", encounter.get("id", ""))),
				"encounter_id": String(encounter.get("encounter_id", encounter.get("id", ""))),
				"label": encounter_display_name(encounter),
				"x": tile.x,
				"y": tile.y,
			}
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if int(town.get("x", -1)) == tile.x and int(town.get("y", -1)) == tile.y:
			return {
				"type": "town",
				"placement_id": String(town.get("placement_id", "")),
				"label": _town_name(town),
				"x": tile.x,
				"y": tile.y,
			}
	return {
		"type": "open",
		"x": tile.x,
		"y": tile.y,
	}

static func _post_action_resource_node(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	var placement_id := String(context.get("placement_id", ""))
	var node_result := _find_resource_node_by_placement(session, placement_id)
	if int(node_result.get("index", -1)) >= 0:
		return node_result.get("node", {})
	return {
		"placement_id": placement_id,
		"site_id": String(context.get("site_id", "")),
		"x": int(context.get("x", 0)),
		"y": int(context.get("y", 0)),
	}

static func _post_action_tile_label(context: Dictionary, fallback: Dictionary) -> String:
	var x := int(context.get("x", fallback.get("x", 0)))
	var y := int(context.get("y", fallback.get("y", 0)))
	return "%d,%d" % [x, y]

static func _post_action_next_step(session: SessionStateStoreScript.SessionData) -> String:
	var objective_next := _event_feed_next_step_line(session)
	if objective_next != "":
		return objective_next
	var movement = session.overworld.get("movement", {})
	if int(movement.get("current", 0)) <= 0:
		return "End the turn after checking exposed routes and town orders."
	return "Choose the next route step, site order, or town response before ending the day."

static func _resource_site_post_action_why(site: Dictionary) -> String:
	var reasons := []
	if _resource_site_is_persistent(site):
		var income_summary := _describe_resource_delta(site.get("control_income", {}))
		if income_summary != "":
			reasons.append("adds daily %s" % income_summary)
		if not _resource_site_weekly_recruits(site).is_empty():
			reasons.append("feeds weekly recruits")
		if int(site.get("vision_radius", 0)) > 0:
			reasons.append("widens scouting")
		if site.has("response_profile"):
			reasons.append("opens route response")
	else:
		var reward_summary := _describe_reward_delta(_resource_site_claim_rewards(site))
		if reward_summary != "":
			reasons.append("adds %s now" % reward_summary)
	if reasons.is_empty():
		return "Site actions change economy, map control, objective tempo, or next-turn route risk."
	return "This site %s." % ", ".join(reasons)

static func _first_sentence_or_default(text: String, fallback: String) -> String:
	var cleaned := _enemy_activity_public_text(text)
	if cleaned == "":
		return fallback
	var sentence_end := cleaned.find(". ")
	if sentence_end >= 0:
		return cleaned.left(sentence_end + 1)
	return cleaned

static func _sentence_with_keyword_or_default(text: String, keyword: String, fallback: String) -> String:
	var cleaned := _enemy_activity_public_text(text)
	var needle := keyword.strip_edges()
	if cleaned == "" or needle == "":
		return _first_sentence_or_default(text, fallback)
	for sentence_value in cleaned.split(". ", false):
		var sentence := String(sentence_value).strip_edges()
		if sentence == "":
			continue
		if sentence.find(needle) >= 0:
			return sentence if sentence.ends_with(".") else "%s." % sentence
	return _first_sentence_or_default(text, fallback)

static func _visible_tile_count(session: SessionStateStoreScript.SessionData) -> int:
	var fog = session.overworld.get(FOG_KEY, {})
	return int(fog.get("visible_count", 0))

static func _explored_tile_count(session: SessionStateStoreScript.SessionData) -> int:
	var fog = session.overworld.get(FOG_KEY, {})
	return int(fog.get("explored_count", 0))

static func _finalize_action_result(
	session: SessionStateStoreScript.SessionData,
	ok: bool,
	base_message: String
) -> Dictionary:
	HeroCommandRulesScript.commit_active_hero(session)
	refresh_fog_of_war(session)
	var messages := []
	if base_message != "":
		messages.append(base_message)

	var scenario_result: Dictionary = _evaluate_scenario_state(session)
	var scenario_message := String(scenario_result.get("message", ""))
	HeroCommandRulesScript.commit_active_hero(session)
	refresh_fog_of_war(session)
	if scenario_message != "":
		messages.append(scenario_message)

	return {
		"ok": ok,
		"message": " ".join(messages),
		"scenario_status": session.scenario_status,
	}

static func _normalize_command_briefing(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	var had_state := briefing_state is Dictionary
	if not had_state:
		briefing_state = {}
	var signature := "%s|%s" % [session.scenario_id, SessionStateStoreScript.normalize_launch_mode(session.launch_mode)]
	if String(briefing_state.get("signature", "")) != signature:
		briefing_state = {
			"signature": signature,
			"shown": false,
			"shown_day": 0,
		}
	else:
		briefing_state["signature"] = signature
		briefing_state["shown"] = bool(briefing_state.get("shown", false))
		briefing_state["shown_day"] = max(0, int(briefing_state.get("shown_day", 0)))
	if not bool(briefing_state.get("shown", false)) and (session.day > 1 or String(session.flags.get("last_action", "")) != ""):
		briefing_state["shown"] = true
		briefing_state["shown_day"] = max(1, session.day)
	session.overworld[COMMAND_BRIEFING_KEY] = briefing_state

static func _normalize_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	if not (forecast_state is Dictionary):
		forecast_state = {}
	var forecast := _command_risk_forecast(session)
	var signature := String(forecast.get("signature", ""))
	if signature == "":
		forecast_state = {
			"signature": "",
			"shown": true,
			"shown_day": session.day,
		}
	elif String(forecast_state.get("signature", "")) != signature:
		forecast_state = {
			"signature": signature,
			"shown": false,
			"shown_day": 0,
		}
	else:
		forecast_state = {
			"signature": signature,
			"shown": bool(forecast_state.get("shown", false)),
			"shown_day": max(0, int(forecast_state.get("shown_day", 0))),
		}
	session.overworld[COMMAND_RISK_FORECAST_KEY] = forecast_state

static func _should_surface_command_briefing(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.scenario_id == "":
		return false
	if session.scenario_status != "in_progress" or String(session.game_state) != "overworld":
		return false
	if session.day != 1 or String(session.flags.get("last_action", "")) != "":
		return false
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	return briefing_state is Dictionary and not bool(briefing_state.get("shown", false))

static func _should_surface_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.scenario_id == "":
		return false
	if session.scenario_status != "in_progress" or String(session.game_state) != "overworld":
		return false
	var forecast := _command_risk_forecast(session)
	if not bool(forecast.get("gate_end_turn", false)):
		return false
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	return forecast_state is Dictionary and not bool(forecast_state.get("shown", false))

static func _command_briefing_lines(session: SessionStateStoreScript.SessionData) -> Array:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var lines := []
	var posture_line := _command_briefing_posture_line(session)
	if posture_line != "":
		lines.append(posture_line)
	if not scenario.is_empty():
		var objective_summary: String = _scenario_opening_objective_summary(session, scenario)
		if objective_summary != "":
			lines.append_array(objective_summary.split("\n"))
	var logistics_line := _command_briefing_logistics_line(session)
	if logistics_line != "":
		lines.append(logistics_line)
	var pressure_line := _command_briefing_pressure_line(session, scenario)
	if pressure_line != "":
		lines.append(pressure_line)
	var orders_line := _command_briefing_orders_line(session, scenario)
	if orders_line != "":
		lines.append(orders_line)
	return lines

static func _command_briefing_posture_line(session: SessionStateStoreScript.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	if hero.is_empty():
		return ""
	var pos := hero_position(session)
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	var movement = session.overworld.get("movement", {})
	var mana = hero.get("spellbook", {}).get("mana", {})
	var army_totals := _army_totals(hero.get("army", {}))
	return "Command posture: %s deploys on %s at %d,%d | Move %d/%d | Scout %d | Mana %d/%d | %d troops in %d groups" % [
		String(hero.get("name", "Hero")),
		terrain,
		pos.x,
		pos.y,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		HeroCommandRulesScript.scouting_radius_for_hero(hero),
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		int(army_totals.get("headcount", 0)),
		int(army_totals.get("groups", 0)),
	]

static func _command_briefing_logistics_line(session: SessionStateStoreScript.SessionData) -> String:
	var pos := hero_position(session)
	var town_result := _nearest_town_for_controller(session, "player", pos.x, pos.y)
	var site_plan := _nearest_logistics_plan(session)
	if int(town_result.get("index", -1)) < 0:
		if site_plan.is_empty():
			return "Logistics watch: No owned town anchors the front yet. Early site claims will define your first supply line."
		return "Logistics watch: No owned town anchors the front yet. %s" % String(site_plan.get("summary", ""))
	var town = town_result.get("town", {})
	var distance = abs(pos.x - int(town.get("x", 0))) + abs(pos.y - int(town.get("y", 0)))
	var logistics := town_logistics_state(session, town)
	var parts := [
		"%s %d tile%s away" % [_town_name(town), distance, "" if distance == 1 else "s"],
		String(logistics.get("summary", "")),
	]
	if int(logistics.get("disrupted_count", 0)) > 0 and logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
		parts.append("Denied: %s" % ", ".join(logistics.get("disrupted_site_labels", []).slice(0, min(2, logistics.get("disrupted_site_labels", []).size()))))
	elif int(logistics.get("threatened_count", 0)) > 0 and logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
		parts.append("Threatened: %s" % ", ".join(logistics.get("threatened_site_labels", []).slice(0, min(2, logistics.get("threatened_site_labels", []).size()))))
	elif logistics.get("missing_family_labels", []) is Array and not logistics.get("missing_family_labels", []).is_empty():
		parts.append("Missing: %s" % ", ".join(logistics.get("missing_family_labels", []).slice(0, min(2, logistics.get("missing_family_labels", []).size()))))
	if not site_plan.is_empty():
		parts.append(String(site_plan.get("summary", "")))
	return "Logistics watch: %s" % " | ".join(parts)

static func _command_briefing_pressure_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var local_summary := _local_visible_threat_summary(session, "")
	if local_summary != "":
		return "Pressure watch: %s" % local_summary
	if scenario.is_empty():
		return "Pressure watch: No hostile lane is confirmed yet. Push scouts forward before the first raid window opens."
	var operational_lines: Array = _scenario_enemy_operational_lines(session, scenario)
	if not operational_lines.is_empty():
		var line := String(operational_lines[0])
		if line.begins_with("Enemy posture: "):
			return "Pressure watch: %s" % line.trim_prefix("Enemy posture: ")
		return "Pressure watch: %s" % line
	return "Pressure watch: No hostile lane is confirmed yet. Push scouts forward before the first raid window opens."

static func _command_briefing_orders_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var context_actions := get_context_actions(session)
	if not context_actions.is_empty():
		return "Immediate orders: %s" % _context_action_briefing(session, context_actions[0], get_active_context(session))
	var site_plan := _nearest_logistics_plan(session)
	if not site_plan.is_empty():
		return "Immediate orders: %s" % String(site_plan.get("order", "Advance to stabilize the nearest logistics lane."))
	var encounter_plan := _nearest_visible_encounter_plan(session)
	if not encounter_plan.is_empty():
		return "Immediate orders: %s" % String(encounter_plan.get("order", "Advance on the nearest hostile contact."))
	if not scenario.is_empty():
		var first_contact: String = _scenario_first_contact_summary(scenario)
		if first_contact != "":
			var contact_lines := first_contact.split("\n")
			if not contact_lines.is_empty():
				return "Immediate orders: %s" % String(contact_lines[0]).trim_prefix("Likely first contact: ")
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var victory_labels: Array = _scenario_objective_labels_from_bucket(session, objectives.get("victory", []), 1)
		if not victory_labels.is_empty():
			return "Immediate orders: Advance on %s while the front is still forming." % String(victory_labels[0])
	return "Immediate orders: Expand the scout ring, secure the nearest lane, and shape the first contact on favorable ground."

static func _context_action_briefing(session: SessionStateStoreScript.SessionData, action: Variant, context: Dictionary) -> String:
	if not (action is Dictionary):
		return "Review the current tile and commit the next order."
	var action_id := String(action.get("id", ""))
	match action_id:
		"visit_town":
			var town = context.get("town", {})
			return "Enter %s now to review construction, recruitment, market, and recovery orders." % _town_name(town)
		"capture_town":
			var town = context.get("town", {})
			var owner := String(town.get("owner", "neutral"))
			if owner == "enemy":
				if _town_requires_assault(town):
					return "Storm %s now. The hostile garrison must be broken in battle before the banner changes." % _town_name(town)
				return "Capture %s from the hostile garrison before it can anchor the local front." % _town_name(town)
			return "Claim %s now to secure a foothold and unlock local command options." % _town_name(town)
		"collect_resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return "Secure %s now to %s." % [
				String(site.get("name", "this site")),
				_resource_site_opening_value(site),
			]
		"site_response":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			var response_state := _resource_site_response_state(session, node, site)
			var command_clause := "Commit %s at %s" % [
				String(response_state.get("action_label", "Secure Route")),
				String(site.get("name", "the frontier site")),
			]
			if String(response_state.get("commander_name", "")) != "":
				command_clause = "Commit %s to %s at %s" % [
					String(response_state.get("commander_name", "")),
					String(response_state.get("action_label", "secure the route")).to_lower(),
					String(site.get("name", "the frontier site")),
				]
			return "%s to steady the local route for %d day%s with escort strength %d." % [
				command_clause,
				int(response_state.get("watch_days", 0)),
				"" if int(response_state.get("watch_days", 0)) == 1 else "s",
				int(response_state.get("security_rating", 1)),
			]
		"collect_artifact":
			var artifact_node = context.get("node", {})
			return "Recover %s now; %s." % [
				ArtifactRulesScript.artifact_name(String(artifact_node.get("artifact_id", ""))),
				ArtifactRulesScript.artifact_collection_state(
					session.overworld.get("hero", {}),
					String(artifact_node.get("artifact_id", "")),
					bool(artifact_node.get("collected", false)),
					String(artifact_node.get("collected_by_faction_id", ""))
				),
			]
		"enter_battle":
			var encounter = context.get("encounter", {})
			var delivery_pressure: String = _encounter_delivery_pressure_summary(session, encounter, true)
			if delivery_pressure != "":
				return delivery_pressure
			return "Break %s now before the host can widen pressure across the frontier." % encounter_display_name(encounter)
	return String(action.get("summary", "Review the current tile and commit the next order."))

static func _context_action_summary(session: SessionStateStoreScript.SessionData, action_id: String, context: Dictionary) -> String:
	match action_id:
		"visit_town", "capture_town":
			return _context_action_briefing(session, {"id": action_id}, context)
		"collect_resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return _resource_site_context_summary(session, node, site)
		"collect_artifact":
			var artifact_node = context.get("node", {})
			var artifact_id := String(artifact_node.get("artifact_id", ""))
			return "Recover %s for the active hero. %s. %s." % [
				ArtifactRulesScript.describe_artifact_short(artifact_id),
				ArtifactRulesScript.artifact_collection_state(
					session.overworld.get("hero", {}),
					artifact_id,
					bool(artifact_node.get("collected", false)),
					String(artifact_node.get("collected_by_faction_id", ""))
				),
				ArtifactRulesScript.describe_single_artifact_impact(artifact_id),
			]
		"enter_battle":
			var encounter = context.get("encounter", {})
			return _encounter_pressure_summary(session, encounter, true)
	return _context_action_briefing(session, {"id": action_id}, context)

static func _encounter_delivery_pressure_summary(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	for_battle_prompt: bool = false
) -> String:
	var delivery_context: Dictionary = delivery_interception_context_for_encounter(session, encounter)
	if not bool(delivery_context.get("active", false)):
		return ""
	var encounter_name := encounter_display_name(encounter)
	var route_label := String(delivery_context.get("route_label", delivery_context.get("pressure_label", "the relief lane")))
	var recruit_summary := String(delivery_context.get("recruit_summary", "the convoy"))
	var interception_state: Dictionary = delivery_context.get("interception", {})
	if for_battle_prompt:
		if bool(interception_state.get("blocks_delivery", false)):
			return "Break %s now to reopen %s before %s is intercepted." % [
				encounter_name,
				route_label,
				recruit_summary,
			]
		return "Break %s now to keep %s moving toward %s." % [
			encounter_name,
			recruit_summary,
			String(delivery_context.get("target_label", "the front")),
		]
	if bool(interception_state.get("blocks_delivery", false)):
		return "%s is on %s. If left standing, %s is intercepted before it reaches %s." % [
			encounter_name,
			route_label,
			recruit_summary,
			String(delivery_context.get("target_label", "the front")),
		]
	return "%s is hunting %s. Breaking it protects %s on the road to %s." % [
		encounter_name,
		route_label,
		recruit_summary,
		String(delivery_context.get("target_label", "the front")),
	]

static func _encounter_pressure_summary(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	for_battle_prompt: bool = false
) -> String:
	var delivery_pressure: String = _encounter_delivery_pressure_summary(session, encounter, for_battle_prompt)
	if delivery_pressure != "":
		return delivery_pressure

	var encounter_name := encounter_display_name(encounter)
	if String(encounter.get("spawned_by_faction_id", "")) == "":
		var readability := describe_encounter_compact_readability(session, encounter)
		if for_battle_prompt:
			var battle_order := "Break %s on %s before the host can widen pressure across the frontier." % [
				encounter_name,
				_terrain_name_at(session, int(encounter.get("x", 0)), int(encounter.get("y", 0))),
			]
			return battle_order if readability == "" else "%s %s." % [battle_order, readability]
		return "Scout report: %s." % readability if readability != "" else "Approach strength unknown beyond authored scouting notes. Enter battle to break the host."

	var target_kind := String(encounter.get("target_kind", ""))
	var target_label := String(encounter.get("target_label", "the frontier"))
	var goal_distance := int(encounter.get("goal_distance", 9999))
	var pressuring := bool(encounter.get("arrived", false)) or goal_distance <= 0
	match target_kind:
		"hero":
			if for_battle_prompt:
				return "Break %s now before it pins %s in a forced field battle." % [encounter_name, target_label]
			if pressuring or goal_distance <= 1:
				return "%s is on %s's march line and can force a field battle at day's end." % [encounter_name, target_label]
			return "%s is hunting %s across the frontier." % [encounter_name, target_label]
		"town":
			if for_battle_prompt:
				return "Break %s now before it reaches %s and forces a town assault." % [encounter_name, target_label]
			if pressuring or goal_distance <= 1:
				return "%s already presses %s and can trigger a town fight at day's end." % [encounter_name, target_label]
			return "%s is marching on %s." % [encounter_name, target_label]
		"resource":
			if for_battle_prompt:
				return "Break %s now before it denies %s." % [encounter_name, target_label]
			return "%s is moving to deny %s." % [encounter_name, target_label]
		"artifact":
			if for_battle_prompt:
				return "Break %s now before it secures %s." % [encounter_name, target_label]
			return "%s is closing on %s." % [encounter_name, target_label]
		"encounter":
			if for_battle_prompt:
				return "Break %s now before it locks down %s and widens the hostile front." % [encounter_name, target_label]
			return "%s is trying to lock down %s and widen the hostile front." % [encounter_name, target_label]
		_:
			if for_battle_prompt:
				return "Break %s now before the host can widen pressure across the frontier." % encounter_name
			return "This host is moving through the frontier under hostile orders."

static func _command_commitment_action_line(session: SessionStateStoreScript.SessionData) -> String:
	var context_actions := get_context_actions(session)
	if not context_actions.is_empty():
		var action = context_actions[0]
		if action is Dictionary:
			return String(action.get("summary", _context_action_briefing(session, action, get_active_context(session))))
	var site_plan := _nearest_logistics_plan(session)
	if not site_plan.is_empty():
		return String(site_plan.get("order", "Advance to stabilize the nearest logistics lane."))
	var encounter_plan := _nearest_visible_encounter_plan(session)
	if not encounter_plan.is_empty():
		return String(encounter_plan.get("order", "Advance on the nearest hostile contact."))
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var victory_labels: Array = _scenario_objective_labels_from_bucket(session, objectives.get("victory", []), 1)
		if not victory_labels.is_empty():
			return "Advance on %s while the front is still forming." % String(victory_labels[0])
	return "Expand the scout ring, secure the nearest lane, and shape the first contact on favorable ground."

static func _command_commitment_route_line(session: SessionStateStoreScript.SessionData) -> String:
	var context := get_active_context(session)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			if String(town.get("owner", "neutral")) == "player":
				var logistics := town_logistics_state(session, town)
				var recovery := town_recovery_state(session, town)
				var parts := [
					"%s anchors this lane" % _town_name(town),
					"Readiness %d" % town_battle_readiness(town, session),
				]
				if String(logistics.get("summary", "")) != "":
					parts.append(String(logistics.get("summary", "")))
				if bool(recovery.get("active", false)):
					parts.append(String(recovery.get("summary", "")))
				return " | ".join(parts)
			return "%s is still off the banner line. Claiming it secures a local foothold and unlocks town command options." % _town_name(town)
		"resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			var site_name := String(site.get("name", "Frontier site"))
			var response_state := _resource_site_response_state(session, node, site)
			var linked_town_result := _resource_node_linked_town(session, node, "player")
			var linked_town = linked_town_result.get("town", {})
			var linked_clause := ""
			if not linked_town.is_empty():
				linked_clause = " | Linked %s" % _town_name(linked_town)
			if bool(response_state.get("active", false)):
				var response_line := "%s escorted for %d day%s" % [
					site_name,
					int(response_state.get("remaining_days", 0)),
					"" if int(response_state.get("remaining_days", 0)) == 1 else "s",
				]
				if String(response_state.get("commander_name", "")) != "":
					response_line += " | %s detached" % String(response_state.get("commander_name", ""))
				var impact_summary := _resource_site_response_effect_summary(response_state)
				if impact_summary != "":
					response_line += " | %s" % impact_summary
				return response_line + linked_clause
			if _resource_site_is_persistent(site):
				if String(node.get("collected_by_faction_id", "")) == "player" and _resource_site_under_threat(session, node, "player"):
					return "%s is under threat%s. Leaving the lane loose risks losing the route bonus." % [site_name, linked_clause]
				return "%s can %s%s." % [site_name, _resource_site_opening_value(site), linked_clause]
			return "%s remains claimable on the active lane." % site_name
		"encounter":
			var encounter = context.get("encounter", {})
			return "%s blocks the active march line. Leaving it intact keeps hostile pressure on this route." % (
				encounter_display_name(encounter)
			)
		"artifact":
			var artifact_node = context.get("node", {})
			return "%s lies exposed on the active lane. Recovering it adds %s to the current commander before the front tightens." % [
				ArtifactRulesScript.artifact_name(String(artifact_node.get("artifact_id", ""))),
				ArtifactRulesScript.describe_artifact_short(String(artifact_node.get("artifact_id", ""))),
			]
	var site_plan := _nearest_logistics_plan(session)
	if not site_plan.is_empty():
		return String(site_plan.get("summary", "The nearest logistics lane needs attention."))
	var local_pressure := _local_visible_threat_summary(session, "")
	if local_pressure != "":
		return local_pressure
	var management_watch := describe_management_watch(session)
	if management_watch != "":
		return management_watch
	return "No visible hostile pressure is crowding the current route."

static func _command_commitment_coverage_line(session: SessionStateStoreScript.SessionData) -> String:
	var parts := []
	var movement = session.overworld.get("movement", {})
	parts.append("Move %d/%d" % [int(movement.get("current", 0)), int(movement.get("max", 0))])
	var reserve_support := _nearest_reserve_hero_support(session)
	if reserve_support.is_empty():
		parts.append("No reserve commander covers the active lane")
	else:
		var reserve_distance := int(reserve_support.get("distance", 0))
		var reserve_name := String(reserve_support.get("name", "Reserve commander"))
		if reserve_distance <= 0:
			parts.append("Reserve %s is already on this tile" % reserve_name)
		else:
			parts.append("Reserve %s %d tile%s %s" % [
				reserve_name,
				reserve_distance,
				"" if reserve_distance == 1 else "s",
				String(reserve_support.get("direction", "away")),
			])
	var pos := hero_position(session)
	var nearest_town_result := _nearest_town_for_controller(session, "player", pos.x, pos.y)
	if int(nearest_town_result.get("index", -1)) >= 0:
		var town = nearest_town_result.get("town", {})
		var distance = abs(pos.x - int(town.get("x", 0))) + abs(pos.y - int(town.get("y", 0)))
		if distance <= 0:
			parts.append("%s anchors this tile" % _town_name(town))
		else:
			parts.append("%s %d tile%s %s" % [
				_town_name(town),
				distance,
				"" if distance == 1 else "s",
				_direction_from_to(pos, Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))),
			])
	else:
		parts.append("No owned town anchors the current march line")
	return " | ".join(parts)

static func _command_commitment_hold_line(session: SessionStateStoreScript.SessionData) -> String:
	var forecast := _command_risk_forecast(session)
	if bool(forecast.get("has_risk", false)):
		var lines = forecast.get("lines", [])
		if lines is Array and lines.size() > 1:
			return String(lines[1]).trim_prefix("- ")
		return String(forecast.get("summary", "the frontier stays strained"))
	if not get_context_actions(session).is_empty():
		return "No concrete next-day break is signaled, but the current order window stays open only while this lane remains clear."
	return "No concrete next-day break is signaled from the current frontier watch."

static func _nearest_reserve_hero_support(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var best := {}
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		var hero_pos = hero.get("position", {})
		var target := Vector2i(int(hero_pos.get("x", 0)), int(hero_pos.get("y", 0)))
		var distance = abs(pos.x - target.x) + abs(pos.y - target.y)
		var candidate := {
			"id": String(hero.get("id", "")),
			"name": String(hero.get("name", "Reserve commander")),
			"distance": distance,
			"direction": _direction_from_to(pos, target),
		}
		if best.is_empty() or distance < int(best.get("distance", 9999)):
			best = candidate
	return best

static func _nearest_logistics_plan(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var best := {}
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		var x := int(node.get("x", -1))
		var y := int(node.get("y", -1))
		if not is_tile_visible(session, x, y):
			continue
		var controller := String(node.get("collected_by_faction_id", ""))
		var priority := 99
		var summary := ""
		var order := ""
		if controller == "player":
			if _resource_site_under_threat(session, node, "player"):
				var response_state := _resource_site_response_state(session, node, site)
				priority = 0
				summary = "%s is threatened %d tile%s %s" % [
					String(site.get("name", "Frontier site")),
					abs(pos.x - x) + abs(pos.y - y),
					"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
					_direction_from_to(pos, Vector2i(x, y)),
				]
				if bool(response_state.get("active", false)) and String(response_state.get("commander_name", "")) != "":
					summary += " | Escort by %s is being contested" % String(response_state.get("commander_name", ""))
				order = "March %d tile%s %s to secure %s before the escort line breaks." % [
					abs(pos.x - x) + abs(pos.y - y),
					"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
					_direction_from_to(pos, Vector2i(x, y)),
					String(site.get("name", "the route")),
				]
			else:
				var response_state := _resource_site_response_state(session, node, site)
				if int(response_state.get("watch_days", 0)) > 0 and not bool(response_state.get("active", false)):
					priority = 2
					summary = "%s is ready for %s %d tile%s %s" % [
						String(site.get("name", "Frontier site")),
						String(response_state.get("action_label", "route security")).to_lower(),
						abs(pos.x - x) + abs(pos.y - y),
						"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
						_direction_from_to(pos, Vector2i(x, y)),
					]
					order = "March %d tile%s %s and issue %s at %s." % [
						abs(pos.x - x) + abs(pos.y - y),
						"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
						_direction_from_to(pos, Vector2i(x, y)),
						String(response_state.get("action_label", "route security")),
						String(site.get("name", "the site")),
					]
		else:
			priority = 1
			summary = "%s lies %d tile%s %s and can %s" % [
				String(site.get("name", "Frontier site")),
				abs(pos.x - x) + abs(pos.y - y),
				"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				_resource_site_opening_value(site),
			]
			order = "Claim %s %d tile%s %s to %s." % [
				String(site.get("name", "the frontier site")),
				abs(pos.x - x) + abs(pos.y - y),
				"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				_resource_site_opening_value(site),
			]
		if priority >= 99:
			continue
		var candidate := {
			"priority": priority,
			"distance": abs(pos.x - x) + abs(pos.y - y),
			"summary": summary,
			"order": order,
		}
		if best.is_empty() or int(candidate.get("priority", 99)) < int(best.get("priority", 99)) or (
			int(candidate.get("priority", 99)) == int(best.get("priority", 99))
			and int(candidate.get("distance", 9999)) < int(best.get("distance", 9999))
		):
			best = candidate
	return best

static func _nearest_visible_encounter_plan(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var best := {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or is_encounter_resolved(session, encounter):
			continue
		var x := int(encounter.get("x", -1))
		var y := int(encounter.get("y", -1))
		if not is_tile_visible(session, x, y):
			continue
		var distance = abs(pos.x - x) + abs(pos.y - y)
		var candidate := {
			"distance": distance,
			"order": "Advance %d tile%s %s and prepare to engage %s on %s." % [
				distance,
				"" if distance == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				encounter_display_name(encounter),
				_terrain_name_at(session, x, y),
			],
		}
		if best.is_empty() or int(candidate.get("distance", 9999)) < int(best.get("distance", 9999)):
			best = candidate
	return best

static func _resource_site_opening_value(site: Dictionary) -> String:
	match String(site.get("family", "")):
		"faction_outpost":
			return "extend scouting and hold the frontier watch"
		"frontier_shrine":
			return "keep spell routes and recovery lanes open"
		"neutral_dwelling":
			return "feed musters into the nearest town"
		_:
			return "strengthen your early reserves"

static func _direction_from_to(origin: Vector2i, target: Vector2i) -> String:
	var vertical := ""
	var horizontal := ""
	if target.y < origin.y:
		vertical = "north"
	elif target.y > origin.y:
		vertical = "south"
	if target.x < origin.x:
		horizontal = "west"
	elif target.x > origin.x:
		horizontal = "east"
	if vertical != "" and horizontal != "":
		return "%s-%s" % [vertical, horizontal]
	if vertical != "":
		return vertical
	if horizontal != "":
		return horizontal
	return "here"

static func _command_risk_forecast(session: SessionStateStoreScript.SessionData) -> Dictionary:
	_normalize_enemy_states(session)
	var items := _command_risk_items(session)
	if items.is_empty():
		return {
			"has_risk": false,
			"severity": 0,
			"summary": "",
			"lines": [],
			"signature": "",
			"gate_end_turn": false,
		}
	items.sort_custom(func(a, b):
		if int(a.get("severity", 0)) == int(b.get("severity", 0)):
			return String(a.get("key", "")) < String(b.get("key", ""))
		return int(a.get("severity", 0)) > int(b.get("severity", 0))
	)
	var selected_items := []
	for item in items:
		if not (item is Dictionary):
			continue
		selected_items.append(item)
		if selected_items.size() >= 3:
			break
	var severity := int(selected_items[0].get("severity", 0))
	var summary_parts := []
	var gate_end_turn := false
	for item in selected_items:
		var summary := String(item.get("summary", ""))
		if summary != "" and summary not in summary_parts:
			summary_parts.append(summary)
		gate_end_turn = gate_end_turn or bool(item.get("gate", false))
	var summary_text := "%s risk" % _command_risk_grade_label(severity)
	if not summary_parts.is_empty():
		summary_text = "%s | %s" % [summary_text, " | ".join(summary_parts)]
	var lines := ["Next-day posture: %s" % summary_text]
	var signature_payload := {"day": session.day, "summary": summary_text, "details": []}
	for item in selected_items:
		var detail := String(item.get("detail", ""))
		if detail == "":
			continue
		lines.append("- %s" % detail)
		signature_payload["details"].append(detail)
	return {
		"has_risk": true,
		"severity": severity,
		"summary": summary_text,
		"lines": lines,
		"signature": JSON.stringify(signature_payload),
		"gate_end_turn": gate_end_turn or severity >= 3,
	}

static func _command_risk_items(session: SessionStateStoreScript.SessionData) -> Array:
	var items := []
	var pressured_town_ids := {}
	var town_items := _command_risk_town_items(session)
	for item in town_items:
		items.append(item)
		var town_id := String(item.get("town_placement_id", ""))
		if town_id != "":
			pressured_town_ids[town_id] = true
	items.append_array(_command_risk_logistics_items(session, pressured_town_ids))
	items.append_array(_command_risk_objective_items(session, pressured_town_ids))
	items.append_array(_command_risk_posture_items(session))
	var field_item := _command_risk_field_item(session)
	if not field_item.is_empty():
		items.append(field_item)
	return items

static func _command_risk_town_items(session: SessionStateStoreScript.SessionData) -> Array:
	var items := []
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var threat_state := _town_command_risk_state(session, town)
		if int(threat_state.get("visible_pressuring", 0)) <= 0 and int(threat_state.get("visible_marching", 0)) <= 0 and not bool(threat_state.get("hidden_targeting", false)) and int(threat_state.get("siege_progress", 0)) <= 0:
			continue
		var readiness := town_battle_readiness(town, session)
		var defense := _town_defense_summary(town)
		var logistics := town_logistics_state(session, town)
		var recovery := town_recovery_state(session, town)
		var capital_project := town_capital_project_state(town, session)
		var objective_anchor: bool = _raid_target_is_objective_anchor(
			session,
			"town",
			String(town.get("placement_id", ""))
		)
		var severity := 2
		if int(threat_state.get("visible_pressuring", 0)) > 0 or int(threat_state.get("siege_progress", 0)) > 0:
			severity = 5
		elif int(threat_state.get("nearest_goal_distance", 9999)) <= 1:
			severity = 4
		elif int(threat_state.get("nearest_goal_distance", 9999)) <= 2 or bool(threat_state.get("hidden_targeting", false)):
			severity = 3
		if readiness <= 18 or defense == "thin watch":
			severity += 1
		if int(logistics.get("support_gap", 0)) > 0 or bool(recovery.get("active", false)) or bool(capital_project.get("vulnerable", false)):
			severity += 1
		if objective_anchor or town_strategic_role(town) in ["capital", "stronghold"]:
			severity += 1
		severity = clampi(severity, 2, 5)
		var threat_clauses := []
		if int(threat_state.get("visible_pressuring", 0)) > 0:
			threat_clauses.append("%d known raid host%s already press the approaches" % [
				int(threat_state.get("visible_pressuring", 0)),
				"" if int(threat_state.get("visible_pressuring", 0)) == 1 else "s",
			])
		if int(threat_state.get("visible_marching", 0)) > 0:
			var days_to_contact = max(1, int(threat_state.get("nearest_goal_distance", 9999)))
			if days_to_contact <= 2:
				threat_clauses.append("%d known host%s can reach the town in %d day%s" % [
					int(threat_state.get("visible_marching", 0)),
					"" if int(threat_state.get("visible_marching", 0)) == 1 else "s",
					days_to_contact,
					"" if days_to_contact == 1 else "s",
				])
			else:
				threat_clauses.append("%d known host%s are marching on the lane" % [
					int(threat_state.get("visible_marching", 0)),
					"" if int(threat_state.get("visible_marching", 0)) == 1 else "s",
				])
		if bool(threat_state.get("hidden_targeting", false)):
			threat_clauses.append("scouts report hostile movement beyond the fog")
		if int(threat_state.get("siege_progress", 0)) > 0:
			threat_clauses.append("siege pressure %d/%d is already building" % [
				int(threat_state.get("siege_progress", 0)),
				max(1, int(threat_state.get("siege_capture_progress", 1))),
			])
		var front_parts := ["Readiness %d" % readiness]
		if defense != "":
			front_parts.append(defense)
		if String(logistics.get("summary", "")) != "" and (int(logistics.get("support_gap", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0 or int(logistics.get("disrupted_count", 0)) > 0):
			front_parts.append(String(logistics.get("summary", "")))
		if bool(recovery.get("active", false)):
			front_parts.append(String(recovery.get("summary", "")))
		if bool(capital_project.get("vulnerable", false)):
			front_parts.append("capital project vulnerable")
		if objective_anchor:
			front_parts.append("objective anchor")
		items.append(
			{
				"key": "town:%s" % String(town.get("placement_id", "")),
				"town_placement_id": String(town.get("placement_id", "")),
				"severity": severity,
				"gate": severity >= 3,
				"summary": "%s exposed" % _town_name(town),
				"detail": "%s: %s | %s. %s" % [
					_town_name(town),
					"; ".join(threat_clauses),
					" | ".join(front_parts),
					_town_command_risk_consequence(town, readiness, logistics, recovery, capital_project, objective_anchor),
				],
			}
		)
	return items

static func _command_risk_logistics_items(session: SessionStateStoreScript.SessionData, pressured_town_ids: Dictionary) -> Array:
	var items := []
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var placement_id := String(town.get("placement_id", ""))
		if pressured_town_ids.has(placement_id):
			continue
		var logistics := town_logistics_state(session, town)
		if int(logistics.get("disrupted_count", 0)) <= 0 and int(logistics.get("threatened_count", 0)) <= 0 and int(logistics.get("support_gap", 0)) <= 0:
			continue
		var capital_project := town_capital_project_state(town, session)
		var recovery := town_recovery_state(session, town)
		var severity_score := int(logistics.get("disrupted_count", 0)) * 2 + int(logistics.get("threatened_count", 0)) + int(logistics.get("support_gap", 0))
		if int(logistics.get("response_count", 0)) <= 0 and int(logistics.get("threatened_count", 0)) > 0:
			severity_score += 1
		if town_strategic_role(town) in ["capital", "stronghold"]:
			severity_score += 1
		if bool(capital_project.get("vulnerable", false)):
			severity_score += 1
		var severity := 2
		if severity_score >= 6:
			severity = 5
		elif severity_score >= 4:
			severity = 4
		elif severity_score >= 2:
			severity = 3
		var route_clause := ""
		if logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
			route_clause = "Denied routes %s" % ", ".join(logistics.get("disrupted_site_labels", []).slice(0, min(2, logistics.get("disrupted_site_labels", []).size())))
		elif logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
			route_clause = "Threatened routes %s" % ", ".join(logistics.get("threatened_site_labels", []).slice(0, min(2, logistics.get("threatened_site_labels", []).size())))
		elif logistics.get("missing_family_labels", []) is Array and not logistics.get("missing_family_labels", []).is_empty():
			route_clause = "Missing anchors %s" % ", ".join(logistics.get("missing_family_labels", []).slice(0, min(2, logistics.get("missing_family_labels", []).size())))
		var consequence_parts := []
		if int(logistics.get("gap_readiness_penalty", 0)) > 0:
			consequence_parts.append("readiness -%d" % int(logistics.get("gap_readiness_penalty", 0)))
		if int(logistics.get("gap_growth_penalty_percent", 0)) > 0:
			consequence_parts.append("recruits -%d%%" % int(logistics.get("gap_growth_penalty_percent", 0)))
		if int(logistics.get("gap_pressure_penalty", 0)) > 0:
			consequence_parts.append("%s -%d" % [_town_pressure_label(town).to_lower(), int(logistics.get("gap_pressure_penalty", 0))])
		if bool(recovery.get("active", false)):
			consequence_parts.append("%d recovery pressure remains" % int(recovery.get("pressure", 0)))
		if bool(capital_project.get("vulnerable", false)) and String(capital_project.get("vulnerability_summary", "")) != "":
			consequence_parts.append(String(capital_project.get("vulnerability_summary", "")))
		items.append(
			{
				"key": "logistics:%s" % placement_id,
				"severity": severity,
				"gate": severity >= 4,
				"summary": "%s routes straining" % _town_name(town),
				"detail": "%s logistics: %s%s. Next day holds %s." % [
					_town_name(town),
					String(logistics.get("summary", "")),
					" | %s" % route_clause if route_clause != "" else "",
					", ".join(consequence_parts) if not consequence_parts.is_empty() else "the same exposed chain unless new response orders go out",
				],
			}
		)
	return items

static func _command_risk_objective_items(session: SessionStateStoreScript.SessionData, pressured_town_ids: Dictionary) -> Array:
	var items := []
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return items
	for objective in objectives.get("defeat", []):
		if not (objective is Dictionary):
			continue
		match String(objective.get("type", "")):
			"enemy_pressure_at_least":
				var pressure_item := _command_risk_pressure_objective_item(session, scenario, objective)
				if not pressure_item.is_empty():
					items.append(pressure_item)
			"encounter_resolved":
				var encounter_item := _command_risk_encounter_objective_item(session, objective)
				if not encounter_item.is_empty():
					items.append(encounter_item)
			"town_not_owned_by_player", "town_owned_by_player":
				var placement_id := String(objective.get("placement_id", ""))
				if placement_id == "" or pressured_town_ids.has(placement_id):
					continue
				var town_result := _find_town_by_placement(session, placement_id)
				if int(town_result.get("index", -1)) < 0:
					continue
				var town = town_result.get("town", {})
				if String(town.get("owner", "neutral")) != "player":
					items.append(
						{
							"key": "objective-town:%s" % placement_id,
							"severity": 5,
							"gate": true,
							"summary": "%s objective slipping" % _town_name(town),
							"detail": "%s is already off the banner line, and the defeat watch %s remains live." % [
								_town_name(town),
								String(objective.get("label", objective.get("id", "objective"))),
							],
						}
					)
	return items

static func _command_risk_posture_items(session: SessionStateStoreScript.SessionData) -> Array:
	var items := []
	var scenario := ContentService.get_scenario(session.scenario_id)
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		var state := _enemy_state_for_faction(session, faction_id)
		var current_pressure := int(state.get("pressure", 0))
		var threshold: int = _enemy_raid_threshold_for_strategy(session, config, faction_id)
		var active_raids: int = _enemy_active_raids(session, faction_id)
		var max_raids: int = _enemy_max_active_raids_for_strategy(session, config, faction_id)
		var posture := String(state.get("posture", "probing"))
		if active_raids >= max_raids:
			continue
		if current_pressure < max(1, threshold - 1) and posture not in ["massing", "raiding"]:
			continue
		var label := String(config.get("label", ContentService.get_faction(faction_id).get("name", faction_id)))
		var severity := 2
		if posture == "raiding" or current_pressure >= threshold:
			severity = 4
		elif posture == "massing" or current_pressure + _public_enemy_pressure_gain(session, config) >= threshold:
			severity = 3
		items.append(
			{
				"key": "posture:%s" % faction_id,
				"severity": severity,
				"gate": false,
				"summary": "%s raid window opening" % label,
				"detail": "%s sits at %d/%d pressure with %d/%d active raids. %s posture makes another host likely if the day ends without reducing pressure." % [
					label,
					current_pressure,
					threshold,
					active_raids,
					max_raids,
					_posture_label(posture),
				],
			}
		)
	return items

static func _command_risk_field_item(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var local_public_contacts := 0
	var nearest_distance := 9999
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or is_encounter_resolved(session, encounter):
			continue
		if not _raid_is_public(session, encounter):
			continue
		var distance = abs(int(encounter.get("x", 0)) - pos.x) + abs(int(encounter.get("y", 0)) - pos.y)
		if distance <= 2:
			local_public_contacts += 1
		nearest_distance = min(nearest_distance, distance)
	if local_public_contacts <= 0:
		return {}
	var nearest_town_result := _nearest_town_for_controller(session, "player", pos.x, pos.y)
	var nearest_town = nearest_town_result.get("town", {})
	var nearest_town_distance = 9999 if nearest_town.is_empty() else abs(pos.x - int(nearest_town.get("x", 0))) + abs(pos.y - int(nearest_town.get("y", 0)))
	if int(_find_active_town(session).get("index", -1)) >= 0:
		return {}
	if nearest_town_distance <= 2 and local_public_contacts <= 1:
		return {}
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	var severity := 3 if local_public_contacts > 1 or nearest_distance <= 1 else 2
	var town_clause := "no owned town anchors the current march line"
	if not nearest_town.is_empty():
		town_clause = "%s %d tile%s away" % [
			_town_name(nearest_town),
			nearest_town_distance,
			"" if nearest_town_distance == 1 else "s",
		]
	return {
		"key": "field:%d:%d" % [pos.x, pos.y],
		"severity": severity,
		"gate": severity >= 3,
		"summary": "Active command exposed",
		"detail": "The active command ends on %s at %d,%d with %d public hostile contact%s inside 2 tiles and %s. Ending here risks a strike on the march line." % [
			terrain,
			pos.x,
			pos.y,
			local_public_contacts,
			"" if local_public_contacts == 1 else "s",
			town_clause,
		],
	}

static func _command_risk_pressure_objective_item(
	session: SessionStateStoreScript.SessionData,
	scenario: Dictionary,
	objective: Dictionary
) -> Dictionary:
	if _scenario_objective_met(session, objective):
		return {}
	var faction_id := String(objective.get("faction_id", ""))
	var config := _enemy_config_for_faction(scenario, faction_id)
	if config.is_empty():
		return {}
	var current_pressure: int = _enemy_pressure(session, faction_id)
	var threshold := int(objective.get("threshold", 0))
	var gain := _public_enemy_pressure_gain(session, config)
	var posture := String(_enemy_state_for_faction(session, faction_id).get("posture", "probing"))
	if current_pressure + gain < threshold and not (posture == "massing" and threshold - current_pressure <= 2):
		return {}
	var label := String(objective.get("label", objective.get("id", "pressure objective")))
	var faction_label := String(config.get("label", ContentService.get_faction(faction_id).get("name", faction_id)))
	return {
		"key": "objective-pressure:%s:%s" % [faction_id, label],
		"severity": 4,
		"gate": true,
		"summary": "%s near trigger" % label,
		"detail": "%s sits at %d/%d pressure. %s posture plus roughly +%d public pressure/day makes the defeat watch %s a likely next-day trigger." % [
			faction_label,
			current_pressure,
			threshold,
			_posture_label(posture),
			gain,
			label,
		],
	}

static func _command_risk_encounter_objective_item(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> Dictionary:
	if _scenario_objective_met(session, objective):
		return {}
	var placement_id := String(objective.get("placement_id", ""))
	if placement_id == "":
		return {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or String(encounter.get("placement_id", "")) != placement_id:
			continue
		var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		if String(encounter.get("contested_by_faction_id", "")) != "":
			return {
				"key": "objective-encounter:%s" % placement_id,
				"severity": 4,
				"gate": true,
				"summary": "%s objective contested" % String(encounter_def.get("name", placement_id)),
				"detail": "%s is already under hostile contest, and the defeat watch %s stays live until the front is cleared." % [
					String(encounter_def.get("name", placement_id)),
					String(objective.get("label", objective.get("id", "objective"))),
				],
			}
		for raid in session.overworld.get("encounters", []):
			if not (raid is Dictionary) or String(raid.get("spawned_by_faction_id", "")) == "":
				continue
			if String(raid.get("target_kind", "")) != "encounter" or String(raid.get("target_placement_id", "")) != placement_id:
				continue
			return {
				"key": "objective-encounter:%s" % placement_id,
				"severity": 3,
				"gate": true,
				"summary": "%s objective pressured" % String(encounter_def.get("name", placement_id)),
				"detail": "%s is drawing hostile pressure, and leaving the day unresolved risks turning the defeat watch %s into a live front." % [
					String(encounter_def.get("name", placement_id)),
					String(objective.get("label", objective.get("id", "objective"))),
				],
			}
	return {}

static func _town_command_risk_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var state := {
		"visible_marching": 0,
		"visible_pressuring": 0,
		"hidden_targeting": false,
		"nearest_goal_distance": 9999,
		"marching_commanders": [],
		"pressuring_commanders": [],
		"siege_progress": 0,
		"siege_capture_progress": 1,
		"front_active": false,
		"front_mode": "",
		"front_faction_id": "",
		"front_enemy_label": "",
		"front_summary": "",
		"front_public_clause": "",
	}
	var scenario := ContentService.get_scenario(session.scenario_id)
	var placement_id := String(town.get("placement_id", ""))
	if placement_id == "":
		return state
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == "":
			continue
		if String(encounter.get("target_kind", "")) != "town" or String(encounter.get("target_placement_id", "")) != placement_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		var is_public: bool = _raid_is_public(session, encounter)
		var goal_distance := int(encounter.get("goal_distance", 9999))
		var is_pressuring := bool(encounter.get("arrived", false)) or goal_distance <= 0
		var commander_name := encounter_commander_threat_label(encounter)
		if is_public:
			if is_pressuring:
				state["visible_pressuring"] = int(state.get("visible_pressuring", 0)) + 1
				if commander_name != "" and commander_name not in state.get("pressuring_commanders", []):
					var pressuring_commanders: Array = state.get("pressuring_commanders", [])
					pressuring_commanders.append(commander_name)
					state["pressuring_commanders"] = pressuring_commanders
			else:
				state["visible_marching"] = int(state.get("visible_marching", 0)) + 1
				state["nearest_goal_distance"] = min(int(state.get("nearest_goal_distance", 9999)), goal_distance)
				if commander_name != "" and commander_name not in state.get("marching_commanders", []):
					var marching_commanders: Array = state.get("marching_commanders", [])
					marching_commanders.append(commander_name)
					state["marching_commanders"] = marching_commanders
		else:
			state["hidden_targeting"] = true
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		if String(config.get("siege_target_placement_id", "")) != placement_id:
			continue
		var faction_state := _enemy_state_for_faction(session, String(config.get("faction_id", "")))
		state["siege_progress"] = max(int(state.get("siege_progress", 0)), int(faction_state.get("siege_progress", 0)))
		state["siege_capture_progress"] = max(1, int(config.get("siege_capture_progress", 1)))
	if int(state.get("nearest_goal_distance", 9999)) == 9999 and int(state.get("visible_pressuring", 0)) > 0:
		state["nearest_goal_distance"] = 0
	var front_state := _town_front_state(session, town)
	state["front_active"] = bool(front_state.get("active", false))
	state["front_mode"] = String(front_state.get("mode", ""))
	state["front_faction_id"] = String(front_state.get("faction_id", ""))
	state["front_enemy_label"] = String(front_state.get("enemy_label", ""))
	state["front_summary"] = String(front_state.get("summary", ""))
	state["front_public_clause"] = String(front_state.get("public_clause", ""))
	return state

static func _town_command_risk_consequence(
	town: Dictionary,
	readiness: int,
	logistics: Dictionary,
	recovery: Dictionary,
	capital_project: Dictionary,
	objective_anchor: bool
) -> String:
	if bool(capital_project.get("vulnerable", false)) and String(capital_project.get("vulnerability_summary", "")) != "":
		return String(capital_project.get("vulnerability_summary", ""))
	var consequence_parts := []
	if int(logistics.get("gap_readiness_penalty", 0)) > 0:
		consequence_parts.append("readiness stays -%d" % int(logistics.get("gap_readiness_penalty", 0)))
	if int(logistics.get("gap_growth_penalty_percent", 0)) > 0:
		consequence_parts.append("recruits stay -%d%%" % int(logistics.get("gap_growth_penalty_percent", 0)))
	if bool(recovery.get("active", false)):
		consequence_parts.append("%d recovery pressure remains" % int(recovery.get("pressure", 0)))
	if not consequence_parts.is_empty():
		return "If you hold this posture, %s." % ", ".join(consequence_parts)
	if readiness <= 18 or _town_defense_summary(town) == "thin watch":
		return "Ending the day here leaves a live siege window on the town."
	if objective_anchor:
		return "This lane also sits on an active objective track."
	return "Another quiet day leaves the front open to hostile pressure."

static func _public_enemy_pressure_gain(session: SessionStateStoreScript.SessionData, config: Dictionary) -> int:
	return max(
		1,
		DifficultyRulesScript.adjust_enemy_pressure_gain(
			session,
			max(0, int(config.get("pressure_per_day", 0)) + int(config.get("pressure_per_enemy_town", 0)))
		)
	)

static func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

static func _enemy_state_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

static func _scenario_town_started_enemy(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	if session == null or placement_id == "":
		return false
	var scenario := ContentService.get_scenario(session.scenario_id)
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return String(town.get("owner", "neutral")) == "enemy"
	return false

static func _town_is_objective_anchor(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	if session == null or placement_id == "":
		return false
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if objective is Dictionary and String(objective.get("placement_id", "")) == placement_id:
				return true
	return false

static func _command_risk_grade_label(severity: int) -> String:
	match clampi(severity, 0, 5):
		5:
			return "Severe"
		4:
			return "High"
		3:
			return "Elevated"
		2:
			return "Guarded"
		1:
			return "Low"
		_:
			return "Steady"

static func _posture_label(posture: String) -> String:
	match posture:
		"fortifying":
			return "fortifying"
		"raiding":
			return "raiding"
		"massing":
			return "massing"
		"collapsed":
			return "collapsed"
		_:
			return "probing"

static func _army_totals(army: Dictionary) -> Dictionary:
	var headcount := 0
	var groups := 0
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var count = max(0, int(stack.get("count", 0)))
		if count <= 0:
			continue
		headcount += count
		groups += 1
	return {"headcount": headcount, "groups": groups}

static func _refresh_all_player_heroes_for_new_day(session: SessionStateStoreScript.SessionData) -> void:
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var synced_active := false
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary):
			continue
		hero = SpellRulesScript.refresh_daily_mana(hero)
		var movement_max := _movement_max_from_hero(hero, session)
		hero["movement"] = {"current": movement_max, "max": movement_max}
		heroes[index] = hero
		if String(hero.get("id", "")) != active_hero_id:
			continue
		synced_active = true
		session.overworld["hero"] = hero.duplicate(true)
		session.overworld["army"] = hero.get("army", {}).duplicate(true)
		session.overworld["movement"] = hero.get("movement", {}).duplicate(true)
		session.overworld["hero_position"] = hero.get("position", {}).duplicate(true)
	session.overworld["player_heroes"] = heroes
	if synced_active:
		return
	var active_hero := HeroCommandRulesScript.active_hero(session)
	if active_hero.is_empty():
		return
	session.overworld["hero"] = active_hero.duplicate(true)
	session.overworld["army"] = active_hero.get("army", {}).duplicate(true)
	session.overworld["movement"] = active_hero.get("movement", {}).duplicate(true)
	session.overworld["hero_position"] = active_hero.get("position", {}).duplicate(true)
