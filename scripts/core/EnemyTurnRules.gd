class_name EnemyTurnRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
static var BattleRulesScript: Variant = load("res://scripts/core/BattleRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")

const TRACKED_RESOURCES := ["gold", "wood", "ore"]

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func build_enemy_states(configs: Variant) -> Array:
	var states = []
	if not (configs is Array):
		return states

	for config in configs:
		if not (config is Dictionary):
			continue
		states.append(
			{
				"faction_id": String(config.get("faction_id", "")),
				"pressure": 0,
				"raid_counter": 0,
				"commander_counter": 0,
				"siege_progress": 0,
				"treasury": _blank_resource_pool(),
				"posture": "probing",
				"captured_artifact_ids": [],
				"commander_roster": [],
			}
		)
	return states

static func normalize_enemy_states(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	DifficultyRulesScript.normalize_session(session)

	var scenario = ContentService.get_scenario(session.scenario_id)
	var configs = scenario.get("enemy_factions", [])
	var existing_states = session.overworld.get("enemy_states", [])
	var normalized_states = []

	if configs is Array:
		for config in configs:
			if not (config is Dictionary):
				continue
			var faction_id = String(config.get("faction_id", ""))
			var existing_state = _find_state(existing_states, faction_id)
			normalized_states.append(
				{
					"faction_id": faction_id,
					"pressure": max(0, int(existing_state.get("pressure", 0))),
					"raid_counter": max(0, int(existing_state.get("raid_counter", 0))),
					"commander_counter": max(0, int(existing_state.get("commander_counter", 0))),
					"siege_progress": max(0, int(existing_state.get("siege_progress", 0))),
					"treasury": _normalize_resource_pool(existing_state.get("treasury", {})),
					"posture": _normalize_posture(existing_state.get("posture", "probing")),
					"captured_artifact_ids": _normalize_string_array(existing_state.get("captured_artifact_ids", [])),
					"commander_roster": EnemyAdventureRulesScript.normalize_commander_roster(
						session,
						faction_id,
						existing_state.get("commander_roster", [])
					),
				}
			)

	session.overworld["enemy_states"] = normalized_states
	EnemyAdventureRulesScript.normalize_raid_armies(session)
	EnemyAdventureRulesScript.normalize_all_commander_rosters(session)

static func run_enemy_turn(session: SessionStateStoreScript.SessionData) -> Dictionary:
	DifficultyRulesScript.normalize_session(session)
	normalize_enemy_states(session)
	var scenario = ContentService.get_scenario(session.scenario_id)
	var configs = scenario.get("enemy_factions", [])
	if not (configs is Array) or configs.is_empty():
		return {"ok": true, "message": ""}

	var states = session.overworld.get("enemy_states", [])
	var messages = []
	var should_apply_weekly_growth: bool = OverworldRulesScript.is_weekly_growth_day(session.day)

	for config in configs:
		if not (config is Dictionary):
			continue
		var faction_id = String(config.get("faction_id", ""))
		var state_index = _find_state_index(states, faction_id)
		if state_index < 0:
			continue
		var state = states[state_index]
		var turn_result = _run_empire_cycle(session, config, state, should_apply_weekly_growth)
		state = turn_result.get("state", state)
		var turn_messages = turn_result.get("messages", [])
		if turn_messages is Array:
			for message in turn_messages:
				if String(message) != "":
					messages.append(String(message))
		states[state_index] = state

	session.overworld["enemy_states"] = states
	EnemyAdventureRulesScript.normalize_all_commander_rosters(session)
	return {"ok": true, "message": " ".join(messages)}

static func describe_threats(session: SessionStateStoreScript.SessionData) -> String:
	normalize_enemy_states(session)
	var scenario = ContentService.get_scenario(session.scenario_id)
	var configs = scenario.get("enemy_factions", [])
	if not (configs is Array) or configs.is_empty():
		return "No hostile factions are active."

	var lines = []
	for config in configs:
		if not (config is Dictionary):
			continue
		var faction_id = String(config.get("faction_id", ""))
		var state = _find_state(session.overworld.get("enemy_states", []), faction_id)
		var threshold = _raid_threshold_for_strategy(session, config, faction_id)
		var line_parts = [
			String(config.get("label", faction_id)),
			_public_posture_label(state, threshold, faction_id),
		]
		var strategy_summary = EnemyAdventureRulesScript.public_strategy_summary(config, faction_id)
		if strategy_summary != "":
			line_parts.append(strategy_summary)
		var capital_watch = _capital_watch_summary(_faction_capital_state(session, faction_id))
		if capital_watch != "":
			line_parts.append(capital_watch)

		var visible_raids = EnemyAdventureRulesScript.visible_raid_count(session, faction_id)
		if visible_raids > 0:
			line_parts.append("Known raids %d" % visible_raids)
		elif active_raid_count(session, faction_id) > 0:
			line_parts.append("Raid hosts are moving beyond the fog")

		var siege_target_id = String(config.get("siege_target_placement_id", ""))
		if siege_target_id != "":
			var siege_progress = int(state.get("siege_progress", 0))
			if siege_progress > 0:
				line_parts.append(
					"Siege %d/%d" % [siege_progress, max(1, int(config.get("siege_capture_progress", 1)))]
				)

		var focus = EnemyAdventureRulesScript.describe_focus(session, faction_id, true)
		if focus != "":
			line_parts.append(focus)
		var commander_recovery = EnemyAdventureRulesScript.public_commander_recovery_summary(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		if commander_recovery != "":
			line_parts.append(commander_recovery)
		var visible_commanders = EnemyAdventureRulesScript.raid_commander_summaries(
			_visible_raids_for_faction(session, faction_id),
			2
		)
		if not visible_commanders.is_empty():
			var commander_summary: String = "Commanders sighted %s" % ", ".join(visible_commanders)
			var hidden_count: int = max(0, EnemyAdventureRulesScript.visible_raid_count(session, faction_id) - visible_commanders.size())
			if hidden_count > 0:
				commander_summary += " (+%d more)" % hidden_count
			line_parts.append(commander_summary)
		var contestation = EnemyAdventureRulesScript.describe_contestation(session, faction_id, true)
		if contestation != "":
			line_parts.append(contestation)
		var relic_summary = _captured_artifact_summary(state)
		if relic_summary != "":
			line_parts.append(relic_summary)
		lines.append(" | ".join(line_parts))

	return "\n".join(lines)

static func get_pressure(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	normalize_enemy_states(session)
	return int(_find_state(session.overworld.get("enemy_states", []), faction_id).get("pressure", 0))

static func active_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var count = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		count += 1
	return count

static func _visible_raids_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var visible := []
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if not EnemyAdventureRulesScript._raid_is_public(session, encounter):
			continue
		visible.append(encounter)
	return visible

static func _run_empire_cycle(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	should_apply_weekly_growth: bool
) -> Dictionary:
	var faction_id = String(config.get("faction_id", ""))
	var towns = session.overworld.get("towns", [])
	var town_entries = _owned_town_entries(session, faction_id)
	var messages = []
	state["captured_artifact_ids"] = _normalize_string_array(state.get("captured_artifact_ids", []))
	if town_entries.is_empty():
		if int(state.get("pressure", 0)) > 0 and active_raid_count(session, faction_id) == 0:
			state["pressure"] = max(0, int(state.get("pressure", 0)) - 1)
		state["posture"] = "collapsed"
		return {"state": state, "messages": messages}

	var treasury = _normalize_resource_pool(state.get("treasury", {}))
	var income_summary = _apply_empire_income(session, town_entries, treasury, state)
	if not income_summary.is_empty():
		state["treasury"] = treasury

	if should_apply_weekly_growth:
		var muster_message = _apply_weekly_musters(session, town_entries, towns, faction_id, config)
		if muster_message != "":
			messages.append(muster_message)
		session.overworld["towns"] = towns

	var build_messages = _build_in_enemy_towns(session, town_entries, towns, treasury, faction_id, config)
	if not build_messages.is_empty():
		messages.append_array(build_messages)
	session.overworld["towns"] = towns

	var reinforcement_message = _reinforce_enemy_forces(session, config, towns, treasury, faction_id)
	if reinforcement_message != "":
		messages.append(reinforcement_message)
	session.overworld["towns"] = towns

	var owned_towns = town_entries.size()
	var capital_state = _faction_capital_state_from_towns(session, towns, faction_id)
	var base_pressure_gain = max(
		0,
		int(config.get("pressure_per_day", 0))
		+ (owned_towns * int(config.get("pressure_per_enemy_town", 0)))
		+ _captured_artifact_pressure_bonus(state)
		+ _empire_town_pressure_bonus(session, faction_id, towns)
		+ _empire_strength_pressure_bonus(session, faction_id, towns)
		+ _empire_capital_pressure_bonus(capital_state, session.day)
		+ OverworldRulesScript.controlled_resource_site_pressure_bonus(session, faction_id)
		- OverworldRulesScript.player_resource_site_pressure_guard(session)
	)
	var pressure_gain = DifficultyRulesScript.adjust_enemy_pressure_gain(session, base_pressure_gain)
	state["pressure"] = max(0, int(state.get("pressure", 0)) + pressure_gain)

	var raid_result = EnemyAdventureRulesScript.advance_raids(session, config, faction_id, state)
	state = raid_result.get("state", state)
	treasury = _normalize_resource_pool(state.get("treasury", treasury))
	var raid_message = String(raid_result.get("message", ""))
	if raid_message != "":
		messages.append(raid_message)

	var defense_result = _queue_town_defense_battle(session, config, faction_id)
	if bool(defense_result.get("battle_started", false)):
		var defense_message = String(defense_result.get("message", ""))
		if defense_message != "":
			messages.append(defense_message)
		state["treasury"] = treasury
		state["posture"] = "raiding"
		return {"state": state, "messages": messages}

	var intercept_result = _queue_hero_intercept_battle(session, config, faction_id)
	if bool(intercept_result.get("battle_started", false)):
		var intercept_message = String(intercept_result.get("message", ""))
		if intercept_message != "":
			messages.append(intercept_message)
		state["treasury"] = treasury
		state["posture"] = "raiding"
		return {"state": state, "messages": messages}

	while _can_launch_raid(session, config, state, faction_id):
		var spawn_result = _spawn_raid(session, config, state)
		if spawn_result.is_empty():
			break
		messages.append(String(spawn_result.get("message", "")))

	var siege_message = _advance_siege(session, config, state, faction_id)
	if siege_message != "":
		messages.append(siege_message)

	state["treasury"] = treasury
	state["posture"] = _determine_posture(session, config, state, faction_id, towns)
	return {"state": state, "messages": messages}

static func _apply_empire_income(
	session: SessionStateStoreScript.SessionData,
	town_entries: Array,
	treasury: Dictionary,
	state: Dictionary = {}
) -> Dictionary:
	var total_income = _blank_resource_pool()
	var faction_id = String(state.get("faction_id", ""))
	for entry in town_entries:
		var town = entry.get("town", {})
		total_income = _merge_resource_pools(total_income, OverworldRulesScript.town_income(town))
	total_income = _merge_resource_pools(total_income, _captured_artifact_income(state))
	if faction_id != "":
		total_income = _merge_resource_pools(total_income, OverworldRulesScript.controlled_resource_site_income(session, faction_id))
	treasury.merge(_merge_resource_pools(treasury, total_income), true)
	return total_income

static func _apply_weekly_musters(
	session: SessionStateStoreScript.SessionData,
	town_entries: Array,
	towns: Array,
	faction_id: String,
	config: Dictionary
) -> String:
	var musters = []
	for entry in town_entries:
		var town = entry.get("town", {})
		var growth: Dictionary = OverworldRulesScript.town_weekly_growth(town, session)
		town["available_recruits"] = _merge_recruits(town.get("available_recruits", {}), growth)
		towns[int(entry.get("index", -1))] = town
		if not growth.is_empty():
			musters.append("%s (%s)" % [_town_name(town), _describe_recruit_delta(growth)])
	if session != null:
		musters.append_array(OverworldRulesScript.apply_controlled_resource_site_musters(session, faction_id))
	if musters.is_empty():
		return ""
	return "%s musters fresh levies at %s." % [
		String(config.get("label", faction_id)),
		"; ".join(musters),
	]

static func _build_in_enemy_towns(
	session: SessionStateStoreScript.SessionData,
	town_entries: Array,
	towns: Array,
	treasury: Dictionary,
	faction_id: String,
	config: Dictionary
) -> Array:
	var messages = []
	for entry in town_entries:
		var town = towns[int(entry.get("index", -1))]
		var build_choice = _best_build_candidate(session, town, treasury, config, faction_id)
		if build_choice.is_empty():
			continue
		var building_id = String(build_choice.get("building_id", ""))
		var building = build_choice.get("building", {})
		var cost = build_choice.get("cost", {})
		OverworldRulesScript.apply_market_cost_coverage(town, treasury, cost)
		_spend_from_pool(treasury, cost)
		var built_buildings = town.get("built_buildings", [])
		if not (built_buildings is Array):
			built_buildings = []
		built_buildings.append(building_id)
		town["built_buildings"] = built_buildings
		town["available_recruits"] = _merge_recruits(
			town.get("available_recruits", {}),
			_building_growth_payload(building_id)
		)
		towns[int(entry.get("index", -1))] = town
		messages.append(
			"%s fortifies %s with %s." % [
				String(config.get("label", faction_id)),
				_town_name(town),
				String(building.get("name", building_id)),
			]
		)
	return messages

static func _reinforce_enemy_forces(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	towns: Array,
	treasury: Dictionary,
	faction_id: String
) -> String:
	var garrisoned_towns = []
	var raid_reinforcements = 0
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		var recruit_result = _recruit_town_forces(session, config, town, treasury, faction_id)
		town = recruit_result.get("town", town)
		towns[index] = town
		if bool(recruit_result.get("garrisoned", false)):
			garrisoned_towns.append(_town_name(town))
		raid_reinforcements += int(recruit_result.get("raid_batches", 0))
	if garrisoned_towns.is_empty() and raid_reinforcements <= 0:
		return ""

	var parts = []
	if not garrisoned_towns.is_empty():
		parts.append("bolsters %s" % ", ".join(garrisoned_towns))
	if raid_reinforcements > 0:
		parts.append("feeds %d raid host%s" % [raid_reinforcements, "" if raid_reinforcements == 1 else "s"])
	return "%s %s." % [String(config.get("label", faction_id)), " and ".join(parts)]

static func _recruit_town_forces(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	treasury: Dictionary,
	faction_id: String
) -> Dictionary:
	var garrisoned = false
	var raid_batches = 0
	var recruit_ids = []
	for unit_id_value in town.get("available_recruits", {}).keys():
		recruit_ids.append(String(unit_id_value))
	recruit_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_priority = _recruit_priority(a, config, faction_id)
		var b_priority = _recruit_priority(b, config, faction_id)
		if is_equal_approx(a_priority, b_priority):
			return a < b
		return a_priority > b_priority
	)

	for unit_id in recruit_ids:
		var available = int(town.get("available_recruits", {}).get(unit_id, 0))
		if available <= 0:
			continue
		var cost = _enemy_recruit_cost(town, unit_id)
		var recruit_count = min(available, _max_affordable_from_pool(treasury, cost))
		if recruit_count <= 0:
			continue
		var destination = _choose_recruit_destination(session, config, town, faction_id)
		if String(destination.get("type", "")) == "raid":
			var raid_count = _apply_reinforcement_to_raid(session, int(destination.get("index", -1)), unit_id, recruit_count)
			if raid_count > 0:
				raid_batches += 1
		else:
			town["garrison"] = _add_stack(town.get("garrison", []), unit_id, recruit_count)
			garrisoned = true
		town["available_recruits"] = _consume_recruits(town.get("available_recruits", {}), unit_id, recruit_count)
		_spend_from_pool(treasury, _scale_resource_pool(cost, recruit_count))
	return {"town": town, "garrisoned": garrisoned, "raid_batches": raid_batches}

static func _choose_recruit_destination(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	faction_id: String
) -> Dictionary:
	var defense_target = _desired_town_strength(session, town, config)
	var current_defense = _army_strength(town.get("garrison", []))
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	if current_defense < int(round(float(defense_target) * 0.72)):
		return {"type": "garrison"}

	var best_raid = _best_raid_reinforcement_target(session, config, faction_id)
	var garrison_gap = max(0, defense_target - current_defense)
	var garrison_score = float(garrison_gap) * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0)
	var raid_score = float(int(best_raid.get("need", 0))) * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0)
	if not best_raid.is_empty() and raid_score > garrison_score:
		return {"type": "raid", "index": int(best_raid.get("index", -1))}
	return {"type": "garrison"}

static func _best_raid_reinforcement_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	var best = {}
	var best_score = -1.0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for index in range(session.overworld.get("encounters", []).size()):
		var encounter = session.overworld.get("encounters", [])[index]
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		var desired = EnemyAdventureRulesScript.desired_raid_strength(encounter)
		var current = EnemyAdventureRulesScript.raid_strength(encounter)
		var need = desired - current
		if need <= 0:
			continue
		var site_family = EnemyAdventureRulesScript.target_site_family(
			session,
			String(encounter.get("target_kind", "")),
			String(encounter.get("target_placement_id", ""))
		)
		var objective_anchor = EnemyAdventureRulesScript.target_is_objective_anchor(
			session,
			String(encounter.get("target_kind", "")),
			String(encounter.get("target_placement_id", ""))
		)
		var score = float(need) * EnemyAdventureRulesScript.strategy_target_weight(
			config,
			faction_id,
			String(encounter.get("target_kind", "")),
			String(encounter.get("target_placement_id", "")),
			site_family,
			objective_anchor
		)
		score += float(EnemyAdventureRulesScript.priority_target_bonus(config, String(encounter.get("target_placement_id", ""))))
		if score > best_score:
			best_score = score
			best = {"index": index, "encounter": encounter, "need": need}
	return best

static func _apply_reinforcement_to_raid(session: SessionStateStoreScript.SessionData, encounter_index: int, unit_id: String, count: int) -> int:
	if encounter_index < 0 or count <= 0:
		return 0
	var encounters = session.overworld.get("encounters", [])
	if encounter_index >= encounters.size():
		return 0
	var encounter = encounters[encounter_index]
	if not (encounter is Dictionary):
		return 0
	encounter = EnemyAdventureRulesScript.ensure_raid_army(encounter)
	var army = encounter.get("enemy_army", {})
	army["stacks"] = _add_stack(army.get("stacks", []), unit_id, count)
	encounter["enemy_army"] = army
	encounters[encounter_index] = encounter
	session.overworld["encounters"] = encounters
	return count

static func _advance_siege(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String
) -> String:
	var target_placement_id = String(config.get("siege_target_placement_id", ""))
	if target_placement_id == "":
		return ""

	var target_town_result = _find_town_by_placement(session, target_placement_id)
	if int(target_town_result.get("index", -1)) < 0:
		state["siege_progress"] = 0
		return ""

	var target_town = target_town_result.get("town", {})
	if String(target_town.get("owner", "neutral")) != "player":
		state["siege_progress"] = 0
		return ""

	var required_raids = max(1, int(config.get("siege_active_raid_threshold", 2)))
	var capture_progress = max(1, int(config.get("siege_capture_progress", 2)))
	var raid_count = EnemyAdventureRulesScript.pressuring_raid_count(session, faction_id, target_placement_id)
	if raid_count < required_raids:
		state["siege_progress"] = max(0, int(state.get("siege_progress", 0)) - 1)
		return ""

	state["siege_progress"] = int(state.get("siege_progress", 0)) + 1
	var town_name = _town_name(target_town)
	if int(state.get("siege_progress", 0)) >= capture_progress:
		_set_town_owner(session, target_placement_id, "enemy")
		state["siege_progress"] = capture_progress
		return "%s overruns %s." % [String(config.get("label", faction_id)), town_name]

	return "%s tightens the siege around %s (%d/%d)." % [
		String(config.get("label", faction_id)),
		town_name,
		int(state.get("siege_progress", 0)),
		capture_progress,
	]

static func _can_launch_raid(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String
) -> bool:
	if _owned_town_count(session, faction_id) <= 0:
		return false
	var raid_threshold = _raid_threshold_for_strategy(session, config, faction_id)
	if int(state.get("pressure", 0)) < raid_threshold:
		return false
	if active_raid_count(session, faction_id) >= _max_active_raids_for_strategy(session, config, faction_id):
		return false
	if not EnemyAdventureRulesScript.has_available_raid_commander(
		session,
		faction_id,
		state.get("commander_roster", [])
	):
		return false
	var encounter_pool = config.get("raid_encounter_ids", [])
	if not (encounter_pool is Array) or encounter_pool.is_empty():
		return false
	return _first_open_spawn_point(session, config).size() > 0

static func _spawn_raid(session: SessionStateStoreScript.SessionData, config: Dictionary, state: Dictionary) -> Dictionary:
	var spawn_point = _first_open_spawn_point(session, config)
	if spawn_point.is_empty():
		return {}

	var encounter_pool = config.get("raid_encounter_ids", [])
	if not (encounter_pool is Array) or encounter_pool.is_empty():
		return {}

	var raid_counter = int(state.get("raid_counter", 0))
	var faction_id := String(config.get("faction_id", ""))
	var occupied_commander_ids: Dictionary = EnemyAdventureRulesScript.occupied_raid_commander_ids(session, faction_id)
	var roster_hero_id := EnemyAdventureRulesScript.select_raid_commander_roster_hero_id(
		session,
		faction_id,
		int(state.get("commander_counter", 0)),
		occupied_commander_ids,
		state.get("commander_roster", [])
	)
	if roster_hero_id == "":
		return {}
	var encounter_id = String(encounter_pool[raid_counter % encounter_pool.size()])
	state["raid_counter"] = raid_counter + 1
	state["commander_counter"] = int(state.get("commander_counter", 0)) + 1
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, String(config.get("faction_id", "")))
	var raid_threshold = _raid_threshold_for_strategy(session, config, String(config.get("faction_id", "")))
	var commitment_scale = clamp(
		EnemyAdventureRulesScript.strategy_scalar(strategy, "raid", "pressure_commitment_scale", 1.0),
		0.55,
		1.6
	)
	state["pressure"] = max(0, int(state.get("pressure", 0)) - int(round(float(raid_threshold) * commitment_scale)))

	var encounters = session.overworld.get("encounters", [])
	var placement_id = "%s_raid_%d" % [String(config.get("faction_id", "enemy")), int(state.get("raid_counter", 0))]
	var raid_seed: Dictionary = {
		"placement_id": placement_id,
		"encounter_id": encounter_id,
		"x": int(spawn_point.get("x", 0)),
		"y": int(spawn_point.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%d:%s" % [session.session_id, session.day, placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
	}
	raid_seed["enemy_commander_state"] = EnemyAdventureRulesScript.build_raid_commander_state(
		raid_seed,
		roster_hero_id,
		faction_id,
		session,
		occupied_commander_ids,
		state.get("commander_roster", [])
	)
	var raid = EnemyAdventureRulesScript.assign_target(
		session,
		config,
		EnemyAdventureRulesScript.ensure_raid_army(raid_seed, session, occupied_commander_ids)
	)
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var encounter_name: String = EnemyAdventureRulesScript.raid_display_name(raid)
	var target_suffix = ""
	if String(raid.get("target_label", "")) != "":
		target_suffix = " toward %s" % String(raid.get("target_label", ""))
	return {
		"ok": true,
		"message": "%s dispatches %s at %d,%d%s." % [
			String(config.get("label", config.get("faction_id", "Enemy"))),
			encounter_name,
			int(spawn_point.get("x", 0)),
			int(spawn_point.get("y", 0)),
			target_suffix,
		],
	}

static func _queue_town_defense_battle(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or not session.battle.is_empty():
		return {}
	var candidate = _town_defense_candidate(session, faction_id)
	if candidate.is_empty():
		return {}
	var encounter_index = int(candidate.get("encounter_index", -1))
	var town = candidate.get("town", {})
	var encounters = session.overworld.get("encounters", [])
	if encounter_index < 0 or encounter_index >= encounters.size() or town.is_empty():
		return {}
	var encounter = encounters[encounter_index]
	if not (encounter is Dictionary):
		return {}
	encounter["battle_context"] = {
		"type": "town_defense",
		"town_placement_id": String(town.get("placement_id", "")),
		"defending_hero_id": "",
		"raid_encounter_key": OverworldRulesScript.encounter_key(encounter),
		"trigger_faction_id": faction_id,
	}
	encounters[encounter_index] = encounter
	session.overworld["encounters"] = encounters

	var payload = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return {}
	session.battle = payload
	session.game_state = "battle"
	var commander_name := EnemyAdventureRulesScript.raid_commander_name(encounter)
	return {
		"battle_started": true,
		"message": (
			"%s launches an assault on %s." % [commander_name, _town_name(town)]
			if commander_name != ""
			else "%s launches an assault on %s." % [String(config.get("label", faction_id)), _town_name(town)]
		),
	}

static func _queue_hero_intercept_battle(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or not session.battle.is_empty():
		return {}
	var candidate = _hero_intercept_candidate(session, faction_id)
	if candidate.is_empty():
		return {}
	var encounter_index = int(candidate.get("encounter_index", -1))
	var encounter = candidate.get("encounter", {})
	var hero = candidate.get("hero", {})
	if encounter_index < 0 or encounter.is_empty() or hero.is_empty():
		return {}
	var hero_id := String(hero.get("id", ""))
	if hero_id == "":
		return {}
	var switch_result: Dictionary = HeroCommandRulesScript.set_active_hero(session, hero_id)
	if not bool(switch_result.get("ok", false)):
		return {}
	var encounters = session.overworld.get("encounters", [])
	encounter["battle_context"] = {
		"type": "hero_intercept",
		"target_hero_id": hero_id,
		"trigger_faction_id": faction_id,
	}
	encounters[encounter_index] = encounter
	session.overworld["encounters"] = encounters

	var payload = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return {}
	session.battle = payload
	session.game_state = "battle"
	var commander_name := EnemyAdventureRulesScript.raid_commander_name(encounter)
	return {
		"battle_started": true,
		"message": (
			"%s cuts off %s in the field." % [commander_name, String(hero.get("name", "the hero"))]
			if commander_name != ""
			else "%s cuts off %s in the field." % [String(config.get("label", faction_id)), String(hero.get("name", "the hero"))]
		),
	}

static func _town_defense_candidate(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var best = {}
	var best_distance = 9999
	var best_strength = -1
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var encounters = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if String(encounter.get("target_kind", "")) != "town":
			continue
		var town_result = _find_town_by_placement(session, String(encounter.get("target_placement_id", "")))
		var town = town_result.get("town", {})
		if town.is_empty() or String(town.get("owner", "neutral")) != "player":
			continue
		var goal_distance = int(encounter.get("goal_distance", 9999))
		if goal_distance > 1 and not bool(encounter.get("arrived", false)):
			continue
		var strength = EnemyAdventureRulesScript.raid_strength(encounter)
		if goal_distance < best_distance or (goal_distance == best_distance and strength > best_strength):
			best_distance = goal_distance
			best_strength = strength
			best = {"encounter_index": index, "encounter": encounter, "town": town}
	return best

static func _hero_intercept_candidate(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var best = {}
	var best_distance = 9999
	var best_strength = -1
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var encounters = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if String(encounter.get("target_kind", "")) != "hero":
			continue
		var hero = _find_player_hero(session, String(encounter.get("target_placement_id", "")))
		if hero.is_empty() or _hero_is_sheltered_in_player_town(session, hero):
			continue
		var goal_distance = int(encounter.get("goal_distance", 9999))
		if goal_distance > 1 and not bool(encounter.get("arrived", false)):
			continue
		var strength = EnemyAdventureRulesScript.raid_strength(encounter)
		if goal_distance < best_distance or (goal_distance == best_distance and strength > best_strength):
			best_distance = goal_distance
			best_strength = strength
			best = {"encounter_index": index, "encounter": encounter, "hero": hero}
	return best

static func _best_build_candidate(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	treasury: Dictionary,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	var best = {}
	var best_score = -1.0
	for building_id in OverworldRulesScript.get_town_build_options(town):
		var status: Dictionary = OverworldRulesScript.get_town_build_status(town, String(building_id))
		if not bool(status.get("buildable", false)):
			continue
		var building = status.get("building", {})
		var cost = building.get("cost", {})
		if not OverworldRulesScript.can_afford_cost_with_town_market(town, treasury, cost):
			continue
		var score = _score_build_candidate(session, town, building, cost, config, faction_id)
		if score > best_score:
			best_score = score
			best = {"building_id": String(building_id), "building": building, "cost": cost}
	return best

static func _score_build_candidate(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building: Dictionary,
	cost: Dictionary,
	config: Dictionary,
	faction_id: String
) -> float:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var building_id = String(building.get("id", ""))
	var current_income: Dictionary = OverworldRulesScript.town_income(town)
	var current_quality: int = OverworldRulesScript.town_reinforcement_quality(town, session)
	var current_readiness: int = OverworldRulesScript.town_battle_readiness(town, session)
	var current_pressure: int = OverworldRulesScript.town_pressure_output(town, session)
	var current_recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var current_market: Dictionary = OverworldRulesScript.town_market_state(town)
	var projected_town = town.duplicate(true)
	var built_buildings = projected_town.get("built_buildings", [])
	if not (built_buildings is Array):
		built_buildings = []
	built_buildings.append(building_id)
	projected_town["built_buildings"] = built_buildings
	var projected_income: Dictionary = OverworldRulesScript.town_income(projected_town)
	var projected_quality: int = OverworldRulesScript.town_reinforcement_quality(projected_town, session)
	var projected_readiness: int = OverworldRulesScript.town_battle_readiness(projected_town, session)
	var projected_pressure: int = OverworldRulesScript.town_pressure_output(projected_town, session)
	var projected_recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, projected_town)
	var projected_market: Dictionary = OverworldRulesScript.town_market_state(projected_town)
	var town_role: String = OverworldRulesScript.town_strategic_role(town)
	var capital_project = building.get("capital_project", {})
	var marginal_income = _resource_value(_subtract_resource_pools(projected_income, current_income))
	var growth_value = 0.0
	for unit_id in _building_growth_payload(building_id).keys():
		growth_value += float(int(_building_growth_payload(building_id)[unit_id]) * 120)
	var quality_value = max(0.0, float(projected_quality - current_quality) * 18.0)
	var readiness_value = max(0.0, float(projected_readiness - current_readiness) * 10.0)
	var pressure_value = max(0.0, float(projected_pressure - current_pressure) * 140.0)
	var recovery_value = 0.0
	var relief_delta = int(projected_recovery.get("relief_per_day", 1)) - int(current_recovery.get("relief_per_day", 1))
	if relief_delta > 0:
		if bool(current_recovery.get("active", false)):
			recovery_value += float(relief_delta) * 85.0
		elif town_role in ["capital", "stronghold"] or (capital_project is Dictionary and not capital_project.is_empty()):
			recovery_value += float(relief_delta) * 45.0
	var market_value = 0.0
	if bool(projected_market.get("active", false)) and not bool(current_market.get("active", false)):
		market_value += 180.0
	market_value += max(
		0.0,
		float(int(projected_market.get("exchange_value", 0)) - int(current_market.get("exchange_value", 0))) * 0.55
	)

	var score = (
		marginal_income * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "income", 1.0)
		+ growth_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "growth", 1.0)
		+ quality_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "quality", 1.0)
		+ readiness_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "readiness", 1.0)
		+ pressure_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "pressure", 1.0)
		+ recovery_value
		+ market_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "income", 1.0)
	)
	var category = String(building.get("category", "support"))
	var category_bonus = 0.0
	match category:
		"economy":
			category_bonus = 240.0
		"dwelling":
			category_bonus = 180.0
		"support":
			category_bonus = 150.0
		"civic":
			category_bonus = 110.0
		"magic":
			category_bonus = 60.0
	score += category_bonus * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_category_weights", category, 1.0)
	if String(building.get("upgrade_from", "")) != "":
		score += 90.0
	if _desired_town_strength(session, town, config) > _army_strength(town.get("garrison", [])):
		if category in ["support", "dwelling"]:
			score += 120.0 * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0)
	if active_raid_count(session, faction_id) < _max_active_raids_for_strategy(session, config, faction_id) and category == "dwelling":
		score += 90.0 * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0)
	if capital_project is Dictionary and not capital_project.is_empty():
		var project_score = 260.0
		match town_role:
			"capital":
				project_score += 320.0
			"stronghold":
				project_score += 160.0
		if session.day >= 4:
			project_score += 180.0
		if active_raid_count(session, faction_id) >= max(1, _max_active_raids_for_strategy(session, config, faction_id) - 1):
			project_score += 120.0
		if String(config.get("siege_target_placement_id", "")) != "":
			project_score += 80.0
		score += project_score
	elif town_role == "capital" and category in ["support", "civic", "magic"]:
		score += 110.0
	elif town_role == "stronghold" and category in ["support", "civic", "dwelling"]:
		score += 80.0
	var efficiency_divisor = max(400.0, float(_resource_value(cost)))
	return score / (efficiency_divisor / 400.0)

static func _determine_posture(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	towns: Array
) -> String:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var threatened_towns = 0
	for town in towns:
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		if _army_strength(town.get("garrison", [])) < _desired_town_strength(session, town, config):
			threatened_towns += 1
	if threatened_towns > 0 and EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0) >= 1.0:
		return "fortifying"
	if active_raid_count(session, faction_id) > 0:
		return "raiding"
	var threshold = _raid_threshold_for_strategy(session, config, faction_id)
	if (
		int(state.get("pressure", 0)) >= threshold
		and not EnemyAdventureRulesScript.has_available_raid_commander(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		and EnemyAdventureRulesScript.recovering_commander_count(
			session,
			faction_id,
			state.get("commander_roster", [])
		) > 0
	):
		return "reorganizing"
	if int(state.get("pressure", 0)) >= threshold:
		return "massing"
	if threatened_towns > 0:
		return "fortifying"
	return "probing"

static func _public_posture_label(state: Dictionary, raid_threshold: int, faction_id: String) -> String:
	match _normalize_posture(state.get("posture", "probing")):
		"reorganizing":
			match faction_id:
				"faction_embercourt":
					return "Road captains are reorganizing after the last clash"
				"faction_mireclaw":
					return "Wounded warbands are slipping back into the reeds to regroup"
				"faction_sunvault":
					return "Relay commanders are recalibrating after the last exchange"
			return "Hostile commanders are regrouping before the next push"
		"fortifying":
			match faction_id:
				"faction_embercourt":
					return "Beacon towns are drawing disciplined levies onto the walls"
				"faction_mireclaw":
					return "Stockades are beating the drums for a local stand"
				"faction_sunvault":
					return "Relay keeps are locking into prepared firing lines"
			return "Border towns are pulling fresh troops onto the walls"
		"raiding":
			match faction_id:
				"faction_embercourt":
					return "Charter columns are pushing measured raids down the lanes"
				"faction_mireclaw":
					return "Warbands are spilling forward in staggered packs"
				"faction_sunvault":
					return "Compact sorties are testing the frontier behind relay screens"
			return "Field hosts are driving raids into the frontier"
		"massing":
			if int(state.get("pressure", 0)) >= raid_threshold * 2:
				match faction_id:
					"faction_embercourt":
						return "A heavier charter assault is assembling behind the line"
					"faction_mireclaw":
						return "A deeper mire surge is gathering in the reeds"
					"faction_sunvault":
						return "Another calibrated battery strike is aligning behind the front"
				return "A heavier strike is gathering behind the lines"
			match faction_id:
				"faction_embercourt":
					return "Quartermasters are assembling another road-bound column"
				"faction_mireclaw":
					return "Fresh cutters are massing for another sudden push"
				"faction_sunvault":
					return "Arrays are lining up for another focused push"
			return "War bands are massing for another strike"
		"collapsed":
			return "The hostile empire has lost its strongholds"
		_:
			match faction_id:
				"faction_embercourt":
					return "Scouts report charter patrols measuring the line"
				"faction_mireclaw":
					return "Scouts report mire runners probing for soft targets"
				"faction_sunvault":
					return "Scouts report relay pickets calibrating the approaches"
			return "Scouts report patrols probing for openings"

static func _first_open_spawn_point(session: SessionStateStoreScript.SessionData, config: Dictionary) -> Dictionary:
	var spawn_points = config.get("spawn_points", [])
	if not (spawn_points is Array):
		return {}

	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var hero_position = session.overworld.get("hero_position", {"x": -1, "y": -1})
	for point in spawn_points:
		if not (point is Dictionary):
			continue
		var x = int(point.get("x", -1))
		var y = int(point.get("y", -1))
		if x == int(hero_position.get("x", -99)) and y == int(hero_position.get("y", -99)):
			continue

		var occupied = false
		for encounter in session.overworld.get("encounters", []):
			if not (encounter is Dictionary):
				continue
			if int(encounter.get("x", -1)) != x or int(encounter.get("y", -1)) != y:
				continue
			if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
				continue
			occupied = true
			break

		if not occupied:
			return {"x": x, "y": y}
	return {}

static func _owned_town_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return _owned_town_entries(session, faction_id).size()

static func _owned_town_entries(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var entries = []
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		entries.append({"index": index, "town": town})
	return entries

static func _faction_capital_state(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	return _faction_capital_state_from_towns(session, session.overworld.get("towns", []), faction_id)

static func _faction_capital_state_from_towns(
	session: SessionStateStoreScript.SessionData,
	towns: Array,
	faction_id: String
) -> Dictionary:
	var state = {
		"capital_count": 0,
		"stronghold_count": 0,
		"anchor_labels": [],
		"active_project_labels": [],
		"dormant_project_labels": [],
		"pressure_bonus": 0,
		"defense_bonus": 0,
		"raid_threshold_reduction": 0,
		"max_active_raids_bonus": 0,
		"active_projects": 0,
		"support_gap": 0,
		"recovery_pressure": 0,
	}
	for town in towns:
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		var role: String = OverworldRulesScript.town_strategic_role(town)
		var town_name = _town_name(town)
		match role:
			"capital":
				state["capital_count"] = int(state.get("capital_count", 0)) + 1
				state["anchor_labels"].append(town_name)
			"stronghold":
				state["stronghold_count"] = int(state.get("stronghold_count", 0)) + 1
				state["anchor_labels"].append(town_name)
		var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
		if int(capital_project.get("active", 0)) > 0:
			state["active_projects"] = int(state.get("active_projects", 0)) + int(capital_project.get("active", 0))
			state["active_project_labels"].append(town_name)
			state["pressure_bonus"] = int(state.get("pressure_bonus", 0)) + int(capital_project.get("pressure_bonus", 0))
			state["defense_bonus"] = int(state.get("defense_bonus", 0)) + int(capital_project.get("defense_bonus", 0))
			state["raid_threshold_reduction"] = int(state.get("raid_threshold_reduction", 0)) + int(capital_project.get("raid_threshold_reduction", 0))
			state["max_active_raids_bonus"] = int(state.get("max_active_raids_bonus", 0)) + int(capital_project.get("max_active_raids_bonus", 0))
			state["support_gap"] = int(state.get("support_gap", 0)) + int(capital_project.get("support_gap", 0))
		elif int(capital_project.get("total", 0)) > 0:
			state["dormant_project_labels"].append(town_name)
		state["recovery_pressure"] = int(state.get("recovery_pressure", 0)) + int(OverworldRulesScript.town_recovery_state(session, town).get("pressure", 0))
	return state

static func _capital_watch_summary(capital_state: Dictionary) -> String:
	var active_labels = capital_state.get("active_project_labels", [])
	if active_labels is Array and not active_labels.is_empty():
		var parts = ["Capital watch: %s online" % ", ".join(active_labels)]
		if int(capital_state.get("pressure_bonus", 0)) > 0:
			parts.append("pressure +%d" % int(capital_state.get("pressure_bonus", 0)))
		if int(capital_state.get("max_active_raids_bonus", 0)) > 0:
			parts.append("raid slots +%d" % int(capital_state.get("max_active_raids_bonus", 0)))
		if int(capital_state.get("support_gap", 0)) > 0:
			parts.append("logistics gaps %d" % int(capital_state.get("support_gap", 0)))
		if int(capital_state.get("recovery_pressure", 0)) > 0:
			parts.append("recovery %d" % int(capital_state.get("recovery_pressure", 0)))
		return ", ".join(parts)
	var dormant_labels = capital_state.get("dormant_project_labels", [])
	if dormant_labels is Array and not dormant_labels.is_empty():
		return "Capital watch: %s still anchors the front" % ", ".join(dormant_labels)
	var anchor_labels = capital_state.get("anchor_labels", [])
	if anchor_labels is Array and not anchor_labels.is_empty():
		return "Anchor watch: %s remain the backbone of the front" % ", ".join(anchor_labels)
	return ""

static func _desired_town_strength(session: SessionStateStoreScript.SessionData, town: Dictionary, config: Dictionary) -> int:
	var built_count = 0
	for _building_id in _normalized_built_buildings(town):
		built_count += 1
	var faction_id = _town_faction_id(town)
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var hero_position = session.overworld.get("hero_position", {"x": 0, "y": 0})
	var distance = abs(int(hero_position.get("x", 0)) - int(town.get("x", 0))) + abs(int(hero_position.get("y", 0)) - int(town.get("y", 0)))
	var town_role: String = OverworldRulesScript.town_strategic_role(town)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var target = 140 + (built_count * 18)
	target += int(round(float(OverworldRulesScript.town_battle_readiness(town, session)) / 2.0))
	match town_role:
		"capital":
			target += 140
		"stronghold":
			target += 70
	if int(capital_project.get("active", 0)) > 0:
		target += int(round(float(int(capital_project.get("defense_bonus", 0))) * 0.55))
		target += int(capital_project.get("active", 0)) * 20
	elif int(capital_project.get("total", 0)) > 0:
		target += 30
	target += int(logistics.get("support_gap", 0)) * 24
	target += int(logistics.get("threatened_count", 0)) * 18
	target += int(logistics.get("delivery_count", 0)) * 16
	target += int(recovery.get("pressure", 0)) * 10
	if distance <= 6:
		target += 120
	if distance <= 3:
		target += 100
	if String(config.get("siege_target_placement_id", "")) == String(town.get("placement_id", "")):
		target += 60
	elif String(config.get("siege_target_placement_id", "")) != "":
		target += 20
	if session.day >= 4 and town_role in ["capital", "stronghold"]:
		target += 25
	target = int(round(float(target) * clamp(
		EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0),
		0.75,
		1.45
	)))
	return max(120, target)

static func _empire_strength_pressure_bonus(session: SessionStateStoreScript.SessionData, faction_id: String, towns: Array) -> int:
	var total_strength = 0
	for town in towns:
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		total_strength += _army_strength(town.get("garrison", []))
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		total_strength += EnemyAdventureRulesScript.raid_strength(encounter)
	return clamp(int(total_strength / 250), 0, 3)

static func _empire_town_pressure_bonus(session: SessionStateStoreScript.SessionData, faction_id: String, towns: Array) -> int:
	var total_pressure = 0
	for town in towns:
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		total_pressure += OverworldRulesScript.town_pressure_output(town, session)
	return clamp(int(floor(float(total_pressure) / 4.0)), 0, 5)

static func _empire_capital_pressure_bonus(capital_state: Dictionary, day: int) -> int:
	var bonus = int(capital_state.get("pressure_bonus", 0))
	var anchor_count = int(capital_state.get("capital_count", 0)) + int(capital_state.get("stronghold_count", 0))
	if day >= 4 and anchor_count > 0:
		bonus += min(2, anchor_count)
	if day >= 5 and int(capital_state.get("active_projects", 0)) > 0:
		bonus += 1
	return max(0, bonus)

static func _raid_threshold_for_strategy(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> int:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var base_threshold = DifficultyRulesScript.adjust_raid_threshold(session, max(1, int(config.get("raid_threshold", 1))))
	var threshold_scale = clamp(
		EnemyAdventureRulesScript.strategy_scalar(strategy, "raid", "threshold_scale", 1.0),
		0.65,
		1.5
	)
	var threshold = max(1, int(round(float(base_threshold) * threshold_scale)))
	var capital_state = _faction_capital_state(session, faction_id)
	threshold -= int(capital_state.get("raid_threshold_reduction", 0))
	if session.day >= 5 and int(capital_state.get("active_projects", 0)) > 0:
		threshold -= 1
	return max(1, threshold)

static func _max_active_raids_for_strategy(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> int:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var capital_state = _faction_capital_state(session, faction_id)
	return max(
		1,
		int(config.get("max_active_raids", 1))
		+ EnemyAdventureRulesScript.strategy_int(strategy, "raid", "max_active_bonus", 0)
		+ int(capital_state.get("max_active_raids_bonus", 0))
	)

static func _recruit_priority(unit_id: String, config: Dictionary, faction_id: String) -> float:
	var unit = ContentService.get_unit(unit_id)
	if unit.is_empty():
		return 0.0
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var score = float(max(1, int(unit.get("tier", 1))) * 100)
	if bool(unit.get("ranged", false)):
		score *= EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "ranged_weight", 1.0)
	else:
		score *= EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "melee_weight", 1.0)
	if max(1, int(unit.get("tier", 1))) <= 2:
		score *= EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "low_tier_weight", 1.0)
	else:
		score *= EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "high_tier_weight", 1.0)
	if bool(unit.get("flying", false)):
		score += 18.0
	var abilities = unit.get("ability_ids", [])
	if abilities is Array:
		if "brace" in abilities:
			score += 16.0
		if "volley" in abilities:
			score += 18.0
		if "bloodrush" in abilities:
			score += 14.0
	return score

static func _enemy_recruit_cost(town: Dictionary, unit_id: String) -> Dictionary:
	var unit = ContentService.get_unit(unit_id)
	return _apply_discount(unit.get("cost", {}), _recruitment_discount_percent(town, unit_id))

static func _recruitment_discount_percent(town: Dictionary, unit_id: String) -> int:
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	var total_discount = _discount_from_profile(town_template.get("recruitment", {}), unit_id)
	total_discount += _discount_from_profile(
		ContentService.get_faction(String(town_template.get("faction_id", ""))).get("recruitment", {}),
		unit_id
	)
	for building_id in _normalized_built_buildings(town):
		var recruit_discount = ContentService.get_building(String(building_id)).get("recruitment_discount_percent", {})
		if recruit_discount is Dictionary:
			total_discount += int(recruit_discount.get(unit_id, 0))
	return clamp(total_discount, 0, 75)

static func _discount_from_profile(profile: Variant, unit_id: String) -> int:
	if not (profile is Dictionary):
		return 0
	var discounts = profile.get("cost_discount_percent", {})
	if not (discounts is Dictionary):
		return 0
	return max(0, int(discounts.get(unit_id, 0)))

static func _building_growth_payload(building_id: String) -> Dictionary:
	var payload = {}
	var building = ContentService.get_building(building_id)
	var unlock_unit_id = String(building.get("unlock_unit_id", ""))
	if unlock_unit_id != "":
		payload[unlock_unit_id] = _scenario_factory()._unit_growth(unlock_unit_id)
	var growth_bonus = building.get("growth_bonus", {})
	if growth_bonus is Dictionary:
		for unit_id in growth_bonus.keys():
			payload[String(unit_id)] = int(payload.get(String(unit_id), 0)) + int(growth_bonus[unit_id])
	return payload

static func _merge_recruits(base: Variant, delta: Variant) -> Dictionary:
	var merged = {}
	if base is Dictionary:
		for unit_id in base.keys():
			merged[String(unit_id)] = max(0, int(base[unit_id]))
	if delta is Dictionary:
		for unit_id in delta.keys():
			merged[String(unit_id)] = int(merged.get(String(unit_id), 0)) + max(0, int(delta[unit_id]))
	return merged

static func _consume_recruits(base: Variant, unit_id: String, amount: int) -> Dictionary:
	var remaining = {}
	if base is Dictionary:
		for existing_unit_id in base.keys():
			remaining[String(existing_unit_id)] = max(0, int(base[existing_unit_id]))
	remaining[unit_id] = max(0, int(remaining.get(unit_id, 0)) - max(0, amount))
	return remaining

static func _army_strength(stacks: Variant) -> int:
	var total = 0
	if not (stacks is Array):
		return total
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var unit_id = String(stack.get("unit_id", ""))
		var count = max(0, int(stack.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		var unit = ContentService.get_unit(unit_id)
		var per_unit_strength = max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
		total += per_unit_strength * count
	return total

static func _add_stack(stacks: Variant, unit_id: String, amount: int) -> Array:
	var normalized = []
	var added = false
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

static func _can_afford_from_pool(pool: Dictionary, cost: Variant) -> bool:
	if not (cost is Dictionary):
		return true
	for key in cost.keys():
		if int(pool.get(String(key), 0)) < max(0, int(cost[key])):
			return false
	return true

static func _max_affordable_from_pool(pool: Dictionary, unit_cost: Variant) -> int:
	if not (unit_cost is Dictionary) or unit_cost.is_empty():
		return 999
	var max_affordable = 999
	for key in unit_cost.keys():
		var price = max(1, int(unit_cost[key]))
		max_affordable = min(max_affordable, int(int(pool.get(String(key), 0)) / price))
	return max_affordable

static func _spend_from_pool(pool: Dictionary, cost: Variant) -> void:
	if not (cost is Dictionary):
		return
	for key in cost.keys():
		var resource_key = String(key)
		pool[resource_key] = max(0, int(pool.get(resource_key, 0)) - max(0, int(cost[key])))

static func _scale_resource_pool(cost: Variant, multiplier: int) -> Dictionary:
	var scaled = {}
	if not (cost is Dictionary):
		return scaled
	for key in cost.keys():
		scaled[String(key)] = max(0, int(cost[key])) * max(0, multiplier)
	return scaled

static func _merge_resource_pools(base: Variant, delta: Variant) -> Dictionary:
	var merged = _normalize_resource_pool(base)
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key = String(key)
			merged[resource_key] = int(merged.get(resource_key, 0)) + int(delta[key])
	return merged

static func _subtract_resource_pools(base: Variant, delta: Variant) -> Dictionary:
	var difference = _normalize_resource_pool(base)
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key = String(key)
			difference[resource_key] = int(difference.get(resource_key, 0)) - int(delta[key])
	return difference

static func _normalize_resource_pool(value: Variant) -> Dictionary:
	var normalized = _blank_resource_pool()
	if value is Dictionary:
		for key in value.keys():
			normalized[String(key)] = max(0, int(value[key]))
	return normalized

static func _blank_resource_pool() -> Dictionary:
	var resources = {}
	for resource_key in TRACKED_RESOURCES:
		resources[resource_key] = 0
	return resources

static func _resource_value(resources: Variant) -> int:
	var value = 0
	if not (resources is Dictionary):
		return value
	value += int(resources.get("gold", 0))
	value += int(resources.get("wood", 0)) * 400
	value += int(resources.get("ore", 0)) * 400
	return value

static func _apply_discount(cost: Variant, discount_percent: int) -> Dictionary:
	var discounted = {}
	var clamped_discount = clamp(discount_percent, 0, 75)
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key = String(key)
			var base_amount = max(0, int(cost[key]))
			discounted[resource_key] = int(ceili(float(base_amount * (100 - clamped_discount)) / 100.0))
	return discounted

static func _normalize_posture(value: Variant) -> String:
	var posture = String(value)
	if posture in ["probing", "massing", "raiding", "fortifying", "reorganizing", "collapsed"]:
		return posture
	return "probing"

static func _normalize_string_array(value: Variant) -> Array:
	var normalized = []
	if not (value is Array):
		return normalized
	for entry in value:
		var item = String(entry)
		if item != "" and item not in normalized:
			normalized.append(item)
	return normalized

static func _captured_artifact_ids(state: Dictionary) -> Array:
	return _normalize_string_array(state.get("captured_artifact_ids", []))

static func _captured_artifact_income(state: Dictionary) -> Dictionary:
	var income = _blank_resource_pool()
	for artifact_id_value in _captured_artifact_ids(state):
		var artifact = ContentService.get_artifact(String(artifact_id_value))
		if artifact.is_empty():
			continue
		income = _merge_resource_pools(income, artifact.get("bonuses", {}).get("daily_income", {}))
	return income

static func _captured_artifact_pressure_bonus(state: Dictionary) -> int:
	var pressure_bonus = 0
	for artifact_id_value in _captured_artifact_ids(state):
		var artifact = ContentService.get_artifact(String(artifact_id_value))
		if artifact.is_empty():
			continue
		var bonuses = artifact.get("bonuses", {})
		pressure_bonus += max(0, int(bonuses.get("overworld_movement", 0)))
		pressure_bonus += max(0, int(bonuses.get("scouting_radius", 0)))
		pressure_bonus += max(0, int(bonuses.get("battle_initiative", 0)))
		pressure_bonus += max(0, int(bonuses.get("battle_attack", 0)))
		pressure_bonus += max(0, int(bonuses.get("battle_defense", 0)))
		if _resource_value(bonuses.get("daily_income", {})) >= 400:
			pressure_bonus += 1
	return clamp(pressure_bonus, 0, 4)

static func _captured_artifact_summary(state: Dictionary) -> String:
	var artifact_count = _captured_artifact_ids(state).size()
	if artifact_count <= 0:
		return ""
	return "%d seized relic%s fueling the campaign" % [artifact_count, "" if artifact_count == 1 else "s"]

static func _normalized_built_buildings(town: Dictionary) -> Array:
	var normalized = []
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in town_template.get("starting_building_ids", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	for building_id_value in town.get("built_buildings", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	return normalized

static func _append_building_with_requirements(target: Array, building_id: String, trail: Array = []) -> void:
	if building_id == "" or building_id in target or building_id in trail:
		return
	var next_trail = trail.duplicate(true)
	next_trail.append(building_id)
	var building = ContentService.get_building(building_id)
	var upgrade_from = String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		_append_building_with_requirements(target, upgrade_from, next_trail)
	for requirement_value in building.get("requires", []):
		_append_building_with_requirements(target, String(requirement_value), next_trail)
	target.append(building_id)

static func _describe_recruit_delta(delta: Variant) -> String:
	if not (delta is Dictionary) or delta.is_empty():
		return ""
	var parts = []
	var unit_ids = []
	for unit_id_value in delta.keys():
		unit_ids.append(String(unit_id_value))
	unit_ids.sort()
	for unit_id in unit_ids:
		var amount = int(delta.get(unit_id, 0))
		if amount <= 0:
			continue
		var unit = ContentService.get_unit(unit_id)
		parts.append("+%d %s" % [amount, String(unit.get("name", unit_id))])
	return ", ".join(parts)

static func _find_state(states: Variant, faction_id: String) -> Dictionary:
	if states is Array:
		for state in states:
			if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
				return state
	return {}

static func _find_state_index(states: Variant, faction_id: String) -> int:
	if states is Array:
		for index in range(states.size()):
			var state = states[index]
			if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
				return index
	return -1

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_player_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	for hero_value in session.overworld.get("player_heroes", []):
		if hero_value is Dictionary and String(hero_value.get("id", "")) == hero_id:
			return hero_value
	return {}

static func _hero_is_sheltered_in_player_town(session: SessionStateStoreScript.SessionData, hero: Dictionary) -> bool:
	if session == null or hero.is_empty():
		return false
	var hero_x := int(hero.get("position", {}).get("x", -1))
	var hero_y := int(hero.get("position", {}).get("y", -1))
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		if String(town_value.get("owner", "neutral")) != "player":
			continue
		if int(town_value.get("x", -2)) == hero_x and int(town_value.get("y", -2)) == hero_y:
			return true
	return false

static func _set_town_owner(session: SessionStateStoreScript.SessionData, placement_id: String, owner: String) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

static func _town_name(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("name", town_state.get("town_id", "Town")))

static func _town_faction_id(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("faction_id", ""))
