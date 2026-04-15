class_name OverworldRules
extends RefCounted

const SessionStateStore = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRules = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRules = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRules = preload("res://scripts/core/ArtifactRules.gd")
const HeroProgressionRules = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRules = preload("res://scripts/core/SpellRules.gd")

const FOG_KEY := "fog"
const VISIBLE_TILES_KEY := "visible_tiles"
const EXPLORED_TILES_KEY := "explored_tiles"
const COMMAND_BRIEFING_KEY := "command_briefing"
const COMMAND_RISK_FORECAST_KEY := "command_risk_forecast"
const WEEKLY_GROWTH_INTERVAL := 7
const BUILDING_CATEGORIES := ["civic", "dwelling", "economy", "support", "magic"]
const LOGISTICS_SITE_FAMILIES := ["neutral_dwelling", "faction_outpost", "frontier_shrine"]

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func _scenario_rules() -> Variant:
	return load("res://scripts/core/ScenarioRules.gd")

static func _scenario_script_rules() -> Variant:
	# Validator anchor: ScenarioScriptRules.describe_recent_events
	return load("res://scripts/core/ScenarioScriptRules.gd")

static func _enemy_turn_rules() -> Variant:
	return load("res://scripts/core/EnemyTurnRules.gd")

static func _enemy_adventure_rules() -> Variant:
	return load("res://scripts/core/EnemyAdventureRules.gd")

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

static func _normalize_scenario_state_rules(session: SessionStateStore.SessionData) -> void:
	_scenario_rules().normalize_scenario_state(session)

static func _evaluate_scenario_state(session: SessionStateStore.SessionData) -> Dictionary:
	return _scenario_rules().evaluate_session(session)

static func _scenario_opening_objective_summary(session: SessionStateStore.SessionData, scenario: Dictionary) -> String:
	return _scenario_rules()._opening_objective_summary(session, scenario)

static func _scenario_enemy_operational_lines(session: SessionStateStore.SessionData, scenario: Dictionary) -> Array:
	return _scenario_rules()._enemy_operational_lines(session, scenario)

static func _scenario_first_contact_summary(scenario: Dictionary) -> String:
	return _scenario_rules()._first_contact_summary(scenario)

static func _scenario_objective_labels_from_bucket(session: SessionStateStore.SessionData, bucket: Variant, limit: int) -> Array:
	return _scenario_rules()._objective_labels_from_bucket(session, bucket, limit)

static func _scenario_objective_met(session: SessionStateStore.SessionData, objective: Dictionary) -> bool:
	return _scenario_rules()._objective_met(session, objective)

static func _scenario_is_objective_met(session: SessionStateStore.SessionData, objective_id: String, bucket: String) -> bool:
	return _scenario_rules().is_objective_met(session, objective_id, bucket)

static func _scenario_describe_objectives(session: SessionStateStore.SessionData) -> String:
	return _scenario_rules().describe_objectives(session)

static func _describe_recent_events(session: SessionStateStore.SessionData, limit: int) -> String:
	return _scenario_script_rules().describe_recent_events(session, limit)

static func _normalize_enemy_states(session: SessionStateStore.SessionData) -> void:
	_enemy_turn_rules().normalize_enemy_states(session)

static func _run_enemy_turn_cycle(session: SessionStateStore.SessionData) -> Dictionary:
	return _enemy_turn_rules().run_enemy_turn(session)

static func _describe_enemy_threats(session: SessionStateStore.SessionData) -> String:
	return _enemy_turn_rules().describe_threats(session)

static func _enemy_pressure(session: SessionStateStore.SessionData, faction_id: String) -> int:
	return _enemy_turn_rules().get_pressure(session, faction_id)

static func _enemy_active_raids(session: SessionStateStore.SessionData, faction_id: String) -> int:
	return _enemy_turn_rules().active_raid_count(session, faction_id)

static func _enemy_raid_threshold_for_strategy(session: SessionStateStore.SessionData, config: Dictionary, faction_id: String) -> int:
	return _enemy_turn_rules()._raid_threshold_for_strategy(session, config, faction_id)

static func _enemy_max_active_raids_for_strategy(session: SessionStateStore.SessionData, config: Dictionary, faction_id: String) -> int:
	return _enemy_turn_rules()._max_active_raids_for_strategy(session, config, faction_id)

static func _raid_target_is_objective_anchor(session: SessionStateStore.SessionData, target_kind: String, placement_id: String) -> bool:
	return _enemy_adventure_rules().target_is_objective_anchor(session, target_kind, placement_id)

static func _raid_is_public(session: SessionStateStore.SessionData, encounter: Dictionary) -> bool:
	return _enemy_adventure_rules()._raid_is_public(session, encounter)

static func normalize_overworld_state(session: SessionStateStore.SessionData) -> void:
	if session == null:
		return
	session.save_version = SessionStateStore.SAVE_VERSION
	DifficultyRules.normalize_session(session)

	var scenario := ContentService.get_scenario(session.scenario_id)
	var hero_id := session.hero_id
	if hero_id == "":
		hero_id = String(scenario.get("hero_id", ""))
		session.hero_id = hero_id
	var player_army_id := String(scenario.get("player_army_id", session.overworld.get("player_army_id", "")))
	HeroCommandRules.normalize_session(
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

	if not session.overworld.has("resource_nodes") or not (session.overworld.get("resource_nodes") is Array):
		session.overworld["resource_nodes"] = _build_scenario_resource_states(scenario.get("resource_nodes", []))
	else:
		session.overworld["resource_nodes"] = _normalize_resource_nodes(session.overworld.get("resource_nodes", []))

	if not session.overworld.has("artifact_nodes") or not (session.overworld.get("artifact_nodes") is Array):
		session.overworld["artifact_nodes"] = ArtifactRules.build_artifact_nodes(scenario.get("artifact_nodes", []))
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
	if not session.overworld.has("hero_position") or not (session.overworld.get("hero_position") is Dictionary):
		session.overworld["hero_position"] = scenario.get("start", {"x": 0, "y": 0})
	_normalize_fog_of_war(session)
	_normalize_command_briefing(session)
	_normalize_command_risk_forecast(session)

	_normalize_scenario_state_rules(session)

static func normalize_overworld_state_bridge(session) -> void:
	normalize_overworld_state(session)

static func refresh_fog_of_war(session: SessionStateStore.SessionData) -> void:
	if session == null:
		return
	if not session.overworld.has("map") or not (session.overworld.get("map") is Array):
		return
	_normalize_fog_of_war(session)

static func is_tile_visible(session: SessionStateStore.SessionData, x: int, y: int) -> bool:
	if session == null:
		return false
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = session.overworld.get(FOG_KEY, {})
	return _grid_cell(fog.get(VISIBLE_TILES_KEY, []), x, y)

static func is_tile_explored(session: SessionStateStore.SessionData, x: int, y: int) -> bool:
	if session == null:
		return false
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = session.overworld.get(FOG_KEY, {})
	return _grid_cell(fog.get(EXPLORED_TILES_KEY, []), x, y)

static func describe_visibility(session: SessionStateStore.SessionData) -> String:
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

static func try_move(session: SessionStateStore.SessionData, dx: int, dy: int) -> Dictionary:
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

	var messages := ["Moved to %d,%d." % [nx, ny]]
	var town_result := _find_active_town(session)
	var town = town_result.get("town", {})
	if not town.is_empty() and String(town.get("owner", "neutral")) != "player":
		messages.append(_claim_town(session, town_result))

	return _finalize_action_result(session, true, " ".join(messages))

static func end_turn(session: SessionStateStore.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	HeroCommandRules.commit_active_hero(session)
	session.day += 1

	var recovery_messages := _advance_all_town_recovery(session)
	var town_income := {"gold": 0, "wood": 0, "ore": 0}
	var weekly_growth_messages := []
	var should_apply_weekly_growth := is_weekly_growth_day(session.day)
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue

		var income := DifficultyRules.scale_income_resources(session, _calculate_town_income(town))
		town_income = _add_resource_sets(town_income, income)
		if should_apply_weekly_growth:
			var growth_summary := _describe_recruit_delta(_growth_tick_town(session, town))
			if growth_summary != "":
				weekly_growth_messages.append("%s (%s)" % [_town_name(town), growth_summary])
		towns[index] = town
	session.overworld["towns"] = towns

	var hero_state = session.overworld.get("hero", {})
	var artifact_income = DifficultyRules.scale_income_resources(
		session,
		ArtifactRules.aggregate_bonuses(hero_state).get("daily_income", {})
	)
	var specialty_income = HeroProgressionRules.daily_income_bonus(hero_state)
	var site_income = DifficultyRules.scale_income_resources(session, controlled_resource_site_income(session, "player"))
	var site_muster_messages := []
	if should_apply_weekly_growth:
		site_muster_messages = apply_controlled_resource_site_musters(session, "player")
	_add_resources(
		session,
		_add_resource_sets(
			_add_resource_sets(_add_resource_sets(town_income, artifact_income), specialty_income),
			site_income
		)
	)
	_refresh_all_player_heroes_for_new_day(session)
	hero_state = session.overworld.get("hero", {})

	var messages := ["Day %d begins." % session.day]
	var town_income_summary := _describe_resource_delta(town_income)
	if town_income_summary != "":
		messages.append("Town income %s." % town_income_summary)
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
	var enemy_turn_result: Dictionary = _run_enemy_turn_cycle(session)
	var enemy_message := String(enemy_turn_result.get("message", ""))
	if enemy_message != "":
		messages.append(enemy_message)
	return _finalize_action_result(session, true, " ".join(messages))

static func collect_active_resource(session: SessionStateStore.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var node_result := _find_resource_node_at(session)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No resource site here."}

	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if site.is_empty():
		return {"ok": false, "message": "This site has no authored payload."}
	if not _resource_node_claimable_by_player(node, site):
		if _resource_site_is_persistent(site):
			return {"ok": false, "message": "This site is already under your control."}
		return {"ok": false, "message": "This site has already been gathered."}

	var nodes = session.overworld.get("resource_nodes", [])
	var previous_controller := String(node.get("collected_by_faction_id", ""))
	node["collected"] = true
	node["collected_by_faction_id"] = "player"
	node["collected_day"] = session.day
	node = _clear_resource_site_response(node)
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes

	var rewards = DifficultyRules.scale_reward_resources(session, _resource_site_claim_rewards(site))
	_add_resources(session, rewards)
	var disruption_message := apply_resource_site_disruption(
		session,
		node,
		site,
		previous_controller,
		"player"
	)
	var messages := [_resource_site_claim_message(site, previous_controller)]
	var reward_summary := _describe_resource_delta(rewards)
	if reward_summary != "":
		messages.append("Stores %s." % reward_summary)
	var recruit_message := _grant_site_claim_recruits(session, site.get("claim_recruits", {}))
	if recruit_message != "":
		messages.append(recruit_message)
	var spell_message := _learn_site_spell(session, String(site.get("learn_spell_id", "")))
	if spell_message != "":
		messages.append(spell_message)
	if disruption_message != "":
		messages.append(disruption_message)
	messages.append_array(_award_experience(session, int(rewards.get("experience", 0))))
	return _finalize_action_result(session, true, " ".join(messages))

static func collect_active_artifact(session: SessionStateStore.SessionData) -> Dictionary:
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

	return _finalize_action_result(session, true, String(pickup_result.get("message", "Recovered artifact.")))

static func perform_context_action(session: SessionStateStore.SessionData, action_id: String) -> Dictionary:
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

static func award_hero_artifact(
	session: SessionStateStore.SessionData,
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

static func capture_active_town(session: SessionStateStore.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	var town_result := _find_active_town(session)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No town stands here."}

	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) == "player":
		return {"ok": false, "message": "This town already flies your banner."}

	return _finalize_action_result(session, true, _claim_town(session, town_result))

static func build_in_active_town(session: SessionStateStore.SessionData, building_id: String) -> Dictionary:
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
		return {"ok": false, "message": "Insufficient resources for %s." % String(building.get("name", building_id))}

	_spend_resources(session, cost)
	var built_buildings = _normalize_built_buildings_for_town_state(town)
	built_buildings.append(building_id)
	town["built_buildings"] = built_buildings
	town["available_recruits"] = _add_recruit_growth(
		town.get("available_recruits", {}),
		HeroProgressionRules.scale_recruit_growth(
			session.overworld.get("hero", {}),
			_building_growth_payload(building_id)
		)
	)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return _finalize_action_result(
		session,
		true,
		"Built %s in %s." % [String(building.get("name", building_id)), _town_name(town)]
	)

static func recruit_in_active_town(session: SessionStateStore.SessionData, unit_id: String, requested_count: int = -1) -> Dictionary:
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
		return {"ok": false, "message": "Resources are too thin to recruit %s." % String(unit.get("name", unit_id))}

	_spend_resources(session, _multiply_cost(adjusted_unit_cost, recruit_count))
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
	return _finalize_action_result(
		session,
		true,
		"Recruited %d %s." % [recruit_count, String(unit.get("name", unit_id))]
	)

static func cast_overworld_spell(session: SessionStateStore.SessionData, spell_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var hero = session.overworld.get("hero", {})
	var movement = session.overworld.get("movement", {})
	var result := SpellRules.cast_overworld_spell(hero, movement, spell_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Spell casting failed."))}

	session.overworld["hero"] = result.get("hero", hero)
	session.overworld["movement"] = result.get("movement", movement)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func equip_artifact(session: SessionStateStore.SessionData, artifact_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRules.equip_artifact(session.overworld.get("hero", {}), artifact_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to equip artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func unequip_artifact(session: SessionStateStore.SessionData, slot: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRules.unequip_artifact(session.overworld.get("hero", {}), slot)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to stow artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func perform_artifact_action(session: SessionStateStore.SessionData, action_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRules.perform_management_action(session.overworld.get("hero", {}), action_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to manage artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func get_active_context(session: SessionStateStore.SessionData) -> Dictionary:
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

static func get_active_encounter(session: SessionStateStore.SessionData) -> Dictionary:
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

static func is_encounter_resolved(session: SessionStateStore.SessionData, encounter: Dictionary) -> bool:
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

static func hero_position(session: SessionStateStore.SessionData) -> Vector2i:
	var pos = session.overworld.get("hero_position", {"x": 0, "y": 0})
	return Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))

static func derive_map_size(session: SessionStateStore.SessionData) -> Vector2i:
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

static func tile_is_blocked(session: SessionStateStore.SessionData, x: int, y: int) -> bool:
	var map_data = session.overworld.get("map", [])
	if y < 0 or not (map_data is Array) or y >= map_data.size():
		return false
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return false
	return String(row[x]) == "water"

static func describe_resources(session: SessionStateStore.SessionData) -> String:
	var resources = session.overworld.get("resources", {})
	return "Gold %d | Wood %d | Ore %d" % [
		int(resources.get("gold", 0)),
		int(resources.get("wood", 0)),
		int(resources.get("ore", 0)),
	]

static func describe_status(session: SessionStateStore.SessionData) -> String:
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

static func _week_of_day(day: int) -> int:
	return int(floori(float(max(day, 1) - 1) / 7.0)) + 1

static func _weekday_of_day(day: int) -> int:
	return ((max(day, 1) - 1) % 7) + 1

static func describe_hero(session: SessionStateStore.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	var command = hero.get("command", {})
	var mana = hero.get("spellbook", {}).get("mana", {})
	var position = hero.get("position", {})
	var army = hero.get("army", {})
	var stack_count := 0
	for stack in army.get("stacks", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			stack_count += 1
	var base := "%s Lv%d XP %d/%d | Command A%d D%d P%d K%d" % [
		String(hero.get("name", "Hero")),
		int(hero.get("level", 1)),
		int(hero.get("experience", 0)),
		int(hero.get("next_level_experience", 250)),
		int(command.get("attack", 0)),
		int(command.get("defense", 0)),
		int(command.get("power", 0)),
		int(command.get("knowledge", 0)),
	]
	var profile := HeroCommandRules.hero_profile_summary(hero, true)
	var profile_line := "%s | %s" % [
		HeroCommandRules.hero_archetype_label(hero),
		HeroProgressionRules.brief_summary(hero),
	]
	if profile != "":
		profile_line = "%s | %s" % [profile_line, profile]
	return "%s\n%s\nField position %d,%d | Scout %d | Mana %d/%d | Army groups %d" % [
		base,
		profile_line,
		int(position.get("x", 0)),
		int(position.get("y", 0)),
		HeroCommandRules.scouting_radius_for_hero(hero),
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		stack_count,
	]

static func _overworld_hero_line(hero: Dictionary) -> String:
	var position = hero.get("position", {})
	var army = hero.get("army", {})
	var headcount := 0
	var groups := 0
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		headcount += count
		groups += 1
	return "%s Lv%d | Pos %d,%d | Scout %d | %d troops/%d groups" % [
		"%s (%s)" % [String(hero.get("name", "Hero")), HeroCommandRules.hero_archetype_label(hero)],
		int(hero.get("level", 1)),
		int(position.get("x", 0)),
		int(position.get("y", 0)),
		HeroCommandRules.scouting_radius_for_hero(hero),
		headcount,
		groups,
	]

static func describe_heroes(session: SessionStateStore.SessionData) -> String:
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

static func describe_army(session: SessionStateStore.SessionData) -> String:
	var army = session.overworld.get("army", {})
	var parts := []
	var headcount := 0
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var unit = ContentService.get_unit(String(stack.get("unit_id", "")))
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		headcount += count
		parts.append("%s x%d" % [String(unit.get("name", stack.get("unit_id", ""))), count])
	return "Marching Army\n%d troops in %d groups\n%s" % [
		headcount,
		parts.size(),
		", ".join(parts) if not parts.is_empty() else "No standing force",
	]

static func is_weekly_growth_day(day: int) -> bool:
	return day > 1 and ((day - 1) % WEEKLY_GROWTH_INTERVAL) == 0

static func days_until_next_weekly_growth(day: int) -> int:
	return WEEKLY_GROWTH_INTERVAL - ((max(day, 1) - 1) % WEEKLY_GROWTH_INTERVAL)

static func next_weekly_growth_day(day: int) -> int:
	return max(day, 1) + days_until_next_weekly_growth(day)

static func describe_town_context(town: Dictionary, session: SessionStateStore.SessionData = null) -> String:
	var income := _describe_resource_delta(_calculate_town_income(town))
	var weekly_growth := _describe_recruit_delta(town_weekly_growth(town, session))
	var defense := _town_defense_summary(town)
	var readiness := town_battle_readiness(town, session)
	var pressure_output := town_pressure_output(town, session)
	var strategic_role := town_strategic_role(town)
	var capital_project := town_capital_project_state(town, session)
	var battlefront := town_battlefront_profile(town)
	var parts := [
		_town_name(town),
		String(ContentService.get_faction(_town_faction_id(town)).get("name", _town_faction_id(town))),
		"Owner %s" % String(town.get("owner", "neutral")).capitalize(),
	]
	if strategic_role == "capital":
		parts.append("Capital Anchor")
	elif strategic_role == "stronghold":
		parts.append("Frontier Stronghold")
	if income != "":
		parts.append("Daily %s" % income)
	if weekly_growth != "":
		parts.append("Weekly %s" % weekly_growth)
	if defense != "":
		parts.append("Defense %s" % defense)
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

static func describe_visibility_panel(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	var controlled_outposts := controlled_resource_site_count(session, "player", "faction_outpost")
	var controlled_shrines := controlled_resource_site_count(session, "player", "frontier_shrine")
	var lines := [
		"Scout Net",
		"- %s" % describe_visibility(session),
		"- Controlled heroes %d | Current reveal radius follows every marching commander." % HeroCommandRules.player_hero_count(session),
	]
	if controlled_outposts > 0:
		lines.append("- Held outposts %d | Frontier relays extend sight beyond commander scout rings." % controlled_outposts)
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
				HeroCommandRules.scouting_radius_for_hero(hero),
				" | Active" if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")) else "",
			]
		)
	return "\n".join(lines)

static func describe_context(session: SessionStateStore.SessionData) -> String:
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
				_resource_site_family_label(site),
				terrain,
				String(site.get("name", "Resource Cache")),
				_resource_site_context_summary(session, node, site),
			]
		"artifact":
			var artifact_node = context.get("node", {})
			return "Artifact Cache\nTerrain %s | %s\nRecovering the cache adds the relic to the active hero inventory." % [
				terrain,
				ArtifactRules.describe_artifact(String(artifact_node.get("artifact_id", ""))),
			]
		"encounter":
			var placement = context.get("encounter", {})
			var encounter = ContentService.get_encounter(String(placement.get("encounter_id", placement.get("id", ""))))
			return "Hostile Contact\nTerrain %s | %s\nApproach strength unknown beyond authored scouting notes. Enter battle to break the host." % [
				terrain,
				String(encounter.get("name", "Skirmish")),
			]
		_:
			return "Open Ground\nTerrain %s | No immediate site action.\nUse the movement controls to scout, consolidate towns, or intercept raids." % terrain

static func _terrain_name_at(session: SessionStateStore.SessionData, x: int, y: int) -> String:
	var map_data = session.overworld.get("map", [])
	if y < 0 or not (map_data is Array) or y >= map_data.size():
		return "Unknown terrain"
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return "Unknown terrain"
	match String(row[x]):
		"grass":
			return "Grassland"
		"forest":
			return "Forest"
		"water":
			return "Sea"
		_:
			var terrain := String(row[x])
			return terrain.capitalize() if terrain != "" else "Open ground"

static func describe_objective_board(session: SessionStateStore.SessionData) -> String:
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
		_scenario_describe_objectives(session),
	]

static func describe_objectives(session: SessionStateStore.SessionData) -> String:
	return describe_objective_board(session)

static func describe_frontier_threats(session: SessionStateStore.SessionData) -> String:
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
	return "\n".join(lines)

static func _local_visible_threat_summary(session: SessionStateStore.SessionData, fallback: String = "") -> String:
	var pos := hero_position(session)
	var visible_contacts := 0
	var local_contacts := 0
	var nearest_contact_name := ""
	var nearest_contact_distance := 99999
	var visible_enemy_towns := 0
	var visible_denied_sites := 0
	var visible_contested_fronts := 0
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
			var encounter_id := String(encounter.get("encounter_id", encounter.get("id", "")))
			nearest_contact_name = String(ContentService.get_encounter(encounter_id).get("name", "hostile contact"))
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
		parts.append("%d hostile contact%s operating within 3 tiles" % [local_contacts, "" if local_contacts == 1 else "s"])
	elif nearest_contact_name != "":
		parts.append("Nearest hostile contact %s at %d tiles" % [nearest_contact_name, nearest_contact_distance])
	elif visible_contacts > 0:
		parts.append("%d hostile contact%s visible on the frontier" % [visible_contacts, "" if visible_contacts == 1 else "s"])
	if visible_enemy_towns > 0:
		parts.append("%d enemy-held town%s currently confirmed by scouts" % [visible_enemy_towns, "" if visible_enemy_towns == 1 else "s"])
	if visible_denied_sites > 0:
		parts.append("%d frontier site%s already denied by hostile forces" % [visible_denied_sites, "" if visible_denied_sites == 1 else "s"])
	if visible_contested_fronts > 0:
		parts.append("%d neutral front%s under hostile contest" % [visible_contested_fronts, "" if visible_contested_fronts == 1 else "s"])
	if parts.is_empty():
		return fallback
	return " | ".join(parts)

static func describe_enemy_threats(session: SessionStateStore.SessionData) -> String:
	return describe_frontier_threats(session)

static func describe_spellbook(session: SessionStateStore.SessionData) -> String:
	return SpellRules.describe_spellbook(session.overworld.get("hero", {}))

static func describe_specialties(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	return HeroProgressionRules.describe_specialties(session.overworld.get("hero", {}))

static func describe_artifacts(session: SessionStateStore.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	return ArtifactRules.describe_management(hero)

static func describe_command_briefing(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	if not _should_surface_command_briefing(session):
		return ""
	return "\n".join(_command_briefing_lines(session))

static func consume_command_briefing(session: SessionStateStore.SessionData) -> String:
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

static func describe_command_risk(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	var forecast := _command_risk_forecast(session)
	if not bool(forecast.get("has_risk", false)):
		return "Command Risk\nSteady watch | No concrete next-day break is signaled from the current frontier watch."
	return "Command Risk\n%s" % String(forecast.get("summary", ""))

static func describe_commitment_board(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	var lines := [
		"Command Commitment",
		"- Immediate order: %s" % _command_commitment_action_line(session),
		"- Route pressure: %s" % _command_commitment_route_line(session),
		"- Coverage: %s" % _command_commitment_coverage_line(session),
		"- If you hold: %s" % _command_commitment_hold_line(session),
	]
	return "\n".join(lines)

static func describe_command_risk_forecast(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	var forecast := _command_risk_forecast(session)
	if not bool(forecast.get("has_risk", false)):
		return ""
	return "\n".join(forecast.get("lines", []))

static func consume_command_risk_forecast(session: SessionStateStore.SessionData) -> String:
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

static func describe_dispatch(session: SessionStateStore.SessionData, last_message: String = "") -> String:
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
	var recent_events: String = _describe_recent_events(session, 2)
	if recent_events != "":
		lines.append("- Scenario pulse: %s" % recent_events)
	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		lines.append("- Outcome pending: %s" % session.scenario_summary)
	return "\n".join(lines)

static func _dispatch_context_brief(session: SessionStateStore.SessionData) -> String:
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
			return "%s on %s" % [ArtifactRules.describe_artifact(String(artifact_node.get("artifact_id", ""))), terrain]
		"encounter":
			var encounter_placement = context.get("encounter", {})
			var encounter := ContentService.get_encounter(String(encounter_placement.get("encounter_id", "")))
			return "%s on %s" % [String(encounter.get("name", "Hostile contact")), terrain]
		_:
			return "Open ground at %d,%d on %s" % [pos.x, pos.y, terrain]

static func town_weekly_growth(town: Dictionary, session: SessionStateStore.SessionData = null) -> Dictionary:
	return _town_weekly_growth(town, session)

static func town_income(town: Dictionary) -> Dictionary:
	return _calculate_town_income(town)

static func town_reinforcement_quality(town: Dictionary, session: SessionStateStore.SessionData = null) -> int:
	return _town_reinforcement_quality(town, session)

static func town_battle_readiness(town: Dictionary, session: SessionStateStore.SessionData = null) -> int:
	return _town_battle_readiness(town, session)

static func town_pressure_output(town: Dictionary, session: SessionStateStore.SessionData = null) -> int:
	return _town_pressure_output(town, session)

static func town_strategic_role(town: Dictionary) -> String:
	return _town_strategic_role(town)

static func town_strategic_summary(town: Dictionary) -> String:
	return _town_strategic_summary(town)

static func town_capital_project_state(town: Dictionary, session: SessionStateStore.SessionData = null) -> Dictionary:
	return _town_capital_project_state(town, session)

static func town_logistics_state(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
	return _town_logistics_state(session, town)

static func town_recovery_state(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
	return _town_recovery_state(session, town)

static func town_public_threat_state(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
	return _town_command_risk_state(session, town)

static func town_battlefront_profile(town: Dictionary) -> Dictionary:
	return _town_battlefront_profile(town)

static func town_market_state(town: Dictionary) -> Dictionary:
	return _town_market_state(town)

static func describe_town_market(session: SessionStateStore.SessionData, town: Dictionary) -> String:
	return "\n".join(_town_market_panel_lines(session, town))

static func get_town_market_actions(session: SessionStateStore.SessionData, town: Dictionary) -> Array:
	return _town_market_actions(session, town)

static func perform_town_market_action(
	session: SessionStateStore.SessionData,
	town: Dictionary,
	action_id: String
) -> Dictionary:
	return _execute_town_market_action(session, town, action_id)

static func describe_town_response_panel(session: SessionStateStore.SessionData, town: Dictionary) -> String:
	return "\n".join(_town_response_panel_lines(session, town))

static func get_town_response_actions(session: SessionStateStore.SessionData, town: Dictionary) -> Array:
	return _town_response_actions(session, town)

static func perform_town_response_action(
	session: SessionStateStore.SessionData,
	town: Dictionary,
	action_id: String
) -> Dictionary:
	return _execute_town_response_action(session, town, action_id)

static func controlled_resource_site_income(session: SessionStateStore.SessionData, controller_id: String) -> Dictionary:
	var income := {"gold": 0, "wood": 0, "ore": 0}
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		income = _add_resource_sets(income, site.get("control_income", {}))
	return income

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

static func controlled_resource_site_pressure_bonus(session: SessionStateStore.SessionData, controller_id: String) -> int:
	var total := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		total += max(0, int(site.get("pressure_bonus", 0)))
		var weekly_recruits = site.get("weekly_recruits", {})
		if controller_id != "player" and weekly_recruits is Dictionary and not weekly_recruits.is_empty():
			total += 1
	return total

static func player_resource_site_pressure_guard(session: SessionStateStore.SessionData) -> int:
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

static func apply_controlled_resource_site_musters(session: SessionStateStore.SessionData, controller_id: String) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var weekly_recruits = site.get("weekly_recruits", {})
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
	session: SessionStateStore.SessionData,
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

static func describe_management_watch(session: SessionStateStore.SessionData) -> String:
	normalize_overworld_state(session)
	var project_summary := ""
	var disruption_summary := ""
	var recovery_summary := ""
	var project_score := -1
	var disruption_score := -1
	var recovery_score := -1
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
	var parts := []
	if project_summary != "":
		parts.append(project_summary)
	if disruption_summary != "":
		parts.append(disruption_summary)
	if recovery_summary != "":
		parts.append(recovery_summary)
	if parts.is_empty():
		return "Town lines are stable."
	return " | ".join(parts)

static func describe_town_build_projection(
	session: SessionStateStore.SessionData,
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
	session: SessionStateStore.SessionData,
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
	session: SessionStateStore.SessionData,
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
	session: SessionStateStore.SessionData,
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

static func town_recruit_cost(session: SessionStateStore.SessionData, town: Dictionary, unit_id: String) -> Dictionary:
	var unit := ContentService.get_unit(unit_id)
	var adjusted_cost := HeroProgressionRules.scale_recruit_cost(session.overworld.get("hero", {}), unit.get("cost", {}))
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

static func get_context_actions(session: SessionStateStore.SessionData) -> Array:
	var actions := []
	var context := get_active_context(session)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			if String(town.get("owner", "neutral")) != "player":
				actions.append(
					{
						"id": "capture_town",
						"label": "Claim Town",
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
			if _resource_node_claimable_by_player(node, site):
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

static func get_artifact_actions(session: SessionStateStore.SessionData) -> Array:
	normalize_overworld_state(session)
	return ArtifactRules.get_management_actions(session.overworld.get("hero", {}))

static func get_spell_actions(session: SessionStateStore.SessionData) -> Array:
	normalize_overworld_state(session)
	return SpellRules.get_overworld_actions(
		session.overworld.get("hero", {}),
		session.overworld.get("movement", {})
	)

static func get_hero_actions(session: SessionStateStore.SessionData) -> Array:
	normalize_overworld_state(session)
	return HeroCommandRules.get_overworld_switch_actions(session)

static func switch_active_hero(session: SessionStateStore.SessionData, hero_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var result := HeroCommandRules.set_active_hero(session, hero_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to change command."))}
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func get_specialty_actions(session: SessionStateStore.SessionData) -> Array:
	normalize_overworld_state(session)
	return HeroProgressionRules.get_choice_actions(session.overworld.get("hero", {}))

static func choose_specialty(session: SessionStateStore.SessionData, specialty_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var hero = session.overworld.get("hero", {})
	var previous_movement_max := _movement_max_from_hero(hero, session)
	var previous_mana_max := int(hero.get("spellbook", {}).get("mana", {}).get("max", SpellRules.mana_max_from_hero(hero)))
	var result := HeroProgressionRules.choose_specialty(hero, specialty_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to choose specialty."))}

	session.overworld["hero"] = ArtifactRules.ensure_hero_artifacts(
		SpellRules.ensure_hero_spellbook(result.get("hero", hero))
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
			}
		)
	return normalized

static func _normalize_artifact_nodes(nodes: Array) -> Array:
	return ArtifactRules.normalize_artifact_nodes(nodes)

static func _find_resource_node_at(session: SessionStateStore.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and _position_matches(node, pos):
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_context_resource_node(session: SessionStateStore.SessionData) -> Dictionary:
	var node_result := _find_resource_node_at(session)
	if int(node_result.get("index", -1)) < 0:
		return {"index": -1, "node": {}}
	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if _resource_site_is_persistent(site) or not bool(node.get("collected", false)):
		return node_result
	return {"index": -1, "node": {}}

static func _find_resource_node_by_placement(session: SessionStateStore.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "node": {}}
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_active_town(session: SessionStateStore.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and _position_matches(town, pos):
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_active_resource_node(session: SessionStateStore.SessionData) -> Dictionary:
	var node_result := _find_resource_node_at(session)
	if int(node_result.get("index", -1)) < 0:
		return {"index": -1, "node": {}}
	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if _resource_node_claimable_by_player(node, site):
		return node_result
	return {"index": -1, "node": {}}

static func _find_active_artifact_node(session: SessionStateStore.SessionData) -> Dictionary:
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

static func _resource_node_claimable_by_player(node: Dictionary, site: Dictionary) -> bool:
	if _resource_site_is_persistent(site):
		return String(node.get("collected_by_faction_id", "")) != "player"
	return not bool(node.get("collected", false))

static func _resource_site_claim_rewards(site: Dictionary) -> Dictionary:
	var rewards = site.get("claim_rewards", site.get("rewards", {}))
	return rewards if rewards is Dictionary else {}

static func _resource_site_family_label(site: Dictionary) -> String:
	match String(site.get("family", "")):
		"neutral_dwelling":
			return "Neutral Dwelling"
		"faction_outpost":
			return "Faction Outpost"
		"frontier_shrine":
			return "Frontier Shrine"
		_:
			return "Resource Site"

static func _resource_site_claim_message(site: Dictionary, previous_controller: String) -> String:
	if not _resource_site_is_persistent(site):
		return "Claimed %s." % String(site.get("name", "the site"))
	if previous_controller == "":
		return "Secured %s." % String(site.get("name", "the site"))
	if previous_controller == "player":
		return "%s already answers your banners." % String(site.get("name", "The site"))
	return "Retook %s from hostile control." % String(site.get("name", "the site"))

static func _resource_site_action_label(node: Dictionary, site: Dictionary) -> String:
	if _resource_site_is_persistent(site) and String(node.get("collected_by_faction_id", "")) not in ["", "player"]:
		return "Reclaim Site"
	match String(site.get("family", "")):
		"neutral_dwelling":
			return "Secure Dwelling"
		"faction_outpost":
			return "Secure Outpost"
		"frontier_shrine":
			return "Bind Shrine"
		_:
			return "Claim Site"

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
			"neutral_dwelling":
				profile["action_label"] = "Dispatch Relief"
			"faction_outpost":
				profile["action_label"] = "Repair Outpost"
			"frontier_shrine":
				profile["action_label"] = "Relight Shrine"
			_:
				profile["action_label"] = "Secure Route"
	if int(profile.get("pressure_guard_bonus", 0)) <= 0:
		match String(site.get("family", "")):
			"neutral_dwelling":
				profile["pressure_guard_bonus"] = 1
			"faction_outpost":
				profile["pressure_guard_bonus"] = 2
			"frontier_shrine":
				profile["pressure_guard_bonus"] = 1
	if int(profile.get("growth_bonus_percent", 0)) <= 0:
		match String(site.get("family", "")):
			"neutral_dwelling":
				profile["growth_bonus_percent"] = 14
			"faction_outpost":
				profile["growth_bonus_percent"] = 4
			"frontier_shrine":
				profile["growth_bonus_percent"] = 6
	if int(profile.get("break_pressure", 0)) <= 0:
		match String(site.get("family", "")):
			"neutral_dwelling":
				profile["break_pressure"] = 1
			"faction_outpost":
				profile["break_pressure"] = 2
			"frontier_shrine":
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
	session: SessionStateStore.SessionData,
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
			commander_name = String(HeroCommandRules.hero_by_id(session, commander_id).get("name", ""))
		if security_rating <= 0:
			var preview_hero := HeroCommandRules.active_hero(session)
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

static func _resource_site_response_action(
	session: SessionStateStore.SessionData,
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

static func _resource_site_context_summary(session: SessionStateStore.SessionData, node: Dictionary, site: Dictionary) -> String:
	var parts := []
	if _resource_site_is_persistent(site):
		var controller := String(node.get("collected_by_faction_id", ""))
		match controller:
			"":
				parts.append("Control unclaimed")
			"player":
				parts.append("Control secured")
			_:
				parts.append("Control denied by %s" % String(ContentService.get_faction(controller).get("name", controller)))
	var income_summary := _describe_resource_delta(site.get("control_income", {}))
	if income_summary != "":
		parts.append("Daily %s" % income_summary)
	var weekly_summary := _describe_recruit_delta(site.get("weekly_recruits", {}))
	if weekly_summary != "":
		parts.append("Weekly %s" % weekly_summary)
	var claim_summary := _describe_recruit_delta(site.get("claim_recruits", {}))
	if claim_summary != "":
		parts.append("Field recruits %s" % claim_summary)
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
	var response_state := _resource_site_response_state(session, node, site)
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
	elif String(node.get("collected_by_faction_id", "")) == "player" and int(response_state.get("watch_days", 0)) > 0:
		var ready_commander := String(response_state.get("commander_name", ""))
		if ready_commander != "":
			parts.append("Commit %s to escort %s and steady nearby threat lanes." % [
				ready_commander,
				String(response_state.get("action_label", "route security")).to_lower(),
			])
		else:
			parts.append("Order %s to steady nearby threat lanes." % String(response_state.get("action_label", "route security")))
	if parts.is_empty():
		return "Claim the site to add its stores immediately."
	return " | ".join(parts)

static func _grant_site_claim_recruits(session: SessionStateStore.SessionData, recruits: Variant) -> String:
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
	return "Auxiliaries join the field army (%s)." % _describe_recruit_delta(recruits)

static func _learn_site_spell(session: SessionStateStore.SessionData, spell_id: String) -> String:
	if spell_id == "":
		return ""
	var result := SpellRules.learn_spell(session.overworld.get("hero", {}), spell_id)
	if not bool(result.get("ok", false)):
		return ""
	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	return String(result.get("message", ""))

static func _issue_active_site_response(session: SessionStateStore.SessionData) -> Dictionary:
	var node_result := _find_context_resource_node(session)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": "No logistics site is ready for response orders here."}
	return _issue_resource_site_response(session, String(node_result.get("node", {}).get("placement_id", "")), "field")

static func _issue_resource_site_response(
	session: SessionStateStore.SessionData,
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
	var movement_result := HeroCommandRules.spend_active_hero_movement(
		session,
		int(response_state.get("movement_cost", 0)),
		String(response_state.get("action_label", "response order")).to_lower()
	)
	if not bool(movement_result.get("ok", false)):
		return movement_result
	if cost is Dictionary and not cost.is_empty():
		_spend_resources(session, cost)

	var active_hero := HeroCommandRules.active_hero(session)
	var commander_id := String(active_hero.get("id", ""))
	var commander_name := String(active_hero.get("name", "The commander"))
	var security_rating := _route_security_rating_for_hero(active_hero)
	var linked_town_result := _resource_node_linked_town(session, node, "player")
	node["response_origin"] = origin
	node["response_source_town_id"] = String(linked_town_result.get("town", {}).get("placement_id", ""))
	node["response_last_day"] = session.day
	node["response_until_day"] = session.day + max(1, int(response_state.get("watch_days", 0))) - 1
	node["response_commander_id"] = commander_id
	node["response_security_rating"] = security_rating
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
	return _finalize_action_result(session, true, " ".join(messages))

static func _resource_node_linked_town(
	session: SessionStateStore.SessionData,
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
	var cleared := node.duplicate(true)
	cleared["response_origin"] = ""
	cleared["response_source_town_id"] = ""
	cleared["response_last_day"] = 0
	cleared["response_until_day"] = 0
	cleared["response_commander_id"] = ""
	cleared["response_security_rating"] = 0
	return cleared

static func _nearest_town_for_controller(
	session: SessionStateStore.SessionData,
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

static func _get_town_at(session: SessionStateStore.SessionData, x: int, y: int) -> Dictionary:
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

static func _movement_max_from_hero(hero: Dictionary, session: SessionStateStore.SessionData = null) -> int:
	return HeroCommandRules.movement_max_for_hero(hero, session)

static func _calculate_town_income(town: Dictionary) -> Dictionary:
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
	return income

static func _growth_tick_town(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
	var hero = session.overworld.get("hero", {})
	var weekly_growth := HeroProgressionRules.scale_recruit_growth(hero, _town_weekly_growth(town, session))
	town["available_recruits"] = _add_recruit_growth(
		town.get("available_recruits", {}),
		weekly_growth
	)
	return weekly_growth

static func _seed_recruits_for_town(town: Dictionary) -> Dictionary:
	var normalized_town := town.duplicate(true)
	normalized_town["built_buildings"] = _normalize_built_buildings_for_town_state(normalized_town)
	return _seed_scenario_recruits_for_town_state(normalized_town)

static func _town_weekly_growth(town: Dictionary, session: SessionStateStore.SessionData = null) -> Dictionary:
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
	return _apply_recruit_percent(growth, growth_percent)

static func _town_reinforcement_quality(town: Dictionary, session: SessionStateStore.SessionData = null) -> int:
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
	return max(0, quality)

static func _town_battle_readiness(town: Dictionary, session: SessionStateStore.SessionData = null) -> int:
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
	return max(0, readiness)

static func _town_pressure_output(town: Dictionary, session: SessionStateStore.SessionData = null) -> int:
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
	return max(0, pressure)

static func _town_logistics_state(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
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
	var held_site_count := 0
	var disrupted_count := 0
	var threatened_count := 0
	var response_count := 0
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
		"held_site_labels": held_site_labels,
		"disrupted_site_labels": disrupted_site_labels,
		"threatened_site_labels": threatened_site_labels,
		"response_site_labels": response_site_labels,
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

static func _town_recovery_state(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
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

static func _town_capital_project_state(town: Dictionary, session: SessionStateStore.SessionData = null) -> Dictionary:
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
		"held_site_labels": [],
		"disrupted_site_labels": [],
		"threatened_site_labels": [],
		"response_site_labels": [],
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

static func _town_recovery_relief_rating(session: SessionStateStore.SessionData, town: Dictionary) -> int:
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
		"neutral_dwelling":
			support["quality_bonus"] = max(2, int(round(float(_weighted_recruit_value(site.get("weekly_recruits", {}))) / 28.0)))
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
	return support

static func _resource_site_under_threat(session: SessionStateStore.SessionData, node: Dictionary, controller_id: String) -> bool:
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

static func _town_response_panel_lines(session: SessionStateStore.SessionData, town: Dictionary) -> Array:
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

static func _town_response_actions(session: SessionStateStore.SessionData, town: Dictionary) -> Array:
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
		var site_summary_parts := [
			String(response_state.get("summary", "")),
			"Site %s" % String(site.get("name", "Frontier site")),
		]
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
				"resource_blocked": not bool(readiness.get("direct_affordable", false)),
				"movement_blocked": movement_left < int(response_state.get("movement_cost", 0)),
			}
		)
	return actions

static func _execute_town_response_action(
	session: SessionStateStore.SessionData,
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

static func _stabilize_town_recovery(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
	var recovery := _town_recovery_state(session, town)
	if not bool(recovery.get("active", false)):
		return {"ok": false, "message": "%s has no active recovery pressure." % _town_name(town)}
	var profile := _town_recovery_stabilize_profile(town)
	var cost = profile.get("resource_cost", {})
	if not _can_afford(session, cost):
		return {"ok": false, "message": "Insufficient resources to stabilize %s." % _town_name(town)}
	var movement_result := HeroCommandRules.spend_active_hero_movement(
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

static func _town_market_panel_lines(session: SessionStateStore.SessionData, town: Dictionary) -> Array:
	var state := _town_market_state(town)
	var lines := ["Exchange Hall"]
	if not bool(state.get("active", false)):
		lines.append("- No market square stands here. Build a market to liquidate spare stock or buy scarce timber and ore.")
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

static func _town_market_actions(session: SessionStateStore.SessionData, town: Dictionary) -> Array:
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

static func _market_action_entry(session: SessionStateStore.SessionData, state: Dictionary, quote: Dictionary) -> Dictionary:
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
	session: SessionStateStore.SessionData,
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
		specialty_summary = "River barges tighten timber rates and open double-wood convoy trades for construction or levy recovery."
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

static func _award_experience(session: SessionStateStore.SessionData, amount: int) -> Array:
	if amount <= 0:
		return []

	var previous_movement_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var previous_mana_max := int(session.overworld.get("hero", {}).get("spellbook", {}).get("mana", {}).get("max", SpellRules.mana_max_from_hero(session.overworld.get("hero", {}))))
	var result := HeroProgressionRules.add_experience(session.overworld.get("hero", {}), amount)
	session.overworld["hero"] = ArtifactRules.ensure_hero_artifacts(
		SpellRules.ensure_hero_spellbook(result.get("hero", session.overworld.get("hero", {})))
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

static func _can_afford(session: SessionStateStore.SessionData, cost: Variant) -> bool:
	var resources = session.overworld.get("resources", {})
	if not (cost is Dictionary):
		return true
	for key in cost.keys():
		if int(resources.get(String(key), 0)) < int(cost[key]):
			return false
	return true

static func _max_affordable_count(session: SessionStateStore.SessionData, unit_cost: Variant) -> int:
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

static func _spend_resources(session: SessionStateStore.SessionData, cost: Variant) -> void:
	var resources = session.overworld.get("resources", {}).duplicate(true)
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key := String(key)
			resources[resource_key] = max(0, int(resources.get(resource_key, 0)) - int(cost[key]))
	session.overworld["resources"] = resources

static func _add_resources(session: SessionStateStore.SessionData, delta: Variant) -> void:
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

static func _describe_resource_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	for key in ["gold", "wood", "ore"]:
		var amount := int(delta.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
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

static func _find_town_by_placement(session: SessionStateStore.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "town": {}}
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _advance_all_town_recovery(session: SessionStateStore.SessionData) -> Array:
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

static func _advance_town_recovery(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
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

static func _sync_movement_to_hero(session: SessionStateStore.SessionData, previous_max: int) -> void:
	var movement_state = session.overworld.get("movement", {})
	if not (movement_state is Dictionary):
		movement_state = {}
	var new_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var current := int(movement_state.get("current", new_max))
	current = clamp(current + (new_max - previous_max), 0, new_max)
	movement_state["current"] = current
	movement_state["max"] = new_max
	session.overworld["movement"] = movement_state

static func _sync_spellbook_to_hero(session: SessionStateStore.SessionData, previous_max: int) -> void:
	var hero = session.overworld.get("hero", {})
	var spellbook = hero.get("spellbook", {})
	if not (spellbook is Dictionary):
		return
	var mana = spellbook.get("mana", {})
	if not (mana is Dictionary):
		return
	var new_max := int(mana.get("max", SpellRules.mana_max_from_hero(hero)))
	var current := int(mana.get("current", new_max))
	current = clamp(current + (new_max - previous_max), 0, new_max)
	mana["current"] = current
	mana["max"] = new_max
	spellbook["mana"] = mana
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero

static func _apply_artifact_claim(
	session: SessionStateStore.SessionData,
	artifact_id: String,
	source_verb: String,
	auto_equip: bool
) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRules.claim_artifact(
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

static func _claim_town(session: SessionStateStore.SessionData, town_result: Dictionary) -> String:
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var town_index := int(town_result.get("index", -1))
	if town_index < 0 or town.is_empty():
		return ""

	town["owner"] = "player"
	town["recovery"] = _normalize_town_recovery_state(town.get("recovery", {}))
	if int(town.get("available_recruits", {}).size()) == 0:
		town["available_recruits"] = _seed_recruits_for_town(town)
	towns[town_index] = town
	session.overworld["towns"] = towns
	return "Captured %s." % _town_name(town)

static func _normalize_fog_of_war(session: SessionStateStore.SessionData) -> void:
	var map_size := derive_map_size(session)
	var had_fog_key := session.overworld.has(FOG_KEY)
	var fog = session.overworld.get(FOG_KEY, {})
	if not (fog is Dictionary):
		fog = {}
	var explored_tiles := []
	if fog.has(EXPLORED_TILES_KEY):
		explored_tiles = _normalize_visibility_grid(fog.get(EXPLORED_TILES_KEY, []), map_size)
	else:
		explored_tiles = _blank_visibility_grid(map_size, not had_fog_key)
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

static func _fog_state_ready(session: SessionStateStore.SessionData) -> bool:
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
	var radius := HeroCommandRules.scouting_radius_for_hero(hero)
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

static func _finalize_action_result(
	session: SessionStateStore.SessionData,
	ok: bool,
	base_message: String
) -> Dictionary:
	HeroCommandRules.commit_active_hero(session)
	refresh_fog_of_war(session)
	var messages := []
	if base_message != "":
		messages.append(base_message)

	var scenario_result: Dictionary = _evaluate_scenario_state(session)
	var scenario_message := String(scenario_result.get("message", ""))
	HeroCommandRules.commit_active_hero(session)
	refresh_fog_of_war(session)
	if scenario_message != "":
		messages.append(scenario_message)

	return {
		"ok": ok,
		"message": " ".join(messages),
		"scenario_status": session.scenario_status,
	}

static func _normalize_command_briefing(session: SessionStateStore.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	var had_state := briefing_state is Dictionary
	if not had_state:
		briefing_state = {}
	var signature := "%s|%s" % [session.scenario_id, SessionStateStore.normalize_launch_mode(session.launch_mode)]
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

static func _normalize_command_risk_forecast(session: SessionStateStore.SessionData) -> void:
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

static func _should_surface_command_briefing(session: SessionStateStore.SessionData) -> bool:
	if session == null or session.scenario_id == "":
		return false
	if session.scenario_status != "in_progress" or String(session.game_state) != "overworld":
		return false
	if session.day != 1 or String(session.flags.get("last_action", "")) != "":
		return false
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	return briefing_state is Dictionary and not bool(briefing_state.get("shown", false))

static func _should_surface_command_risk_forecast(session: SessionStateStore.SessionData) -> bool:
	if session == null or session.scenario_id == "":
		return false
	if session.scenario_status != "in_progress" or String(session.game_state) != "overworld":
		return false
	var forecast := _command_risk_forecast(session)
	if not bool(forecast.get("gate_end_turn", false)):
		return false
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	return forecast_state is Dictionary and not bool(forecast_state.get("shown", false))

static func _command_briefing_lines(session: SessionStateStore.SessionData) -> Array:
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

static func _command_briefing_posture_line(session: SessionStateStore.SessionData) -> String:
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
		HeroCommandRules.scouting_radius_for_hero(hero),
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		int(army_totals.get("headcount", 0)),
		int(army_totals.get("groups", 0)),
	]

static func _command_briefing_logistics_line(session: SessionStateStore.SessionData) -> String:
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

static func _command_briefing_pressure_line(session: SessionStateStore.SessionData, scenario: Dictionary) -> String:
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

static func _command_briefing_orders_line(session: SessionStateStore.SessionData, scenario: Dictionary) -> String:
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

static func _context_action_briefing(session: SessionStateStore.SessionData, action: Variant, context: Dictionary) -> String:
	if not (action is Dictionary):
		return "Review the current tile and commit the next order."
	var action_id := String(action.get("id", ""))
	match action_id:
		"visit_town":
			var town = context.get("town", {})
			return "Enter %s now to review construction, recruitment, market, and recovery orders." % _town_name(town)
		"capture_town":
			var town = context.get("town", {})
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
			return "Recover the relic on this tile now before hostile pressure reaches the lane."
		"enter_battle":
			var encounter = context.get("encounter", {})
			var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
			return "Break %s now before the host can widen pressure across the frontier." % String(encounter_def.get("name", "the blocking host"))
	return String(action.get("summary", "Review the current tile and commit the next order."))

static func _context_action_summary(session: SessionStateStore.SessionData, action_id: String, context: Dictionary) -> String:
	match action_id:
		"visit_town", "capture_town":
			return _context_action_briefing(session, {"id": action_id}, context)
		"collect_resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return _resource_site_context_summary(session, node, site)
		"collect_artifact":
			var artifact_node = context.get("node", {})
			return "Recover %s for the active hero before hostile pressure reaches this lane." % ArtifactRules.describe_artifact(
				String(artifact_node.get("artifact_id", ""))
			)
		"enter_battle":
			var encounter = context.get("encounter", {})
			var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
			return "Break %s on %s before the host can widen pressure across the frontier." % [
				String(encounter_def.get("name", "the blocking host")),
				_terrain_name_at(session, int(encounter.get("x", 0)), int(encounter.get("y", 0))),
			]
	return _context_action_briefing(session, {"id": action_id}, context)

static func _command_commitment_action_line(session: SessionStateStore.SessionData) -> String:
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

static func _command_commitment_route_line(session: SessionStateStore.SessionData) -> String:
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
			var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
			return "%s blocks the active march line. Leaving it intact keeps hostile pressure on this route." % String(
				encounter_def.get("name", "Hostile contact")
			)
		"artifact":
			var artifact_node = context.get("node", {})
			return "%s lies exposed on the active lane. Recovering it strengthens the current commander before the front tightens." % ArtifactRules.describe_artifact(
				String(artifact_node.get("artifact_id", ""))
			)
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

static func _command_commitment_coverage_line(session: SessionStateStore.SessionData) -> String:
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

static func _command_commitment_hold_line(session: SessionStateStore.SessionData) -> String:
	var forecast := _command_risk_forecast(session)
	if bool(forecast.get("has_risk", false)):
		var lines = forecast.get("lines", [])
		if lines is Array and lines.size() > 1:
			return String(lines[1]).trim_prefix("- ")
		return String(forecast.get("summary", "the frontier stays strained"))
	if not get_context_actions(session).is_empty():
		return "No concrete next-day break is signaled, but the current order window stays open only while this lane remains clear."
	return "No concrete next-day break is signaled from the current frontier watch."

static func _nearest_reserve_hero_support(session: SessionStateStore.SessionData) -> Dictionary:
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

static func _nearest_logistics_plan(session: SessionStateStore.SessionData) -> Dictionary:
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

static func _nearest_visible_encounter_plan(session: SessionStateStore.SessionData) -> Dictionary:
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
		var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		var candidate := {
			"distance": distance,
			"order": "Advance %d tile%s %s and prepare to engage %s on %s." % [
				distance,
				"" if distance == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				String(encounter_def.get("name", "the nearest host")),
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

static func _command_risk_forecast(session: SessionStateStore.SessionData) -> Dictionary:
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

static func _command_risk_items(session: SessionStateStore.SessionData) -> Array:
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

static func _command_risk_town_items(session: SessionStateStore.SessionData) -> Array:
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

static func _command_risk_logistics_items(session: SessionStateStore.SessionData, pressured_town_ids: Dictionary) -> Array:
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

static func _command_risk_objective_items(session: SessionStateStore.SessionData, pressured_town_ids: Dictionary) -> Array:
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

static func _command_risk_posture_items(session: SessionStateStore.SessionData) -> Array:
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

static func _command_risk_field_item(session: SessionStateStore.SessionData) -> Dictionary:
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
	if String(get_active_context(session).get("type", "empty")) == "town":
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
	session: SessionStateStore.SessionData,
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

static func _command_risk_encounter_objective_item(session: SessionStateStore.SessionData, objective: Dictionary) -> Dictionary:
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

static func _town_command_risk_state(session: SessionStateStore.SessionData, town: Dictionary) -> Dictionary:
	var state := {
		"visible_marching": 0,
		"visible_pressuring": 0,
		"hidden_targeting": false,
		"nearest_goal_distance": 9999,
		"siege_progress": 0,
		"siege_capture_progress": 1,
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
		if is_public:
			if is_pressuring:
				state["visible_pressuring"] = int(state.get("visible_pressuring", 0)) + 1
			else:
				state["visible_marching"] = int(state.get("visible_marching", 0)) + 1
				state["nearest_goal_distance"] = min(int(state.get("nearest_goal_distance", 9999)), goal_distance)
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

static func _public_enemy_pressure_gain(session: SessionStateStore.SessionData, config: Dictionary) -> int:
	return max(
		1,
		DifficultyRules.adjust_enemy_pressure_gain(
			session,
			max(0, int(config.get("pressure_per_day", 0)) + int(config.get("pressure_per_enemy_town", 0)))
		)
	)

static func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

static func _enemy_state_for_faction(session: SessionStateStore.SessionData, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

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

static func _refresh_all_player_heroes_for_new_day(session: SessionStateStore.SessionData) -> void:
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary):
			continue
		hero = SpellRules.refresh_daily_mana(hero)
		var movement_max := _movement_max_from_hero(hero, session)
		hero["movement"] = {"current": movement_max, "max": movement_max}
		heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	HeroCommandRules.normalize_session(session)
