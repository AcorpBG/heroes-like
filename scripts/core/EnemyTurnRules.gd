class_name EnemyTurnRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
static var SpellRulesScript: Variant = load("res://scripts/core/SpellRules.gd")
static var TownRulesScript: Variant = load("res://scripts/core/TownRules.gd")
static var BattleRulesScript: Variant = load("res://scripts/core/BattleRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")

const TRACKED_RESOURCES := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const ENEMY_TOWN_DEVELOPMENT_MIN_COMPLETION_DAY := 24

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

	var configs = _enemy_faction_configs_for_session(session)
	var existing_states = session.overworld.get("enemy_states", [])
	var normalized_states = []

	if configs is Array:
		for config in configs:
			if not (config is Dictionary):
				continue
			var faction_id = String(config.get("faction_id", ""))
			var existing_state = _find_state(existing_states, faction_id)
			var normalized_state := {
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
			var known_world_memory := EnemyAdventureRulesScript.normalize_enemy_known_world_memory(
				existing_state.get("known_world_memory", {}),
				int(session.day)
			)
			if not known_world_memory.is_empty():
				normalized_state["known_world_memory"] = known_world_memory
			if existing_state.has("hero_task_state"):
				var task_state_report := normalize_optional_hero_task_state(existing_state.get("hero_task_state", {}))
				if bool(task_state_report.get("ok", false)) and bool(task_state_report.get("normalized_present", false)):
					normalized_state["hero_task_state"] = task_state_report.get("task_state", {})
			normalized_states.append(normalized_state)

	session.overworld["enemy_states"] = normalized_states
	EnemyAdventureRulesScript.normalize_raid_armies(session)
	EnemyAdventureRulesScript.normalize_all_commander_rosters(session)

static func normalize_optional_hero_task_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {
			"ok": false,
			"normalized_present": false,
			"invalid_reason": "hero_task_state_not_dictionary",
			"input_task_count": 0,
			"normalized_task_count": 0,
			"dropped_task_count": 0,
			"sanitized_field_count": 0,
			"observed_policy": "dropped_invalid_board",
		}
	var source: Dictionary = value
	var tasks_value = source.get("tasks", [])
	if not (tasks_value is Array):
		return {
			"ok": false,
			"normalized_present": false,
			"invalid_reason": "hero_task_state_tasks_not_array",
			"input_task_count": 0,
			"normalized_task_count": 0,
			"dropped_task_count": 0,
			"sanitized_field_count": max(0, source.keys().size()),
			"observed_policy": "dropped_invalid_board",
		}
	var normalized_tasks := []
	var dropped_count := 0
	var sanitized_count := _hero_task_state_board_sanitized_field_count(source)
	for task_value in tasks_value:
		var task_report := _normalize_hero_task_record(task_value)
		sanitized_count += int(task_report.get("sanitized_field_count", 0))
		if bool(task_report.get("ok", false)):
			normalized_tasks.append(task_report.get("task", {}))
		else:
			dropped_count += 1
	return {
		"ok": true,
		"normalized_present": true,
		"task_state": {
			"schema_version": clamp(max(1, int(source.get("schema_version", 1))), 1, 1),
			"planner_epoch": max(0, int(source.get("planner_epoch", 0))),
			"tasks": normalized_tasks,
		},
		"input_task_count": tasks_value.size(),
		"normalized_task_count": normalized_tasks.size(),
		"dropped_task_count": dropped_count,
		"sanitized_field_count": sanitized_count,
		"observed_policy": "preserved_and_normalized",
	}

static func run_enemy_turn(session: SessionStateStoreScript.SessionData) -> Dictionary:
	DifficultyRulesScript.normalize_session(session)
	normalize_enemy_states(session)
	var configs = _enemy_faction_configs_for_session(session)
	if not (configs is Array) or configs.is_empty():
		return {"ok": true, "message": ""}

	var states = session.overworld.get("enemy_states", [])
	var messages = []
	var events = []
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
		_append_event_records(events, turn_result.get("events", []))
		states[state_index] = state

	session.overworld["enemy_states"] = states
	EnemyAdventureRulesScript.normalize_all_commander_rosters(session)
	return {"ok": true, "message": " ".join(messages), "events": events}

static func run_enemy_town_economy_turn(
	session: SessionStateStoreScript.SessionData,
	faction_id_filter: String = ""
) -> Dictionary:
	DifficultyRulesScript.normalize_session(session)
	normalize_enemy_states(session)
	var configs = _enemy_faction_configs_for_session(session)
	if not (configs is Array) or configs.is_empty():
		return {"ok": true, "message": "", "events": []}

	var states = session.overworld.get("enemy_states", [])
	var towns = session.overworld.get("towns", [])
	var messages := []
	var events := []
	var should_apply_weekly_growth: bool = OverworldRulesScript.is_weekly_growth_day(session.day)
	for config in configs:
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		if faction_id_filter != "" and faction_id != faction_id_filter:
			continue
		var state_index := _find_state_index(states, faction_id)
		if state_index < 0:
			continue
		var state: Dictionary = states[state_index]
		var town_entries := _owned_town_entries(session, faction_id)
		var treasury := _normalize_resource_pool(state.get("treasury", {}))
		_apply_empire_income(session, town_entries, treasury, state)
		if should_apply_weekly_growth:
			var muster_message := _apply_weekly_musters(session, town_entries, towns, faction_id, config)
			if muster_message != "":
				messages.append(muster_message)
			session.overworld["towns"] = towns
		var build_result := _build_in_enemy_towns(session, town_entries, towns, treasury, faction_id, config)
		var build_messages: Array = build_result.get("messages", [])
		if not build_messages.is_empty():
			messages.append_array(build_messages)
		_append_event_records(events, build_result.get("events", []))
		session.overworld["towns"] = towns
		var study_result := _study_spells_in_enemy_towns(session, config, town_entries, towns, faction_id, state)
		state = study_result.get("state", state)
		var study_messages: Array = study_result.get("messages", [])
		if not study_messages.is_empty():
			messages.append_array(study_messages)
		_append_event_records(events, study_result.get("events", []))
		state["treasury"] = treasury
		states[state_index] = state
	session.overworld["enemy_states"] = states
	EnemyAdventureRulesScript.normalize_all_commander_rosters(session)
	return {"ok": true, "message": " ".join(messages), "events": events}

static func _append_event_records(output: Array, events_value: Variant) -> void:
	if not (events_value is Array):
		return
	for event_value in events_value:
		if event_value is Dictionary and not event_value.is_empty():
			output.append(event_value)

static func describe_threats(session: SessionStateStoreScript.SessionData) -> String:
	normalize_enemy_states(session)
	var configs = _enemy_faction_configs_for_session(session)
	if not (configs is Array) or configs.is_empty():
		return "No hostile factions are active."

	var lines = []
	for config in configs:
		if not (config is Dictionary):
			continue
		var faction_id = String(config.get("faction_id", ""))
		var state = _find_state(session.overworld.get("enemy_states", []), faction_id)
		var front_state := _faction_front_state(session, faction_id)
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
		var front_summary := String(front_state.get("summary", ""))
		if front_summary != "":
			line_parts.append(front_summary)
		var commander_recovery = EnemyAdventureRulesScript.public_commander_recovery_summary(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		if commander_recovery != "":
			line_parts.append(commander_recovery)
		var commander_rebuild = EnemyAdventureRulesScript.public_commander_rebuild_summary(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		if commander_rebuild != "":
			line_parts.append(commander_rebuild)
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
		var commander_memory = EnemyAdventureRulesScript.raid_commander_memory_summaries(
			_visible_raids_for_faction(session, faction_id),
			2
		)
		if not commander_memory.is_empty():
			line_parts.append("Command memory %s" % ", ".join(commander_memory))
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

static func town_governor_pressure_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary = {},
	faction_id: String = ""
) -> Dictionary:
	if session == null:
		return {}
	DifficultyRulesScript.normalize_session(session)
	normalize_enemy_states(session)
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	if config.is_empty() or resolved_faction_id == "":
		for enemy_config in _enemy_faction_configs_for_session(session):
			if not (enemy_config is Dictionary):
				continue
			if resolved_faction_id == "" or String(enemy_config.get("faction_id", "")) == resolved_faction_id:
				config = enemy_config
				resolved_faction_id = String(config.get("faction_id", resolved_faction_id))
				break
	if resolved_faction_id == "":
		return {}

	var state := _find_state(session.overworld.get("enemy_states", []), resolved_faction_id)
	var current_treasury := _normalize_resource_pool(state.get("treasury", {}))
	var projected_treasury := current_treasury.duplicate(true)
	var town_entries := _owned_town_entries(session, resolved_faction_id)
	var income := _apply_empire_income(session, town_entries, projected_treasury, state)
	var towns := []
	for entry in town_entries:
		var town: Dictionary = entry.get("town", {})
		var town_report := town_governor_town_report(
			session,
			config,
			town,
			projected_treasury,
			resolved_faction_id,
			true
		)
		if not town_report.is_empty():
			towns.append(town_report)
	return {
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"faction_id": resolved_faction_id,
		"faction_label": String(config.get("label", resolved_faction_id)),
		"current_treasury": current_treasury,
		"income_projection": income,
		"projected_treasury": projected_treasury,
		"town_count": towns.size(),
		"towns": towns,
	}

static func town_governor_town_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	treasury: Dictionary,
	faction_id: String,
	include_projected_build: bool = true
) -> Dictionary:
	if town.is_empty():
		return {}
	var build_report := town_build_pressure_report(session, config, town, treasury, faction_id)
	var projected_town := town.duplicate(true)
	var projected_treasury := _normalize_resource_pool(treasury)
	var selected_build: Dictionary = build_report.get("selected_build", {})
	if include_projected_build and not selected_build.is_empty():
		var building_id := String(selected_build.get("building_id", ""))
		var cost: Dictionary = selected_build.get("cost", {})
		OverworldRulesScript.apply_market_cost_coverage(projected_town, projected_treasury, cost, int(session.day))
		_spend_from_pool(projected_treasury, cost)
		var built_buildings = projected_town.get("built_buildings", [])
		if not (built_buildings is Array):
			built_buildings = []
		built_buildings = built_buildings.duplicate(true)
		built_buildings.append(building_id)
		projected_town["built_buildings"] = built_buildings
		projected_town["available_recruits"] = _merge_recruits(
			projected_town.get("available_recruits", {}),
			_building_growth_payload(building_id)
		)
	var recruit_report := town_recruitment_pressure_report(
		session,
		config,
		projected_town,
		projected_treasury,
		faction_id
	)
	var events := []
	var build_event := ai_town_build_event(session, config, town, selected_build)
	if not build_event.is_empty():
		events.append(build_event)
	var recruit_events: Array = recruit_report.get("events", [])
	for event in recruit_events:
		if event is Dictionary and not event.is_empty():
			events.append(event)
	return {
		"placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"town_label": _town_name(town),
		"strategic_role": OverworldRulesScript.town_strategic_role(town),
		"garrison_strength": _army_strength(town.get("garrison", [])),
		"desired_garrison_strength": _desired_town_strength(session, town, config),
		"build": build_report,
		"recruitment": recruit_report,
		"events": events,
	}

static func town_build_pressure_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	treasury: Dictionary,
	faction_id: String
) -> Dictionary:
	var candidates := []
	for building_id in OverworldRulesScript.get_town_build_options(town, int(session.day) if session != null else -1):
		var status: Dictionary = OverworldRulesScript.get_town_build_status(town, String(building_id))
		if not bool(status.get("buildable", false)):
			continue
		var building: Dictionary = status.get("building", {})
		var cost: Dictionary = building.get("cost", {})
		var breakdown := _build_candidate_score_breakdown(session, town, building, cost, config, faction_id)
		var pacing_report := _enemy_town_development_pacing_report(session, town, String(building_id))
		breakdown["affordable"] = OverworldRulesScript.can_afford_cost_with_town_market(town, treasury, cost, int(session.day))
		breakdown["pacing_eligible"] = bool(pacing_report.get("pacing_eligible", true))
		breakdown["pacing_reason"] = String(pacing_report.get("pacing_reason", "on_pace"))
		breakdown["earliest_completion_day_if_built"] = int(pacing_report.get("earliest_completion_day_if_built", 0))
		breakdown["min_completion_day"] = int(pacing_report.get("min_completion_day", 0))
		breakdown["building_id"] = String(building_id)
		breakdown["building_label"] = String(building.get("name", building_id))
		breakdown["category"] = String(building.get("category", "support"))
		breakdown["cost"] = cost
		candidates.append(breakdown)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_affordable := bool(a.get("affordable", false))
		var b_affordable := bool(b.get("affordable", false))
		if a_affordable != b_affordable:
			return a_affordable
		var a_score := float(a.get("final_score", 0.0))
		var b_score := float(b.get("final_score", 0.0))
		if is_equal_approx(a_score, b_score):
			return String(a.get("building_id", "")) < String(b.get("building_id", ""))
		return a_score > b_score
	)
	var selected := {}
	for candidate in candidates:
		if bool(candidate.get("affordable", false)) and bool(candidate.get("pacing_eligible", true)):
			selected = candidate
			break
	return {
		"selected_build": selected,
		"candidate_count": candidates.size(),
		"candidates": candidates,
	}

static func town_recruitment_pressure_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	treasury: Dictionary,
	faction_id: String
) -> Dictionary:
	var candidates := []
	var recruit_ids := []
	var destination := _choose_recruit_destination_breakdown(session, config, town, faction_id)
	for unit_id_value in town.get("available_recruits", {}).keys():
		recruit_ids.append(String(unit_id_value))
	recruit_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_priority = _recruit_priority_for_destination(a, config, faction_id, destination)
		var b_priority = _recruit_priority_for_destination(b, config, faction_id, destination)
		if is_equal_approx(a_priority, b_priority):
			return a < b
		return a_priority > b_priority
	)
	for unit_id in recruit_ids:
		var available := int(town.get("available_recruits", {}).get(unit_id, 0))
		var cost := _enemy_recruit_cost(town, unit_id)
		var recruit_count: int = _max_affordable_from_pool_with_town_market(town, treasury, cost, int(session.day), available)
		candidates.append(
			{
				"unit_id": unit_id,
				"unit_label": String(ContentService.get_unit(unit_id).get("name", unit_id)),
				"available": available,
				"recruit_count": recruit_count,
				"cost": cost,
				"priority": _recruit_priority_for_destination(unit_id, config, faction_id, destination),
				"affordable": recruit_count > 0,
				"destination": destination,
			}
		)
	var selected := {}
	for candidate in candidates:
		if int(candidate.get("recruit_count", 0)) > 0:
			selected = candidate
			break
	var events := []
	if not selected.is_empty():
		var town_event := ai_town_recruit_event(session, config, town, selected)
		if not town_event.is_empty():
			events.append(town_event)
		var destination_event := ai_town_recruit_destination_event(session, config, town, selected)
		if not destination_event.is_empty():
			events.append(destination_event)
	return {
		"selected_recruitment": selected,
		"candidate_count": candidates.size(),
		"candidates": candidates,
		"events": events,
	}

static func ai_town_build_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	selected_build: Dictionary
) -> Dictionary:
	if selected_build.is_empty():
		return {}
	var building_id := String(selected_build.get("building_id", ""))
	if building_id == "":
		return {}
	return EnemyAdventureRulesScript.build_ai_event_record(
		session,
		config,
		"ai_town_built",
		_town_actor(town),
		{
			"target_kind": "town_building",
			"target_placement_id": building_id,
			"target_label": String(selected_build.get("building_label", building_id)),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": selected_build.get("reason_codes", []),
			"target_public_reason": String(selected_build.get("public_reason", "")),
			"target_public_importance": "medium",
			"target_debug_reason": String(selected_build.get("debug_reason", "")),
		},
		{
			"actor_label": _town_name(town),
			"summary": "%s builds %s (%s)." % [
				_town_name(town),
				String(selected_build.get("building_label", building_id)),
				String(selected_build.get("public_reason", "town pressure")),
			],
			"state_policy": "derived",
		}
	)

static func ai_town_recruit_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	selected_recruitment: Dictionary
) -> Dictionary:
	if selected_recruitment.is_empty():
		return {}
	var unit_id := String(selected_recruitment.get("unit_id", ""))
	if unit_id == "":
		return {}
	var destination: Dictionary = selected_recruitment.get("destination", {})
	var reason_codes: Array = _normalize_string_array(destination.get("reason_codes", []))
	if "town_recruitment" not in reason_codes:
		reason_codes.push_front("town_recruitment")
	return EnemyAdventureRulesScript.build_ai_event_record(
		session,
		config,
		"ai_town_recruited",
		_town_actor(town),
		{
			"target_kind": "unit",
			"target_placement_id": unit_id,
			"target_label": "%d %s" % [
				int(selected_recruitment.get("recruit_count", 0)),
				String(selected_recruitment.get("unit_label", unit_id)),
			],
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(destination.get("public_reason", "")),
			"target_public_importance": "medium",
			"target_debug_reason": String(destination.get("debug_reason", "")),
		},
		{
			"actor_label": _town_name(town),
			"summary": "%s recruits %d %s for %s." % [
				_town_name(town),
				int(selected_recruitment.get("recruit_count", 0)),
				String(selected_recruitment.get("unit_label", unit_id)),
				String(destination.get("public_reason", "front pressure")),
			],
			"state_policy": "derived",
		}
	)

static func ai_town_recruit_destination_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	selected_recruitment: Dictionary
) -> Dictionary:
	var destination: Dictionary = selected_recruitment.get("destination", {})
	if destination.is_empty():
		return {}
	var destination_type := String(destination.get("type", "garrison"))
	var event_type := "ai_garrison_reinforced"
	var target_kind := "town"
	var target_id := String(town.get("placement_id", ""))
	var target_label := _town_name(town)
	match destination_type:
		"raid":
			event_type = "ai_raid_reinforced"
			target_kind = "raid"
			target_id = String(destination.get("raid_placement_id", target_id))
			target_label = String(destination.get("raid_label", target_id))
		"rebuild":
			event_type = "ai_commander_rebuilt"
			target_kind = "commander"
			target_id = String(destination.get("roster_hero_id", ""))
			target_label = String(destination.get("commander_label", target_id))
		"planned":
			event_type = "ai_commander_prepared"
			target_kind = "commander"
			target_id = String(destination.get("roster_hero_id", ""))
			target_label = String(destination.get("commander_label", target_id))
		"emergency":
			event_type = "ai_emergency_defender_prepared"
			target_kind = "commander"
			target_id = String(destination.get("roster_hero_id", ""))
			target_label = String(destination.get("commander_label", target_id))
		_:
			pass
	if target_label == "":
		target_label = target_id
	return EnemyAdventureRulesScript.build_ai_event_record(
		session,
		config,
		event_type,
		_town_actor(town),
		{
			"target_kind": target_kind,
			"target_placement_id": target_id,
			"target_label": target_label,
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": destination.get("reason_codes", []),
			"target_public_reason": String(destination.get("public_reason", "")),
			"target_public_importance": "medium",
			"target_debug_reason": String(destination.get("debug_reason", "")),
		},
		{
			"actor_label": _town_name(town),
			"summary": "%s sends %d %s to %s (%s)." % [
				_town_name(town),
				int(selected_recruitment.get("recruit_count", 0)),
				String(selected_recruitment.get("unit_label", selected_recruitment.get("unit_id", "units"))),
				target_label,
				String(destination.get("public_reason", "front pressure")),
			],
			"state_policy": "derived",
		}
	)

static func _town_actor(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"name": _town_name(town),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
	}

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

static func _faction_front_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Dictionary:
	var retake_labels: Array = []
	var stabilizing_labels: Array = []
	var pressure_bonus := 0
	var threshold_reduction := 0
	var garrison_bonus := 0
	var build_bonus := 0
	var retake_count := 0
	var stabilizing_count := 0
	var top_front_priority := 0
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var front: Dictionary = OverworldRulesScript.town_front_state(session, town)
		if not bool(front.get("active", false)) or String(front.get("faction_id", "")) != faction_id:
			continue
		var compact_summary := String(front.get("compact_summary", _town_name(town)))
		top_front_priority = max(top_front_priority, int(front.get("priority_bonus", 0)))
		match String(front.get("mode", "")):
			"retake":
				retake_count += 1
				pressure_bonus += int(front.get("pressure_bonus", 0))
				threshold_reduction = max(threshold_reduction, int(front.get("threshold_reduction", 0)))
				if compact_summary != "" and compact_summary not in retake_labels:
					retake_labels.append(compact_summary)
			"stabilizing":
				stabilizing_count += 1
				garrison_bonus += int(front.get("garrison_bonus", 0))
				build_bonus += int(front.get("build_bonus", 0))
				if compact_summary != "" and compact_summary not in stabilizing_labels:
					stabilizing_labels.append(compact_summary)
	var parts := []
	if not retake_labels.is_empty():
		parts.append(
			"Retake fronts %s" % ", ".join(retake_labels.slice(0, min(2, retake_labels.size())))
		)
	if not stabilizing_labels.is_empty():
		parts.append(
			"Stabilizing %s" % ", ".join(stabilizing_labels.slice(0, min(2, stabilizing_labels.size())))
		)
	return {
		"retake_count": retake_count,
		"stabilizing_count": stabilizing_count,
		"pressure_bonus": clampi(pressure_bonus, 0, 4),
		"threshold_reduction": clampi(threshold_reduction, 0, 2),
		"garrison_bonus": clampi(garrison_bonus, 0, 180),
		"build_bonus": clampi(build_bonus, 0, 160),
		"top_front_priority": top_front_priority,
		"summary": " | ".join(parts),
	}

static func _run_empire_cycle(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	should_apply_weekly_growth: bool
) -> Dictionary:
	var faction_id = String(config.get("faction_id", ""))
	var towns = session.overworld.get("towns", [])
	var town_entries = _owned_town_entries(session, faction_id)
	var front_state := _faction_front_state(session, faction_id)
	var messages = []
	var events = []
	state["captured_artifact_ids"] = _normalize_string_array(state.get("captured_artifact_ids", []))
	if town_entries.is_empty():
		if active_raid_count(session, faction_id) > 0:
			var no_town_memory_result := EnemyAdventureRulesScript.refresh_enemy_known_world_memory(session, config, state)
			state = no_town_memory_result.get("state", state)
			var raid_result = EnemyAdventureRulesScript.advance_raids(session, config, faction_id, state)
			state = raid_result.get("state", state)
			state = _latest_enemy_state(session, faction_id, state)
			_append_event_records(events, raid_result.get("events", []))
			var raid_message = String(raid_result.get("message", ""))
			if raid_message != "":
				messages.append(raid_message)
			var defense_result = _queue_town_defense_battle(session, config, faction_id)
			_append_event_records(events, defense_result.get("events", []))
			var defense_message = String(defense_result.get("message", ""))
			if defense_message != "":
				messages.append(defense_message)
			if bool(defense_result.get("battle_started", false)):
				state = _latest_enemy_state(session, faction_id, state)
				state["posture"] = "raiding"
				return {"state": state, "messages": messages, "events": events}
			var intercept_result = _queue_hero_intercept_battle(session, config, faction_id)
			_append_event_records(events, intercept_result.get("events", []))
			var intercept_message = String(intercept_result.get("message", ""))
			if intercept_message != "":
				messages.append(intercept_message)
			if bool(intercept_result.get("battle_started", false)):
				state = _latest_enemy_state(session, faction_id, state)
				state["posture"] = "raiding"
				return {"state": state, "messages": messages, "events": events}
			state["posture"] = "raiding"
			return {"state": state, "messages": messages, "events": events}
		if int(state.get("pressure", 0)) > 0 and active_raid_count(session, faction_id) == 0:
			state["pressure"] = max(0, int(state.get("pressure", 0)) - 1)
		state["posture"] = "collapsed"
		return {"state": state, "messages": messages, "events": events}

	var treasury = _normalize_resource_pool(state.get("treasury", {}))
	var income_summary = _apply_empire_income(session, town_entries, treasury, state)
	if not income_summary.is_empty():
		state["treasury"] = treasury

	if should_apply_weekly_growth:
		var muster_message = _apply_weekly_musters(session, town_entries, towns, faction_id, config)
		if muster_message != "":
			messages.append(muster_message)
		session.overworld["towns"] = towns

	var memory_result := EnemyAdventureRulesScript.refresh_enemy_known_world_memory(session, config, state)
	state = memory_result.get("state", state)

	var pre_build_task_plan_result := EnemyAdventureRulesScript.plan_enemy_hero_task_board(session, config, state)
	state = pre_build_task_plan_result.get("state", state)
	_append_event_records(events, pre_build_task_plan_result.get("events", []))

	var build_result := _build_in_enemy_towns(session, town_entries, towns, treasury, faction_id, config)
	var build_messages: Array = build_result.get("messages", [])
	if not build_messages.is_empty():
		messages.append_array(build_messages)
	_append_event_records(events, build_result.get("events", []))
	session.overworld["towns"] = towns

	var study_result := _study_spells_in_enemy_towns(session, config, town_entries, towns, faction_id, state)
	state = study_result.get("state", state)
	var study_messages: Array = study_result.get("messages", [])
	if not study_messages.is_empty():
		messages.append_array(study_messages)
	_append_event_records(events, study_result.get("events", []))

	var reinforcement_result := _reinforce_enemy_forces(session, config, towns, treasury, faction_id)
	var reinforcement_message = String(reinforcement_result.get("message", ""))
	if reinforcement_message != "":
		messages.append(reinforcement_message)
	_append_event_records(events, reinforcement_result.get("events", []))
	session.overworld["towns"] = towns
	var refreshed_state := _find_state(session.overworld.get("enemy_states", []), faction_id)
	if not refreshed_state.is_empty():
		state["commander_roster"] = refreshed_state.get("commander_roster", state.get("commander_roster", []))

	var owned_towns = town_entries.size()
	var capital_state = _faction_capital_state_from_towns(session, towns, faction_id)
	var base_pressure_gain = max(
		0,
		int(config.get("pressure_per_day", 0))
		+ (owned_towns * int(config.get("pressure_per_enemy_town", 0)))
		+ _captured_artifact_pressure_bonus(state)
		+ _empire_town_pressure_bonus(session, faction_id, towns)
		+ _empire_strength_pressure_bonus(session, faction_id, towns)
		+ int(front_state.get("pressure_bonus", 0))
		+ _empire_capital_pressure_bonus(capital_state, session.day)
		+ OverworldRulesScript.controlled_resource_site_pressure_bonus(session, faction_id)
		- OverworldRulesScript.player_resource_site_pressure_guard(session)
	)
	var pressure_gain = DifficultyRulesScript.adjust_enemy_pressure_gain(session, base_pressure_gain)
	state["pressure"] = max(0, int(state.get("pressure", 0)) + pressure_gain)
	if pressure_gain > 0:
		var pressure_event := EnemyAdventureRulesScript.ai_pressure_summary_event(
			session,
			config,
			EnemyAdventureRulesScript.choose_target(session, config, _enemy_activity_origin(town_entries, config)),
			state
		)
		_append_event_records(events, [pressure_event])

	var raid_result = EnemyAdventureRulesScript.advance_raids(session, config, faction_id, state)
	state = raid_result.get("state", state)
	state = _latest_enemy_state(session, faction_id, state)
	_append_event_records(events, raid_result.get("events", []))
	treasury = _normalize_resource_pool(state.get("treasury", treasury))
	var raid_message = String(raid_result.get("message", ""))
	if raid_message != "":
		messages.append(raid_message)

	var task_plan_result := EnemyAdventureRulesScript.plan_enemy_hero_task_board(session, config, state)
	state = task_plan_result.get("state", state)
	_append_event_records(events, task_plan_result.get("events", []))

	var defense_result = _queue_town_defense_battle(session, config, faction_id)
	_append_event_records(events, defense_result.get("events", []))
	var defense_message = String(defense_result.get("message", ""))
	if defense_message != "":
		messages.append(defense_message)
	if bool(defense_result.get("battle_started", false)):
		state = _latest_enemy_state(session, faction_id, state)
		state["treasury"] = treasury
		state["posture"] = "raiding"
		return {"state": state, "messages": messages, "events": events}

	var intercept_result = _queue_hero_intercept_battle(session, config, faction_id)
	_append_event_records(events, intercept_result.get("events", []))
	var intercept_message = String(intercept_result.get("message", ""))
	if intercept_message != "":
		messages.append(intercept_message)
	if bool(intercept_result.get("battle_started", false)):
		state = _latest_enemy_state(session, faction_id, state)
		state["treasury"] = treasury
		state["posture"] = "raiding"
		return {"state": state, "messages": messages, "events": events}

	var launched_placement_ids := []
	while _can_launch_raid(session, config, state, faction_id):
		var spawn_result = _spawn_raid(session, config, state)
		if spawn_result.is_empty():
			break
		messages.append(String(spawn_result.get("message", "")))
		_append_event_records(events, spawn_result.get("events", []))
		var launched_id := String(spawn_result.get("placement_id", ""))
		if launched_id != "" and launched_id not in launched_placement_ids:
			launched_placement_ids.append(launched_id)
		if String(spawn_result.get("spawn_plan_source", "")).begins_with("emergency_"):
			break

	if not launched_placement_ids.is_empty():
		var launch_advance_result = EnemyAdventureRulesScript.advance_raids(
			session,
			config,
			faction_id,
			state,
			{"only_placement_ids": launched_placement_ids}
		)
		state = launch_advance_result.get("state", state)
		state = _latest_enemy_state(session, faction_id, state)
		_append_event_records(events, launch_advance_result.get("events", []))
		var launch_advance_message = String(launch_advance_result.get("message", ""))
		if launch_advance_message != "":
			messages.append(launch_advance_message)

		var launched_defense_result = _queue_town_defense_battle(session, config, faction_id)
		_append_event_records(events, launched_defense_result.get("events", []))
		var launched_defense_message = String(launched_defense_result.get("message", ""))
		if launched_defense_message != "":
			messages.append(launched_defense_message)
		if bool(launched_defense_result.get("battle_started", false)):
			state = _latest_enemy_state(session, faction_id, state)
			state["treasury"] = treasury
			state["posture"] = "raiding"
			return {"state": state, "messages": messages, "events": events}

		var launched_intercept_result = _queue_hero_intercept_battle(session, config, faction_id)
		_append_event_records(events, launched_intercept_result.get("events", []))
		var launched_intercept_message = String(launched_intercept_result.get("message", ""))
		if launched_intercept_message != "":
			messages.append(launched_intercept_message)
		if bool(launched_intercept_result.get("battle_started", false)):
			state = _latest_enemy_state(session, faction_id, state)
			state["treasury"] = treasury
			state["posture"] = "raiding"
			return {"state": state, "messages": messages, "events": events}

	var siege_message = _advance_siege(session, config, state, faction_id)
	if siege_message != "":
		messages.append(siege_message)

	state["treasury"] = treasury
	state["posture"] = _determine_posture(session, config, state, faction_id, towns)
	return {"state": state, "messages": messages, "events": events}

static func _latest_enemy_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	fallback: Dictionary
) -> Dictionary:
	if session == null or faction_id == "":
		return fallback
	var latest := _find_state(session.overworld.get("enemy_states", []), faction_id)
	return latest if not latest.is_empty() else fallback

static func _enemy_activity_origin(town_entries: Array, config: Dictionary) -> Dictionary:
	for entry_value in town_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var town: Dictionary = entry.get("town", {})
		if town.is_empty():
			continue
		return {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	var spawn_points = config.get("spawn_points", [])
	if spawn_points is Array and not spawn_points.is_empty() and spawn_points[0] is Dictionary:
		return {"x": int(spawn_points[0].get("x", 0)), "y": int(spawn_points[0].get("y", 0))}
	return {"x": 0, "y": 0}

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
		total_income = _merge_resource_pools(total_income, OverworldRulesScript.town_income(town, session))
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
) -> Dictionary:
	var messages = []
	var events = []
	for entry in town_entries:
		var town = towns[int(entry.get("index", -1))]
		if _town_controller_faction_id(town) != faction_id:
			continue
		if int(town.get("last_build_day", 0)) == int(session.day):
			continue
		var build_choice = _best_build_candidate(session, town, treasury, config, faction_id)
		if build_choice.is_empty():
			continue
		var building_id = String(build_choice.get("building_id", ""))
		if not _enemy_town_development_pacing_allows_build(session, town, building_id):
			continue
		var building = build_choice.get("building", {})
		var cost = build_choice.get("cost", {})
		OverworldRulesScript.apply_market_cost_coverage(town, treasury, cost, int(session.day))
		_spend_from_pool(treasury, cost)
		var built_buildings = town.get("built_buildings", [])
		if not (built_buildings is Array):
			built_buildings = []
		built_buildings.append(building_id)
		town["built_buildings"] = built_buildings
		town["last_build_day"] = int(session.day)
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
		var build_event := ai_town_build_event(session, config, town, build_choice)
		if not build_event.is_empty():
			events.append(build_event)
	return {"messages": messages, "events": events}

static func _study_spells_in_enemy_towns(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town_entries: Array,
	towns: Array,
	faction_id: String,
	state: Dictionary
) -> Dictionary:
	var messages := []
	var events := []
	var roster := EnemyAdventureRulesScript.normalize_commander_roster(
		session,
		faction_id,
		state.get("commander_roster", [])
	)
	if roster.is_empty():
		return {"state": state, "messages": messages, "events": events}

	var studied_commander_ids := []
	for entry_value in town_entries:
		if not (entry_value is Dictionary):
			continue
		var town_index := int(entry_value.get("index", -1))
		if town_index < 0 or town_index >= towns.size():
			continue
		var town_value = towns[town_index]
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if _town_controller_faction_id(town) != faction_id:
			continue
		var spell_ids := _enemy_town_accessible_spell_ids(town)
		if spell_ids.is_empty():
			continue
		var study_choice := _best_enemy_town_spell_study_choice(
			session,
			config,
			faction_id,
			town,
			state,
			roster,
			spell_ids,
			studied_commander_ids
		)
		if study_choice.is_empty():
			continue
		var roster_index := int(study_choice.get("roster_index", -1))
		if roster_index < 0 or roster_index >= roster.size():
			continue
		var roster_entry: Dictionary = roster[roster_index]
		var commander_state: Dictionary = roster_entry.get("commander_state", {}) if roster_entry.get("commander_state", {}) is Dictionary else {}
		var spell_id := String(study_choice.get("spell_id", ""))
		var learn_result: Dictionary = SpellRulesScript.learn_spell(commander_state, spell_id)
		if not bool(learn_result.get("ok", false)):
			continue
		var learned_commander: Dictionary = learn_result.get("hero", commander_state)
		var roster_hero_id := String(roster_entry.get("roster_hero_id", learned_commander.get("roster_hero_id", "")))
		roster_entry["commander_state"] = EnemyAdventureRulesScript.build_roster_commander_state(
			roster_hero_id,
			faction_id,
			learned_commander,
			roster_entry
		)
		roster_entry["target_memory"] = EnemyAdventureRulesScript.commander_target_memory(roster_entry.get("commander_state", {}))
		roster_entry["commander_role_state"] = EnemyAdventureRulesScript.commander_live_role_state(roster_entry.get("commander_state", {}))
		roster_entry["army_continuity"] = EnemyAdventureRulesScript.commander_army_continuity(roster_entry.get("commander_state", {}))
		roster[roster_index] = roster_entry
		if roster_hero_id != "":
			studied_commander_ids.append(roster_hero_id)
		var spell := ContentService.get_spell(spell_id)
		var spell_name := String(spell.get("name", spell_id))
		var commander_label := EnemyAdventureRulesScript.commander_display_name(roster_entry, false)
		if commander_label == "":
			commander_label = roster_hero_id
		messages.append("%s studies %s at %s." % [commander_label, spell_name, _town_name(town)])
		events.append(
			_enemy_town_spell_study_event(
				session,
				config,
				town,
				roster_entry,
				spell_id,
				spell_name,
				float(study_choice.get("score", 0.0))
			)
		)

	if studied_commander_ids.is_empty():
		return {"state": state, "messages": messages, "events": events}
	state["commander_roster"] = roster
	_write_enemy_state(session, faction_id, state)
	return {"state": state, "messages": messages, "events": events}

static func _best_enemy_town_spell_study_choice(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	town: Dictionary,
	state: Dictionary,
	roster: Array,
	spell_ids: Array,
	studied_commander_ids: Array
) -> Dictionary:
	var best := {}
	for roster_index in range(roster.size()):
		var roster_entry = roster[roster_index]
		if not (roster_entry is Dictionary):
			continue
		var roster_hero_id := String(roster_entry.get("roster_hero_id", ""))
		if roster_hero_id == "" or roster_hero_id in studied_commander_ids:
			continue
		if String(roster_entry.get("status", "available")) != "available":
			continue
		if not EnemyAdventureRulesScript.commander_can_deploy(roster_entry):
			continue
		var commander_state: Dictionary = roster_entry.get("commander_state", {}) if roster_entry.get("commander_state", {}) is Dictionary else {}
		var task := _enemy_commander_open_task(state, roster_hero_id)
		for spell_id_value in spell_ids:
			var spell_id := String(spell_id_value)
			if spell_id == "" or SpellRulesScript.knows_spell(commander_state, spell_id):
				continue
			var spell := ContentService.get_spell(spell_id)
			if spell.is_empty():
				continue
			var score := _enemy_spell_study_score(spell, commander_state, roster_entry, task, config, town)
			if best.is_empty() or score > float(best.get("score", 0.0)):
				best = {
					"roster_index": roster_index,
					"roster_hero_id": roster_hero_id,
					"spell_id": spell_id,
					"score": score,
				}
	return best

static func _enemy_spell_study_score(
	spell: Dictionary,
	commander_state: Dictionary,
	roster_entry: Dictionary,
	task: Dictionary,
	config: Dictionary,
	town: Dictionary
) -> float:
	var score := float(max(1, int(spell.get("tier", 1))) * 30)
	score += float(max(0, int(spell.get("mana_cost", 0)))) * 1.5
	var context := String(spell.get("context", ""))
	var primary_role := String(spell.get("primary_role", ""))
	var categories := _normalize_string_array(spell.get("role_categories", []))
	var effect: Dictionary = spell.get("effect", {}) if spell.get("effect", {}) is Dictionary else {}
	var effect_type := String(effect.get("type", ""))
	var command: Dictionary = commander_state.get("command", {}) if commander_state.get("command", {}) is Dictionary else {}
	var hero_template := ContentService.get_hero(String(roster_entry.get("roster_hero_id", commander_state.get("roster_hero_id", ""))))
	var command_path := String(commander_state.get("command_path", hero_template.get("command_path", "")))
	var archetype := String(commander_state.get("archetype", ""))
	var task_kind := String(task.get("target_kind", ""))
	if command_path == "magic":
		score += 28.0
		score += float(max(0, int(command.get("power", 0)))) * 3.0
		score += float(max(0, int(command.get("knowledge", 0)))) * 1.5
	else:
		score += 8.0
	if context == "overworld":
		if task_kind in ["resource", "artifact", "encounter", "town", "explore", "objective"]:
			score += 24.0
		if effect_type == "restore_movement" or primary_role.find("movement") >= 0:
			score += 22.0
		if effect_type.find("reveal") >= 0 or primary_role.find("scout") >= 0:
			score += 18.0
		if archetype in ["pathfinder", "outrider", "roadwarden", "warrenhunter", "relaysurveyor"]:
			score += 14.0
	else:
		if task_kind in ["hero", "town", "encounter", "resource", "artifact"]:
			score += 18.0
		if "damage" in categories or effect_type == "damage_enemy":
			score += 18.0
			if archetype in ["raider", "marshal", "packlord", "batterycaptain", "siegelock", "briarmarshal"]:
				score += 10.0
		if "control" in categories or "debuff" in categories:
			score += 12.0
			if archetype in ["hexcaller", "starseer", "rootoracle", "denaugur", "drumoracle"]:
				score += 10.0
		if "buff" in categories or "recovery" in categories or "countermagic" in categories:
			score += 12.0
			if archetype in ["warden", "castellan", "solarphysician", "recoverywarden", "granary"]:
				score += 10.0
	if String(spell.get("school_id", "")) == String(ContentService.get_town(String(town.get("town_id", ""))).get("spell_signature_school_id", "")):
		score += 6.0
	return score

static func _enemy_town_accessible_spell_ids(town: Dictionary) -> Array:
	if TownRulesScript == null:
		return []
	return TownRulesScript.accessible_spell_ids(town)

static func _enemy_commander_open_task(state: Dictionary, roster_hero_id: String) -> Dictionary:
	if state.is_empty() or roster_hero_id == "":
		return {}
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	for task_value in task_state.get("tasks", []):
		if task_value is Dictionary and String(task_value.get("actor_id", "")) == roster_hero_id:
			return task_value
	return {}

static func _write_enemy_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	state: Dictionary
) -> void:
	if session == null or faction_id == "":
		return
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	for state_index in range(states.size()):
		var entry = states[state_index]
		if entry is Dictionary and String(entry.get("faction_id", "")) == faction_id:
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return

static func _enemy_town_spell_study_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	roster_entry: Dictionary,
	spell_id: String,
	spell_name: String,
	score: float
) -> Dictionary:
	var roster_hero_id := String(roster_entry.get("roster_hero_id", ""))
	var commander_label := EnemyAdventureRulesScript.commander_display_name(roster_entry, false)
	if commander_label == "":
		commander_label = roster_hero_id
	return EnemyAdventureRulesScript.build_ai_event_record(
		session,
		config,
		"ai_commander_studied_spell",
		{
			"id": roster_hero_id,
			"name": commander_label,
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
		},
		{
			"target_kind": "spell",
			"target_placement_id": spell_id,
			"target_label": spell_name,
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
		},
		{
			"actor_id": roster_hero_id,
			"actor_label": commander_label,
			"target_kind": "spell",
			"target_id": spell_id,
			"target_label": spell_name,
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"reason_codes": ["town_spell_study", "magic_preparation"],
			"public_reason": "spell study",
			"public_importance": "medium",
			"state_policy": "persisted_commander_spellbook",
			"summary": "%s studies %s at %s." % [commander_label, spell_name, _town_name(town)],
			"debug_reason": "town_spell_study_score_%0.1f" % score,
			"learned_spell_id": spell_id,
			"learned_spell_name": spell_name,
		}
	)

static func _enemy_town_development_pacing_allows_build(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building_id: String
) -> bool:
	return bool(_enemy_town_development_pacing_report(session, town, building_id).get("pacing_eligible", true))

static func _enemy_town_development_pacing_report(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building_id: String
) -> Dictionary:
	if session == null or building_id == "":
		return {"pacing_eligible": true, "pacing_reason": "no_active_session"}
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	if town_template.is_empty() or profile.is_empty() or not bool(profile.get("one_build_per_turn", false)):
		return {"pacing_eligible": true, "pacing_reason": "no_development_pacing_profile"}
	var target_buildings := _normalize_string_array(town_template.get("buildable_building_ids", []))
	if target_buildings.is_empty() or building_id not in target_buildings:
		return {"pacing_eligible": true, "pacing_reason": "non_target_build"}
	var target_turns = max(1, int(profile.get("target_complete_turns", 30)))
	var min_completion_day = clamp(
		int(profile.get("min_completion_day", min(ENEMY_TOWN_DEVELOPMENT_MIN_COMPLETION_DAY, target_turns))),
		1,
		target_turns
	)
	var built_target_count := 0
	var built_buildings := _normalize_string_array(town.get("built_buildings", []))
	for target_id in target_buildings:
		if String(target_id) in built_buildings:
			built_target_count += 1
	var missing_before = max(0, target_buildings.size() - built_target_count)
	var remaining_after_build = max(0, missing_before - 1)
	var earliest_completion_day_if_built = int(session.day) + remaining_after_build
	var pacing_eligible = earliest_completion_day_if_built >= min_completion_day
	return {
		"pacing_eligible": pacing_eligible,
		"pacing_reason": "on_pace" if pacing_eligible else "ahead_of_development_floor",
		"min_completion_day": min_completion_day,
		"target_complete_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"built_target_count": built_target_count,
		"missing_target_count_before": missing_before,
		"remaining_target_count_after_build": remaining_after_build,
		"earliest_completion_day_if_built": earliest_completion_day_if_built,
	}

static func _reinforce_enemy_forces(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	towns: Array,
	treasury: Dictionary,
	faction_id: String
) -> Dictionary:
	var garrisoned_towns = []
	var raid_reinforcements = 0
	var rebuild_batches = 0
	var planned_batches = 0
	var emergency_batches = 0
	var events = []
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_controller_faction_id(town) != faction_id:
			continue
		var recruit_result = _recruit_town_forces(session, config, town, treasury, faction_id)
		town = recruit_result.get("town", town)
		towns[index] = town
		_append_event_records(events, recruit_result.get("events", []))
		if bool(recruit_result.get("garrisoned", false)):
			garrisoned_towns.append(_town_name(town))
		raid_reinforcements += int(recruit_result.get("raid_batches", 0))
		rebuild_batches += int(recruit_result.get("rebuild_batches", 0))
		planned_batches += int(recruit_result.get("planned_batches", 0))
		emergency_batches += int(recruit_result.get("emergency_batches", 0))
	if garrisoned_towns.is_empty() and raid_reinforcements <= 0:
		if rebuild_batches <= 0 and planned_batches <= 0 and emergency_batches <= 0:
			return {"message": "", "events": events}

	var parts = []
	if not garrisoned_towns.is_empty():
		parts.append("bolsters %s" % ", ".join(garrisoned_towns))
	if raid_reinforcements > 0:
		parts.append("feeds %d raid host%s" % [raid_reinforcements, "" if raid_reinforcements == 1 else "s"])
	if rebuild_batches > 0:
		parts.append("rebuilds %d command host%s" % [rebuild_batches, "" if rebuild_batches == 1 else "s"])
	if planned_batches > 0:
		parts.append("prepares %d planned command host%s" % [planned_batches, "" if planned_batches == 1 else "s"])
	if emergency_batches > 0:
		parts.append("prepares %d emergency defender%s" % [emergency_batches, "" if emergency_batches == 1 else "s"])
	return {
		"message": "%s %s." % [String(config.get("label", faction_id)), " and ".join(parts)],
		"events": events,
	}

static func _recruit_town_forces(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	treasury: Dictionary,
	faction_id: String
) -> Dictionary:
	var garrisoned = false
	var raid_batches = 0
	var rebuild_batches = 0
	var planned_batches = 0
	var emergency_batches = 0
	var events = []
	var recruit_ids = []
	var initial_destination_breakdown = _choose_recruit_destination_breakdown(session, config, town, faction_id)
	for unit_id_value in town.get("available_recruits", {}).keys():
		recruit_ids.append(String(unit_id_value))
	recruit_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_priority = _recruit_priority_for_destination(a, config, faction_id, initial_destination_breakdown)
		var b_priority = _recruit_priority_for_destination(b, config, faction_id, initial_destination_breakdown)
		if is_equal_approx(a_priority, b_priority):
			return a < b
		return a_priority > b_priority
	)

	for unit_id in recruit_ids:
		var available = int(town.get("available_recruits", {}).get(unit_id, 0))
		if available <= 0:
			continue
		var cost = _enemy_recruit_cost(town, unit_id)
		var recruit_count = _max_affordable_from_pool_with_town_market(town, treasury, cost, int(session.day), available)
		if recruit_count <= 0:
			continue
		var destination_breakdown = _choose_recruit_destination_breakdown(session, config, town, faction_id)
		var destination = _recruit_destination_from_breakdown(destination_breakdown)
		var applied_count = recruit_count
		if String(destination.get("type", "")) == "raid":
			applied_count = _apply_reinforcement_to_raid(
				session,
				int(destination.get("index", -1)),
				unit_id,
				recruit_count
			)
			if applied_count > 0:
				raid_batches += 1
		elif String(destination.get("type", "")) in ["rebuild", "planned", "emergency"]:
			applied_count = EnemyAdventureRulesScript.reinforce_commander_roster_army(
				session,
				faction_id,
				String(destination.get("roster_hero_id", "")),
				unit_id,
				recruit_count,
				String(destination.get("base_encounter_id", "")),
				int(destination.get("target_strength", 0))
			)
			if applied_count > 0:
				if String(destination.get("type", "")) == "planned":
					planned_batches += 1
				elif String(destination.get("type", "")) == "emergency":
					emergency_batches += 1
				else:
					rebuild_batches += 1
		else:
			town["garrison"] = _add_stack(town.get("garrison", []), unit_id, recruit_count)
			garrisoned = true
		if applied_count <= 0:
			continue
		town["available_recruits"] = _consume_recruits(town.get("available_recruits", {}), unit_id, applied_count)
		var final_cost := _scale_resource_pool(cost, applied_count)
		OverworldRulesScript.apply_market_cost_coverage(town, treasury, final_cost, int(session.day))
		_spend_from_pool(treasury, final_cost)
		var selected_recruitment := {
			"unit_id": unit_id,
			"unit_label": String(ContentService.get_unit(unit_id).get("name", unit_id)),
			"recruit_count": applied_count,
			"destination": destination_breakdown,
		}
		var town_event := ai_town_recruit_event(session, config, town, selected_recruitment)
		if not town_event.is_empty():
			events.append(town_event)
		var destination_event := ai_town_recruit_destination_event(session, config, town, selected_recruitment)
		if not destination_event.is_empty():
			events.append(destination_event)
	return {
		"town": town,
		"garrisoned": garrisoned,
		"raid_batches": raid_batches,
		"rebuild_batches": rebuild_batches,
		"planned_batches": planned_batches,
		"emergency_batches": emergency_batches,
		"events": events,
	}

static func _choose_recruit_destination(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	faction_id: String
) -> Dictionary:
	var breakdown := _choose_recruit_destination_breakdown(session, config, town, faction_id)
	return _recruit_destination_from_breakdown(breakdown)

static func _recruit_destination_from_breakdown(breakdown: Dictionary) -> Dictionary:
	match String(breakdown.get("type", "garrison")):
		"raid":
			return {"type": "raid", "index": int(breakdown.get("index", -1))}
		"rebuild":
			return {"type": "rebuild", "roster_hero_id": String(breakdown.get("roster_hero_id", ""))}
		"planned":
			return {
				"type": "planned",
				"roster_hero_id": String(breakdown.get("roster_hero_id", "")),
				"base_encounter_id": String(breakdown.get("base_encounter_id", "")),
				"target_strength": int(breakdown.get("target_strength", 0)),
			}
		"emergency":
			return {
				"type": "emergency",
				"roster_hero_id": String(breakdown.get("roster_hero_id", "")),
				"base_encounter_id": String(breakdown.get("base_encounter_id", "")),
				"target_strength": int(breakdown.get("target_strength", 0)),
			}
		_:
			return {"type": "garrison"}

static func _choose_recruit_destination_breakdown(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	faction_id: String
) -> Dictionary:
	var defense_target = _desired_town_strength(session, town, config)
	var current_defense = _army_strength(town.get("garrison", []))
	var local_front: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var best_rebuild = _best_commander_rebuild_target(session, config, faction_id)
	var best_raid = _best_raid_reinforcement_target(session, config, faction_id, town)
	var best_planned = _best_planned_task_recruitment_target(session, config, faction_id, town)
	var best_emergency = _best_emergency_defense_recruitment_target(session, config, faction_id, town)
	var faction_front_state := _faction_front_state(session, faction_id)
	var garrison_gap = max(0, defense_target - current_defense)
	var garrison_score = float(garrison_gap) * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0)
	garrison_score += float(int(local_front.get("garrison_bonus", 0)))
	var raid_score = float(int(best_raid.get("need", 0))) * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0)
	raid_score += float(int(faction_front_state.get("top_front_priority", 0))) * 0.35
	var rebuild_score = float(int(best_rebuild.get("need", 0))) * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0) * 0.85
	rebuild_score += float(int(faction_front_state.get("top_front_priority", 0))) * 0.18
	var planned_score = float(best_planned.get("score", 0.0))
	var emergency_score = float(best_emergency.get("score", 0.0))
	if current_defense < int(round(float(defense_target) * 0.72)):
		return _recruit_destination_report_payload(
			"garrison",
			"critical_garrison_gap",
			"stabilizes garrison",
			["garrison_safety"],
			"local defense is below the minimum wall target",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned
		)
	if not best_emergency.is_empty() and emergency_score > max(garrison_score * 0.9, max(raid_score * 0.8, rebuild_score * 0.75)):
		return _recruit_destination_report_payload(
			"emergency",
			"emergency_defense_preparation",
			"prepares emergency defense",
			["emergency_defense_preparation", "front_defense"],
			"an uncovered threatened front needs a launch-ready defender",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned,
			emergency_score,
			best_emergency
		)
	if (
		not best_rebuild.is_empty()
		and not EnemyAdventureRulesScript.has_available_raid_commander(
			session,
			faction_id,
			EnemyAdventureRulesScript.commander_roster_for_faction(session, faction_id)
		)
	):
		return _recruit_destination_report_payload(
			"rebuild",
			"commander_rebuild_required",
			"rebuilds command",
			["commander_rebuild"],
			"no available commander can launch until a host is rebuilt",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned
		)
	if (
		bool(local_front.get("active", false))
		and String(local_front.get("mode", "")) == "stabilizing"
		and current_defense < defense_target + int(round(float(int(local_front.get("garrison_bonus", 0))) / 2.0))
	):
		return _recruit_destination_report_payload(
			"garrison",
			"stabilizing_front",
			"stabilizes garrison",
			["garrison_safety", "objective_front"],
			"the town is stabilizing a live front",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned
		)
	if not best_rebuild.is_empty() and rebuild_score > max(garrison_score, raid_score):
		return _recruit_destination_report_payload(
			"rebuild",
			"commander_rebuild_pressure",
			"rebuilds command",
			["commander_rebuild"],
			"commander continuity has the strongest reinforcement need",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned
		)
	if not best_raid.is_empty() and raid_score > garrison_score:
		return _recruit_destination_report_payload(
			"raid",
			"active_raid_need",
			"feeds raid hosts",
			["raid_reinforcement"],
			"an active raid host has the stronger field need",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned
		)
	if not best_planned.is_empty() and planned_score > max(garrison_score * 0.9, rebuild_score * 0.8):
		return _recruit_destination_report_payload(
			"planned",
			"planned_task_preparation",
			"prepares command",
			["planned_task_preparation", "strategic_task_planner"],
			"a saved strategic task has a reachable commander host to prepare",
			garrison_score,
			raid_score,
			rebuild_score,
			defense_target,
			current_defense,
			best_raid,
			best_rebuild,
			local_front,
			planned_score,
			best_planned
		)
	return _recruit_destination_report_payload(
		"garrison",
		"default_garrison",
		"stabilizes garrison",
		["garrison_safety"],
		"no active raid or commander rebuild need beats local defense",
		garrison_score,
		raid_score,
		rebuild_score,
		defense_target,
		current_defense,
		best_raid,
		best_rebuild,
		local_front,
		planned_score,
		best_planned
	)

static func _recruit_destination_report_payload(
	destination_type: String,
	decision_rule: String,
	public_reason: String,
	reason_codes: Array,
	debug_reason: String,
	garrison_score: float,
	raid_score: float,
	rebuild_score: float,
	defense_target: int,
	current_defense: int,
	best_raid: Dictionary,
	best_rebuild: Dictionary,
	local_front: Dictionary,
	planned_score: float = 0.0,
	best_planned: Dictionary = {},
	emergency_score: float = 0.0,
	best_emergency: Dictionary = {}
) -> Dictionary:
	var payload := {
		"type": destination_type,
		"decision_rule": decision_rule,
		"public_reason": public_reason,
		"reason_codes": reason_codes,
		"debug_reason": debug_reason,
		"garrison_score": garrison_score,
		"raid_score": raid_score,
		"rebuild_score": rebuild_score,
		"planned_score": planned_score,
		"emergency_score": emergency_score,
		"defense_target": defense_target,
		"current_defense": current_defense,
		"garrison_gap": max(0, defense_target - current_defense),
		"local_front_mode": String(local_front.get("mode", "")) if bool(local_front.get("active", false)) else "",
	}
	if destination_type == "raid":
		var raid: Dictionary = best_raid.get("encounter", {})
		payload["index"] = int(best_raid.get("index", -1))
		payload["raid_placement_id"] = String(raid.get("placement_id", ""))
		payload["raid_label"] = EnemyAdventureRulesScript.raid_display_name(raid)
		payload["raid_need"] = int(best_raid.get("need", 0))
		payload["target_strength"] = int(best_raid.get("target_strength", 0))
		payload["threat_recovery"] = bool(best_raid.get("threat_recovery", false))
		payload["threat_hero_id"] = String(best_raid.get("threat_hero_id", ""))
		payload["threat_hero_strength"] = int(best_raid.get("threat_hero_strength", 0))
		payload["supply_distance"] = int(best_raid.get("supply_distance", 0))
		payload["target_id"] = String(raid.get("target_placement_id", ""))
		payload["target_label"] = String(raid.get("target_label", raid.get("target_placement_id", "")))
	elif destination_type == "rebuild":
		payload["roster_hero_id"] = String(best_rebuild.get("roster_hero_id", ""))
		payload["commander_label"] = String(ContentService.get_hero(String(best_rebuild.get("roster_hero_id", ""))).get("name", payload["roster_hero_id"]))
		payload["rebuild_need"] = int(best_rebuild.get("need", 0))
		payload["commander_status"] = String(best_rebuild.get("status", ""))
	elif destination_type == "planned":
		payload["roster_hero_id"] = String(best_planned.get("roster_hero_id", ""))
		payload["commander_label"] = String(ContentService.get_hero(String(best_planned.get("roster_hero_id", ""))).get("name", payload["roster_hero_id"]))
		payload["planned_need"] = int(best_planned.get("need", 0))
		payload["target_strength"] = int(best_planned.get("target_strength", 0))
		payload["base_encounter_id"] = String(best_planned.get("base_encounter_id", ""))
		payload["task_id"] = String(best_planned.get("task_id", ""))
		payload["commander_fit_bonus"] = int(best_planned.get("commander_fit_bonus", 0))
		payload["commander_fit_profile"] = String(best_planned.get("commander_fit_profile", ""))
		payload["target_kind"] = String(best_planned.get("target_kind", ""))
		payload["target_id"] = String(best_planned.get("target_id", ""))
		payload["target_label"] = String(best_planned.get("target_label", best_planned.get("target_id", "")))
		payload["goal_distance"] = int(best_planned.get("goal_distance", 0))
	elif destination_type == "emergency":
		payload["roster_hero_id"] = String(best_emergency.get("roster_hero_id", ""))
		payload["commander_label"] = String(ContentService.get_hero(String(best_emergency.get("roster_hero_id", ""))).get("name", payload["roster_hero_id"]))
		payload["emergency_need"] = int(best_emergency.get("need", 0))
		payload["target_strength"] = int(best_emergency.get("target_strength", 0))
		payload["base_encounter_id"] = String(best_emergency.get("base_encounter_id", ""))
		payload["target_kind"] = String(best_emergency.get("target_kind", ""))
		payload["target_id"] = String(best_emergency.get("target_id", ""))
		payload["target_label"] = String(best_emergency.get("target_label", best_emergency.get("target_id", "")))
		payload["goal_distance"] = int(best_emergency.get("goal_distance", 0))
		payload["spawn_plan_source"] = String(best_emergency.get("spawn_plan_source", ""))
	return payload

static func _best_emergency_defense_recruitment_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	support_town: Dictionary
) -> Dictionary:
	if session == null or faction_id == "" or support_town.is_empty():
		return {}
	var base_encounter_id := _primary_raid_encounter_id(config)
	if base_encounter_id == "":
		return {}
	var state := _find_state(session.overworld.get("enemy_states", []), faction_id)
	if state.is_empty():
		return {}
	var points := _open_spawn_points(session, config)
	if points.is_empty():
		return {}
	var occupied_commander_ids := EnemyAdventureRulesScript.occupied_raid_commander_ids(session, faction_id)
	var best := {}
	var best_score := -1.0
	for index in range(points.size()):
		var point = points[index]
		if not (point is Dictionary):
			continue
		var candidate := _emergency_defense_spawn_candidate_for_point(
			session,
			config,
			state,
			faction_id,
			point,
			occupied_commander_ids,
			index
		)
		if candidate.is_empty():
			continue
		var current_strength := int(candidate.get("spawn_plan_current_strength", 0))
		var target_strength := int(candidate.get("spawn_plan_target_strength", 0))
		var need: int = max(0, target_strength - current_strength)
		if need <= 0:
			continue
		var supply_distance: int = abs(int(support_town.get("x", 0)) - int(point.get("x", 0))) \
			+ abs(int(support_town.get("y", 0)) - int(point.get("y", 0)))
		var score := float(need) * 1.15
		score += float(int(candidate.get("spawn_plan_priority", 0))) * 0.65
		score += float(max(0, 18 - supply_distance) * 12)
		score -= float(supply_distance * 4)
		score -= float(max(0, int(candidate.get("spawn_plan_goal_distance", 0))) * 3)
		if String(candidate.get("spawn_plan_target_kind", "")) == "town":
			score += 45.0
		if score > best_score:
			best_score = score
			best = {
				"roster_hero_id": String(candidate.get("roster_hero_id", "")),
				"need": need,
				"score": score,
				"target_kind": String(candidate.get("spawn_plan_target_kind", "")),
				"target_id": String(candidate.get("spawn_plan_target_id", "")),
				"target_label": String(candidate.get("spawn_plan_target_label", candidate.get("spawn_plan_target_id", ""))),
				"goal_distance": int(candidate.get("spawn_plan_goal_distance", 0)),
				"base_encounter_id": base_encounter_id,
				"target_strength": target_strength,
				"current_strength": current_strength,
				"spawn_plan_source": String(candidate.get("spawn_plan_source", "")),
				"supply_distance": supply_distance,
			}
	return best

static func _best_planned_task_recruitment_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	support_town: Dictionary
) -> Dictionary:
	if session == null or faction_id == "" or support_town.is_empty():
		return {}
	var base_encounter_id := _primary_raid_encounter_id(config)
	if base_encounter_id == "":
		return {}
	var roster := EnemyAdventureRulesScript.normalize_commander_roster(
		session,
		faction_id,
		EnemyAdventureRulesScript.commander_roster_for_faction(session, faction_id)
	)
	var roster_by_id := {}
	for entry_value in roster:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var actor_id := String(entry.get("roster_hero_id", ""))
			if actor_id != "":
				roster_by_id[actor_id] = entry
	var base_strength := _enemy_encounter_base_strength(base_encounter_id)
	if base_strength <= 0:
		return {}
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var best := {}
	var best_score := -1.0
	for task_value in EnemyAdventureRulesScript._ai_hero_task_live_tasks_for_faction(session, faction_id):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("task_status", "")) not in ["planned", "reserved"]:
			continue
		if int(task.get("expires_day", 0)) > 0 and int(task.get("expires_day", 0)) < int(session.day):
			continue
		var actor_id := String(task.get("actor_id", ""))
		if actor_id == "" or not roster_by_id.has(actor_id):
			continue
		var entry: Dictionary = roster_by_id.get(actor_id, {})
		if String(entry.get("status", EnemyAdventureRulesScript.COMMANDER_STATUS_AVAILABLE)) != EnemyAdventureRulesScript.COMMANDER_STATUS_AVAILABLE:
			continue
		if not EnemyAdventureRulesScript.commander_can_deploy(entry):
			continue
		var saved_plan := EnemyAdventureRulesScript._ai_hero_task_spawn_saved_plan_for_actor(
			session,
			faction_id,
			actor_id,
			{"x": int(support_town.get("x", 0)), "y": int(support_town.get("y", 0))}
		)
		if saved_plan.is_empty():
			continue
		var target_kind := String(saved_plan.get("target_kind", task.get("target_kind", "")))
		var target_id := String(saved_plan.get("target_placement_id", task.get("target_id", "")))
		if target_kind == "" or target_id == "":
			continue
		var continuity := EnemyAdventureRulesScript.commander_army_continuity(entry)
		var current_strength := int(continuity.get("current_strength", base_strength))
		if continuity.is_empty() or int(continuity.get("base_strength", 0)) <= 0:
			current_strength = base_strength
		var target_strength: int = base_strength + _planned_task_prep_strength(base_strength, target_kind, String(task.get("task_class", "")))
		var need: int = max(0, target_strength - current_strength)
		if need <= 0:
			continue
		var site_family := EnemyAdventureRulesScript.target_site_family(session, target_kind, target_id)
		var objective_anchor := EnemyAdventureRulesScript.target_is_objective_anchor(session, target_kind, target_id)
		var score := float(need) * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0) * 0.65
		score += float(int(saved_plan.get("priority", task.get("priority", 0)))) * 0.35
		score += float(max(0, int(task.get("commander_fit_bonus", 0)))) * 0.65
		score += float(EnemyAdventureRulesScript.priority_target_bonus(config, target_id)) * 0.35
		score *= EnemyAdventureRulesScript.strategy_target_weight(config, faction_id, target_kind, target_id, site_family, objective_anchor)
		score -= float(max(0, int(saved_plan.get("goal_distance", 0))) * 5)
		if score > best_score:
			best_score = score
			best = {
				"roster_hero_id": actor_id,
				"need": need,
				"score": score,
				"task_id": String(task.get("task_id", saved_plan.get("hero_task_id", ""))),
				"target_kind": target_kind,
				"target_id": target_id,
				"target_label": String(saved_plan.get("target_label", task.get("target_label", target_id))),
				"goal_distance": int(saved_plan.get("goal_distance", 0)),
				"base_encounter_id": base_encounter_id,
				"target_strength": target_strength,
				"commander_fit_bonus": int(task.get("commander_fit_bonus", 0)),
				"commander_fit_profile": String(task.get("commander_fit_profile", "")),
			}
	return best

static func _planned_task_prep_strength(base_strength: int, target_kind: String, task_class: String) -> int:
	var floor_strength := 35
	match target_kind:
		"town", "hero":
			floor_strength = 70
		"artifact", "encounter":
			floor_strength = 55
		"resource":
			floor_strength = 40
	var class_bonus := 0
	if task_class in ["raid_town", "retake_site"]:
		class_bonus = 25
	elif task_class in ["contest_site", "defend_front"]:
		class_bonus = 15
	return max(floor_strength + class_bonus, int(round(float(max(1, base_strength)) * 0.22)))

static func _primary_raid_encounter_id(config: Dictionary) -> String:
	var ids: Array = config.get("raid_encounter_ids", []) if config.get("raid_encounter_ids", []) is Array else []
	for id_value in ids:
		var encounter_id := String(id_value)
		if encounter_id != "":
			return encounter_id
	return String(config.get("raid_encounter_id", ""))

static func _enemy_encounter_base_strength(encounter_id: String) -> int:
	if encounter_id == "":
		return 0
	var encounter := ContentService.get_encounter(encounter_id)
	if encounter.is_empty():
		return 0
	var army := ContentService.get_army_group(String(encounter.get("enemy_group_id", "")))
	return _army_strength(army.get("stacks", []) if army.get("stacks", []) is Array else [])

static func _best_raid_reinforcement_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	support_town: Dictionary = {}
) -> Dictionary:
	var best = {}
	var best_score = -1.0
	var best_distance = 9999
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for index in range(session.overworld.get("encounters", []).size()):
		var encounter = session.overworld.get("encounters", [])[index]
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		var current = EnemyAdventureRulesScript.raid_strength(encounter)
		var desired = _raid_reinforcement_target_strength(encounter, current)
		var need = desired - current
		if need <= 0:
			continue
		var supply_distance := 0
		if not support_town.is_empty():
			supply_distance = EnemyAdventureRulesScript.raid_reinforcement_route_distance(
				session,
				support_town,
				encounter,
				faction_id
			)
			if supply_distance >= 9999:
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
		if _raid_has_nearby_player_threat_recovery_need(encounter, current):
			score += float(int(encounter.get("player_threat_hero_strength", 0))) * 0.35
			score += 120.0
		if String(encounter.get("target_kind", "")) == "town":
			var target_town: Dictionary = _find_town_by_placement(
				session,
				String(encounter.get("target_placement_id", ""))
			).get("town", {})
			var front_state: Dictionary = OverworldRulesScript.town_front_state(session, target_town)
			if bool(front_state.get("active", false)) and String(front_state.get("faction_id", "")) == faction_id:
				score += float(int(front_state.get("priority_bonus", 0))) * 0.4
			if not support_town.is_empty() and String(target_town.get("placement_id", "")) == String(support_town.get("placement_id", "")):
				score += 120.0
		score += float(EnemyAdventureRulesScript.priority_target_bonus(config, String(encounter.get("target_placement_id", ""))))
		if not support_town.is_empty():
			score += float(max(0, 16 - supply_distance) * 18)
			score -= float(supply_distance * 10)
		if score > best_score or (is_equal_approx(score, best_score) and supply_distance < best_distance):
			best_score = score
			best_distance = supply_distance
			best = {
				"index": index,
				"encounter": encounter,
				"need": need,
				"target_strength": desired,
				"threat_recovery": _raid_has_nearby_player_threat_recovery_need(encounter, current),
				"threat_hero_id": String(encounter.get("player_threat_hero_id", "")),
				"threat_hero_strength": int(encounter.get("player_threat_hero_strength", 0)),
				"supply_distance": supply_distance,
				"score": score,
			}
	return best

static func _raid_reinforcement_target_strength(encounter: Dictionary, current_strength: int) -> int:
	var desired: int = EnemyAdventureRulesScript.desired_raid_strength(encounter)
	if _raid_has_nearby_player_threat_recovery_need(encounter, current_strength):
		var threat_strength: int = max(0, int(encounter.get("player_threat_hero_strength", 0)))
		desired = max(desired, int(ceili(float(threat_strength) * 0.92)))
	return desired

static func _raid_has_nearby_player_threat_recovery_need(encounter: Dictionary, current_strength: int) -> bool:
	if encounter.is_empty():
		return false
	var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
	if "player_threat_avoidance" not in reason_codes and String(encounter.get("player_threat_hero_id", "")) == "":
		return false
	var threat_strength: int = max(0, int(encounter.get("player_threat_hero_strength", 0)))
	return threat_strength > current_strength

static func _best_commander_rebuild_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	var best := {}
	var best_score := -1.0
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	for entry_value in EnemyAdventureRulesScript.normalize_commander_roster(
		session,
		faction_id,
		EnemyAdventureRulesScript.commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if String(entry_value.get("roster_hero_id", "")) == "":
			continue
		var commander_status := String(entry_value.get("status", EnemyAdventureRulesScript.COMMANDER_STATUS_AVAILABLE))
		if commander_status == EnemyAdventureRulesScript.COMMANDER_STATUS_ACTIVE:
			continue
		if commander_status == EnemyAdventureRulesScript.COMMANDER_STATUS_RECOVERING and int(entry_value.get("recovery_day", 0)) > int(session.day):
			continue
		var continuity := EnemyAdventureRulesScript.commander_army_continuity(entry_value)
		var need: int = max(0, int(continuity.get("rebuild_need", 0)))
		if need <= 0:
			continue
		var score := float(need)
		score *= EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0)
		score += float(max(0, int(entry_value.get("renown", 0))) * 24)
		score += float(max(0, int(EnemyAdventureRulesScript.commander_target_memory(entry_value).get("focus_pressure_count", 0))) * 12)
		score += float(max(0, int(EnemyAdventureRulesScript.commander_target_memory(entry_value).get("rivalry_count", 0))) * 10)
		if String(entry_value.get("status", "")) == EnemyAdventureRulesScript.COMMANDER_STATUS_RECOVERING:
			score += 30.0
		if score > best_score:
			best_score = score
			best = {
				"roster_hero_id": String(entry_value.get("roster_hero_id", "")),
				"status": commander_status,
				"need": need,
				"score": score,
			}
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
	var commander_state = encounter.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		encounter["enemy_commander_state"] = EnemyAdventureRulesScript.sync_commander_army_continuity(
			commander_state,
			army,
			String(encounter.get("encounter_id", encounter.get("id", "")))
		)
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
		_set_town_owner(session, target_placement_id, "enemy", faction_id, "siege breakthrough")
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
	var launch_ready_plan := _planned_task_launch_ready_report(session, config, state, faction_id)
	var emergency_defense_plan := _emergency_defense_launch_ready_report(session, config, state, faction_id)
	var raid_threshold = _raid_threshold_for_strategy(session, config, faction_id)
	if int(state.get("pressure", 0)) < raid_threshold and launch_ready_plan.is_empty() and emergency_defense_plan.is_empty():
		return false
	return not _best_open_spawn_point(session, config, state, faction_id).is_empty()

static func _emergency_defense_launch_ready_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or faction_id == "":
		return {}
	var points := _open_spawn_points(session, config)
	if points.is_empty():
		return {}
	var occupied_commander_ids: Dictionary = EnemyAdventureRulesScript.occupied_raid_commander_ids(session, faction_id)
	var best := {}
	for index in range(points.size()):
		var point = points[index]
		if not (point is Dictionary):
			continue
		var candidate := _emergency_defense_spawn_candidate_for_point(
			session,
			config,
			state,
			faction_id,
			point,
			occupied_commander_ids,
			index
		)
		if candidate.is_empty():
			continue
		if best.is_empty() or _spawn_point_candidate_beats(candidate, best):
			best = candidate
	return best

static func _planned_task_launch_ready_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or faction_id == "":
		return {}
	var points := _open_spawn_points(session, config)
	if points.is_empty():
		return {}
	var occupied_commander_ids: Dictionary = EnemyAdventureRulesScript.occupied_raid_commander_ids(session, faction_id)
	var best := {}
	for index in range(points.size()):
		var point = points[index]
		if not (point is Dictionary):
			continue
		var candidate := _ready_saved_task_spawn_candidate_for_point(
			session,
			config,
			state,
			faction_id,
			point,
			occupied_commander_ids,
			index
		)
		if candidate.is_empty():
			continue
		var report := _spawn_point_candidate_ready_launch_report(session, config, state, faction_id, candidate)
		if report.is_empty():
			continue
		if best.is_empty() or int(report.get("spawn_plan_score", 0)) > int(best.get("spawn_plan_score", 0)):
			best = report
	return best

static func _spawn_point_candidate_ready_launch_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	candidate: Dictionary
) -> Dictionary:
	var actor_id := String(candidate.get("roster_hero_id", ""))
	var target_kind := String(candidate.get("spawn_plan_target_kind", ""))
	var target_id := String(candidate.get("spawn_plan_target_id", ""))
	if actor_id == "" or target_kind == "" or target_id == "":
		return {}
	var task := _planned_task_for_ready_launch(session, faction_id, actor_id, target_kind, target_id)
	if task.is_empty():
		return {}
	var base_encounter_id := _primary_raid_encounter_id(config)
	var base_strength := _enemy_encounter_base_strength(base_encounter_id)
	if base_strength <= 0:
		return {}
	var target_strength := base_strength + _planned_task_prep_strength(
		base_strength,
		target_kind,
		String(task.get("task_class", ""))
	)
	var commander := _commander_roster_entry_for_launch(session, faction_id, actor_id, state)
	if commander.is_empty():
		return {}
	if String(commander.get("status", EnemyAdventureRulesScript.COMMANDER_STATUS_AVAILABLE)) != EnemyAdventureRulesScript.COMMANDER_STATUS_AVAILABLE:
		return {}
	if not EnemyAdventureRulesScript.commander_can_deploy(commander):
		return {}
	var continuity := EnemyAdventureRulesScript.commander_army_continuity(commander)
	if String(continuity.get("encounter_id", "")) != base_encounter_id:
		return {}
	if continuity.is_empty() or int(continuity.get("current_strength", 0)) < target_strength:
		return {}
	return {
		"actor_id": actor_id,
		"target_kind": target_kind,
		"target_id": target_id,
		"task_id": String(task.get("task_id", "")),
		"base_encounter_id": base_encounter_id,
		"current_strength": int(continuity.get("current_strength", 0)),
		"target_strength": target_strength,
		"spawn_x": int(candidate.get("x", 0)),
		"spawn_y": int(candidate.get("y", 0)),
		"spawn_plan_score": int(candidate.get("spawn_plan_score", 0)),
	}

static func _planned_task_for_ready_launch(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	actor_id: String,
	target_kind: String,
	target_id: String
) -> Dictionary:
	for task_value in EnemyAdventureRulesScript._ai_hero_task_live_tasks_for_faction(session, faction_id):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) not in ["planned", "reserved"]:
			continue
		if String(task.get("target_kind", "")) != target_kind or String(task.get("target_id", "")) != target_id:
			continue
		if int(task.get("expires_day", 0)) > 0 and int(task.get("expires_day", 0)) < int(session.day):
			continue
		if String(task.get("last_validation", "valid")) != "valid":
			continue
		return task
	return {}

static func _commander_roster_entry_for_launch(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	actor_id: String,
	state: Dictionary
) -> Dictionary:
	var roster := EnemyAdventureRulesScript.normalize_commander_roster(
		session,
		faction_id,
		state.get("commander_roster", EnemyAdventureRulesScript.commander_roster_for_faction(session, faction_id))
	)
	for entry_value in roster:
		if entry_value is Dictionary and String(entry_value.get("roster_hero_id", "")) == actor_id:
			return entry_value
	return {}

static func _spawn_raid(session: SessionStateStoreScript.SessionData, config: Dictionary, state: Dictionary) -> Dictionary:
	var faction_id := String(config.get("faction_id", ""))
	var spawn_point = _best_open_spawn_point(session, config, state, faction_id)
	if spawn_point.is_empty():
		return {}

	var encounter_pool = config.get("raid_encounter_ids", [])
	if not (encounter_pool is Array) or encounter_pool.is_empty():
		return {}

	var raid_counter = int(state.get("raid_counter", 0))
	var occupied_commander_ids: Dictionary = EnemyAdventureRulesScript.occupied_raid_commander_ids(session, faction_id)
	var roster_hero_id := String(spawn_point.get("roster_hero_id", ""))
	if roster_hero_id == "":
		roster_hero_id = EnemyAdventureRulesScript.select_raid_commander_roster_hero_id_for_spawn(
			session,
			faction_id,
			spawn_point,
			int(state.get("commander_counter", 0)),
			occupied_commander_ids,
			state.get("commander_roster", [])
		)
	if roster_hero_id == "":
		return {}
	var encounter_id := _spawn_raid_encounter_id_from_plan(spawn_point, encounter_pool, raid_counter)
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
	state["commander_roster"] = EnemyAdventureRulesScript.record_commander_deployment(
		session,
		faction_id,
		roster_hero_id,
		state.get("commander_roster", []),
		placement_id
	)
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
	if String(spawn_point.get("spawn_plan_target_kind", "")) != "" and String(spawn_point.get("spawn_plan_target_id", "")) != "":
		raid_seed["target_kind"] = String(spawn_point.get("spawn_plan_target_kind", ""))
		raid_seed["target_placement_id"] = String(spawn_point.get("spawn_plan_target_id", ""))
		raid_seed["target_label"] = String(spawn_point.get("spawn_plan_target_label", ""))
		raid_seed["target_x"] = int(spawn_point.get("spawn_plan_target_x", spawn_point.get("x", 0)))
		raid_seed["target_y"] = int(spawn_point.get("spawn_plan_target_y", spawn_point.get("y", 0)))
		raid_seed["goal_x"] = int(spawn_point.get("spawn_plan_goal_x", raid_seed["target_x"]))
		raid_seed["goal_y"] = int(spawn_point.get("spawn_plan_goal_y", raid_seed["target_y"]))
		raid_seed["target_reason_codes"] = spawn_point.get("spawn_plan_reason_codes", [])
		raid_seed["target_public_reason"] = String(spawn_point.get("spawn_plan_public_reason", ""))
		raid_seed["target_public_importance"] = String(spawn_point.get("spawn_plan_public_importance", "high"))
		raid_seed["target_debug_reason"] = String(spawn_point.get("spawn_plan_debug_reason", ""))
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
	raid = _promote_spawned_raid_public_threat(raid)
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var encounter_name: String = EnemyAdventureRulesScript.raid_display_name(raid)
	var target_suffix = ""
	if String(raid.get("target_label", "")) != "":
		target_suffix = " toward %s" % String(raid.get("target_label", ""))
	return {
		"ok": true,
		"placement_id": placement_id,
		"roster_hero_id": roster_hero_id,
		"spawn_plan_source": String(spawn_point.get("spawn_plan_source", "")),
		"message": "%s dispatches %s at %d,%d%s." % [
			String(config.get("label", config.get("faction_id", "Enemy"))),
			encounter_name,
			int(spawn_point.get("x", 0)),
			int(spawn_point.get("y", 0)),
			target_suffix,
		],
		"events": [EnemyAdventureRulesScript.ai_target_assignment_event(session, config, raid, {})],
	}

static func _promote_spawned_raid_public_threat(raid: Dictionary) -> Dictionary:
	if raid.is_empty() or String(raid.get("target_kind", "")) == "" or String(raid.get("target_placement_id", "")) == "":
		return raid
	var promoted := raid.duplicate(true)
	var importance := String(promoted.get("target_public_importance", ""))
	if importance not in ["critical", "high"]:
		promoted["target_public_importance"] = "high"
	if String(promoted.get("target_public_reason", "")) == "":
		promoted["target_public_reason"] = EnemyAdventureRulesScript._public_reason_from_codes(
			promoted.get("target_reason_codes", [])
		)
	return promoted

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
	var defender_owner := String(town.get("owner", "neutral"))
	var readiness_report := _town_assault_ready_report(session, encounter, town, config)
	if not bool(readiness_report.get("ready", false)):
		var previous_target := _raid_target_snapshot(encounter)
		encounter = EnemyAdventureRulesScript.redirect_town_assault_for_risk(
			session,
			config,
			encounter,
			faction_id,
			readiness_report
		)
		encounters[encounter_index] = encounter
		session.overworld["encounters"] = encounters
		var assignment_event := EnemyAdventureRulesScript.ai_target_assignment_event(session, config, encounter, previous_target)
		if assignment_event.is_empty():
			assignment_event = EnemyAdventureRulesScript.ai_target_assignment_event(session, config, encounter, {})
		var commander_name := EnemyAdventureRulesScript.raid_commander_name(encounter)
		return {
			"battle_started": false,
			"risk_gated": true,
			"readiness_report": readiness_report,
			"events": [assignment_event] if not assignment_event.is_empty() else [],
			"message": (
				"%s delays the assault on %s to gather strength." % [commander_name, _town_name(town)]
				if commander_name != ""
				else "%s delays the assault on %s to gather strength." % [String(config.get("label", faction_id)), _town_name(town)]
			),
		}
	encounter["battle_context"] = {
		"type": "town_defense",
		"town_placement_id": String(town.get("placement_id", "")),
		"defending_hero_id": "",
		"raid_encounter_key": OverworldRulesScript.encounter_key(encounter),
		"trigger_faction_id": faction_id,
		"defender_owner": defender_owner,
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

static func _town_assault_ready_report(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	town: Dictionary,
	config: Dictionary = {}
) -> Dictionary:
	var assault_strength := EnemyAdventureRulesScript.raid_strength(encounter)
	var desired_strength := EnemyAdventureRulesScript.desired_raid_strength(encounter)
	var garrison_strength := _army_strength(town.get("garrison", []))
	var readiness: int = OverworldRulesScript.town_battle_readiness(town, session)
	var desired_floor := int(round(float(desired_strength) * 0.68))
	var garrison_floor := int(round(float(garrison_strength) * 0.85))
	var readiness_floor: int = 60 + (readiness * 2)
	var base_required_strength: int = max(85, desired_floor, garrison_floor, readiness_floor)
	var risk_tolerance_scale := EnemyAdventureRulesScript.commander_risk_tolerance_scale(encounter, config, "town")
	var required_strength: int = EnemyAdventureRulesScript._scaled_required_strength(base_required_strength, risk_tolerance_scale)
	var ready := assault_strength >= required_strength
	return {
		"ready": ready,
		"assault_strength": assault_strength,
		"desired_strength": desired_strength,
		"garrison_strength": garrison_strength,
		"town_readiness": readiness,
		"base_required_strength": base_required_strength,
		"risk_tolerance_scale": risk_tolerance_scale,
		"required_strength": required_strength,
		"reason": "ready_for_town_assault" if ready else "assault_risk_regroup",
	}

static func _raid_target_snapshot(raid: Dictionary) -> Dictionary:
	return {
		"target_kind": String(raid.get("target_kind", "")),
		"target_placement_id": String(raid.get("target_placement_id", "")),
		"target_label": String(raid.get("target_label", "")),
		"target_x": int(raid.get("target_x", raid.get("goal_x", 0))),
		"target_y": int(raid.get("target_y", raid.get("goal_y", 0))),
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
	var encounters = session.overworld.get("encounters", [])
	var readiness_report := _hero_intercept_ready_report(session, encounter, hero, config)
	if not bool(readiness_report.get("ready", false)):
		var previous_target := _raid_target_snapshot(encounter)
		encounter = EnemyAdventureRulesScript.redirect_hero_intercept_for_risk(
			session,
			config,
			encounter,
			faction_id,
			readiness_report
		)
		encounters[encounter_index] = encounter
		session.overworld["encounters"] = encounters
		var assignment_event := EnemyAdventureRulesScript.ai_target_assignment_event(session, config, encounter, previous_target)
		if assignment_event.is_empty():
			assignment_event = EnemyAdventureRulesScript.ai_target_assignment_event(session, config, encounter, {})
		var commander_name := EnemyAdventureRulesScript.raid_commander_name(encounter)
		return {
			"battle_started": false,
			"risk_gated": true,
			"readiness_report": readiness_report,
			"events": [assignment_event] if not assignment_event.is_empty() else [],
			"message": (
				"%s shadows %s while gathering strength." % [commander_name, String(hero.get("name", "the hero"))]
				if commander_name != ""
				else "%s shadows %s while gathering strength." % [String(config.get("label", faction_id)), String(hero.get("name", "the hero"))]
			),
		}
	var switch_result: Dictionary = HeroCommandRulesScript.set_active_hero(session, hero_id)
	if not bool(switch_result.get("ok", false)):
		return {}
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

static func _hero_intercept_ready_report(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	hero: Dictionary,
	config: Dictionary = {}
) -> Dictionary:
	var hunter_strength := EnemyAdventureRulesScript.raid_strength(encounter)
	var desired_strength := EnemyAdventureRulesScript.desired_raid_strength(encounter)
	var hero_strength := _army_strength(hero.get("army", {}).get("stacks", []))
	var desired_floor := int(round(float(desired_strength) * 0.65))
	var hero_floor := int(round(float(hero_strength) * 0.85))
	var base_required_strength: int = max(75, desired_floor, hero_floor)
	var risk_tolerance_scale := EnemyAdventureRulesScript.commander_risk_tolerance_scale(encounter, config, "hero")
	var required_strength: int = EnemyAdventureRulesScript._scaled_required_strength(base_required_strength, risk_tolerance_scale)
	var ready := hunter_strength >= required_strength
	return {
		"ready": ready,
		"hunter_strength": hunter_strength,
		"desired_strength": desired_strength,
		"hero_strength": hero_strength,
		"base_required_strength": base_required_strength,
		"risk_tolerance_scale": risk_tolerance_scale,
		"required_strength": required_strength,
		"reason": "ready_for_hero_intercept" if ready else "hero_hunt_risk_regroup",
	}

static func _town_defense_candidate(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var best = {}
	var best_score := -1000000000.0
	var best_distance := 9999
	var best_strength := -1
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var encounters = session.overworld.get("encounters", [])
	var config := _enemy_config_for_faction(session, faction_id)
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
		if int(encounter.get("assault_delay_until_day", 0)) > int(session.day):
			continue
		var town_result = _find_town_by_placement(session, String(encounter.get("target_placement_id", "")))
		var town = town_result.get("town", {})
		var town_owner := String(town.get("owner", "neutral"))
		var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
		var neutral_expansion := town_owner == "neutral" and (
			"town_expansion" in reason_codes
			or "neutral_town_claim" in reason_codes
			or "neutral_town_siege" in reason_codes
		)
		if town.is_empty() or (town_owner != "player" and not neutral_expansion):
			continue
		var goal_distance = int(encounter.get("goal_distance", 9999))
		if goal_distance > 1 and not bool(encounter.get("arrived", false)):
			continue
		var strength = EnemyAdventureRulesScript.raid_strength(encounter)
		var readiness_report := _town_assault_ready_report(session, encounter, town, config)
		var score := _town_assault_candidate_score(
			session,
			config,
			faction_id,
			encounter,
			town,
			readiness_report,
			goal_distance,
			strength
		)
		if (
			score > best_score
			or (
				is_equal_approx(score, best_score)
				and (
					goal_distance < best_distance
					or (goal_distance == best_distance and strength > best_strength)
					or (
						goal_distance == best_distance
						and strength == best_strength
						and String(encounter.get("placement_id", "")) < String(best.get("encounter", {}).get("placement_id", ""))
					)
				)
			)
		):
			best_score = score
			best_distance = goal_distance
			best_strength = strength
			best = {
				"encounter_index": index,
				"encounter": encounter,
				"town": town,
				"readiness_report": readiness_report,
				"selection_score": score,
			}
	return best

static func _hero_intercept_candidate(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var best = {}
	var best_score := -1000000000.0
	var best_distance := 9999
	var best_strength := -1
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var encounters = session.overworld.get("encounters", [])
	var config := _enemy_config_for_faction(session, faction_id)
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
		if int(encounter.get("hero_intercept_delay_until_day", 0)) > int(session.day):
			continue
		var hero = _find_player_hero(session, String(encounter.get("target_placement_id", "")))
		if hero.is_empty() or _hero_is_sheltered_in_player_town(session, hero):
			continue
		if not _hero_current_tile_interceptable(encounter, hero):
			continue
		var goal_distance = int(encounter.get("goal_distance", 9999))
		if goal_distance > 1 and not bool(encounter.get("arrived", false)):
			continue
		var strength = EnemyAdventureRulesScript.raid_strength(encounter)
		var readiness_report := _hero_intercept_ready_report(session, encounter, hero, config)
		var score := _hero_intercept_candidate_score(
			session,
			config,
			faction_id,
			encounter,
			hero,
			readiness_report,
			goal_distance,
			strength
		)
		if (
			score > best_score
			or (
				is_equal_approx(score, best_score)
				and (
					goal_distance < best_distance
					or (goal_distance == best_distance and strength > best_strength)
					or (
						goal_distance == best_distance
						and strength == best_strength
						and String(encounter.get("placement_id", "")) < String(best.get("encounter", {}).get("placement_id", ""))
					)
				)
			)
		):
			best_score = score
			best_distance = goal_distance
			best_strength = strength
			best = {
				"encounter_index": index,
				"encounter": encounter,
				"hero": hero,
				"readiness_report": readiness_report,
				"selection_score": score,
			}
	return best

static func _hero_current_tile_interceptable(encounter: Dictionary, hero: Dictionary) -> bool:
	if encounter.is_empty() or hero.is_empty():
		return false
	var hero_position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
	if hero_position.is_empty():
		return false
	var raid_tile := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	var hero_tile := Vector2i(int(hero_position.get("x", 0)), int(hero_position.get("y", 0)))
	return abs(raid_tile.x - hero_tile.x) + abs(raid_tile.y - hero_tile.y) <= 1

static func _town_assault_candidate_score(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	encounter: Dictionary,
	town: Dictionary,
	readiness_report: Dictionary,
	goal_distance: int,
	strength: int
) -> float:
	var target_id := String(town.get("placement_id", ""))
	var objective_anchor := EnemyAdventureRulesScript.target_is_objective_anchor(session, "town", target_id)
	var town_priority := EnemyAdventureRulesScript.priority_target_bonus(config, target_id)
	town_priority += EnemyAdventureRulesScript._town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var readiness: int = int(readiness_report.get("town_readiness", OverworldRulesScript.town_battle_readiness(town, session)))
	var required: int = maxi(1, int(readiness_report.get("required_strength", 1)))
	var strength_margin: int = strength - required
	var score := 0.0
	if bool(readiness_report.get("ready", false)):
		score += 100000.0
	else:
		score -= 15000.0
	score += float(maxi(-80, strength_margin)) * 2.0
	score += float(strength) * 0.25
	score += float(town_priority) * 5.0
	score += float(readiness) * 6.0
	score += float(maxi(0, 12 - goal_distance)) * 20.0
	if bool(objective_anchor):
		score += 420.0
	if bool(front_state.get("active", false)) and String(front_state.get("faction_id", "")) == faction_id:
		score += float(int(front_state.get("priority_bonus", 0))) * 3.0
		if String(front_state.get("mode", "")) == "retake":
			score += 260.0
	var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
	if "town_siege" in reason_codes:
		score += 100.0
	if "objective_front" in reason_codes:
		score += 180.0
	return score

static func _hero_intercept_candidate_score(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	encounter: Dictionary,
	hero: Dictionary,
	readiness_report: Dictionary,
	goal_distance: int,
	strength: int
) -> float:
	var hero_id := String(hero.get("id", ""))
	var hero_strength: int = int(readiness_report.get("hero_strength", _army_strength(hero.get("army", {}).get("stacks", []))))
	var required: int = maxi(1, int(readiness_report.get("required_strength", 1)))
	var strength_margin: int = strength - required
	var score := 0.0
	if bool(readiness_report.get("ready", false)):
		score += 100000.0
	else:
		score -= 15000.0
	score += float(maxi(-80, strength_margin)) * 2.2
	score += float(strength) * 0.22
	score += float(maxi(0, 12 - goal_distance)) * 20.0
	score += float(maxi(0, 180 - hero_strength)) * 1.25
	if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
		score += 110.0
	if bool(hero.get("is_primary", false)):
		score += 150.0
	var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
	if "exposed_hero" in reason_codes:
		score += 180.0
	if "hero_hunt" in reason_codes:
		score += 80.0
	if hero_id != "":
		score += float(EnemyAdventureRulesScript.priority_target_bonus(config, hero_id))
		score *= EnemyAdventureRulesScript.strategy_target_weight(config, faction_id, "hero", hero_id)
	return score

static func _best_build_candidate(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	treasury: Dictionary,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	var best = {}
	var best_score = -1.0
	for building_id in OverworldRulesScript.get_town_build_options(town, int(session.day) if session != null else -1):
		var status: Dictionary = OverworldRulesScript.get_town_build_status(town, String(building_id))
		if not bool(status.get("buildable", false)):
			continue
		var building = status.get("building", {})
		var cost = building.get("cost", {})
		if not OverworldRulesScript.can_afford_cost_with_town_market(town, treasury, cost, int(session.day)):
			continue
		if not _enemy_town_development_pacing_allows_build(session, town, String(building_id)):
			continue
		var score = _score_build_candidate(session, town, building, cost, config, faction_id)
		if score > best_score:
			best_score = score
			var breakdown := _build_candidate_score_breakdown(session, town, building, cost, config, faction_id)
			best = {
				"building_id": String(building_id),
				"building": building,
				"building_label": String(building.get("name", building_id)),
				"category": String(building.get("category", "support")),
				"cost": cost,
				"reason_codes": breakdown.get("reason_codes", []),
				"public_reason": String(breakdown.get("public_reason", "")),
				"debug_reason": String(breakdown.get("debug_reason", "")),
			}
	return best

static func _score_build_candidate(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building: Dictionary,
	cost: Dictionary,
	config: Dictionary,
	faction_id: String
) -> float:
	return float(_build_candidate_score_breakdown(session, town, building, cost, config, faction_id).get("final_score", 0.0))

static func _build_candidate_score_breakdown(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building: Dictionary,
	cost: Dictionary,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var building_id = String(building.get("id", ""))
	var current_income: Dictionary = OverworldRulesScript.town_income(town, session)
	var current_quality: int = OverworldRulesScript.town_reinforcement_quality(town, session)
	var current_readiness: int = OverworldRulesScript.town_battle_readiness(town, session)
	var current_pressure: int = OverworldRulesScript.town_pressure_output(town, session)
	var current_recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var current_market: Dictionary = OverworldRulesScript.town_market_state(town)
	var town_front: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var projected_town = town.duplicate(true)
	var built_buildings = projected_town.get("built_buildings", [])
	if not (built_buildings is Array):
		built_buildings = []
	built_buildings.append(building_id)
	projected_town["built_buildings"] = built_buildings
	var projected_income: Dictionary = OverworldRulesScript.town_income(projected_town, session)
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

	var weighted_income_value: float = marginal_income * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "income", 1.0)
	var weighted_growth_value: float = growth_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "growth", 1.0)
	var weighted_quality_value: float = quality_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "quality", 1.0)
	var weighted_readiness_value: float = readiness_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "readiness", 1.0)
	var weighted_pressure_value: float = pressure_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "pressure", 1.0)
	var weighted_market_value: float = market_value * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_value_weights", "income", 1.0)
	var score: float = (
		weighted_income_value
		+ weighted_growth_value
		+ weighted_quality_value
		+ weighted_readiness_value
		+ weighted_pressure_value
		+ recovery_value
		+ weighted_market_value
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
	var weighted_category_bonus: float = category_bonus * EnemyAdventureRulesScript.strategy_scalar(strategy, "build_category_weights", category, 1.0)
	score += weighted_category_bonus
	var upgrade_bonus := 0.0
	if String(building.get("upgrade_from", "")) != "":
		upgrade_bonus = 90.0
		score += upgrade_bonus
	var garrison_need_bonus := 0.0
	if _desired_town_strength(session, town, config) > _army_strength(town.get("garrison", [])):
		if category in ["support", "dwelling"]:
			garrison_need_bonus = 120.0 * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0)
			score += garrison_need_bonus
	var raid_need_bonus := 0.0
	if active_raid_count(session, faction_id) < _max_active_raids_for_strategy(session, config, faction_id) and category == "dwelling":
		raid_need_bonus = 90.0 * EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "raid_bias", 1.0)
		score += raid_need_bonus
	var front_bonus := 0.0
	if bool(town_front.get("active", false)) and String(town_front.get("mode", "")) == "stabilizing":
		if category in ["support", "dwelling", "civic"]:
			front_bonus = 100.0 + float(int(town_front.get("build_bonus", 0)))
			score += front_bonus
		elif category == "economy":
			front_bonus = 35.0
			score += front_bonus
	var planned_task_build_bonus: float = _planned_task_build_preparation_bonus(
		session,
		config,
		faction_id,
		town,
		building,
		category,
		growth_value,
		quality_value,
		readiness_value
	)
	score += planned_task_build_bonus
	var project_bonus := 0.0
	var role_bonus := 0.0
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
		project_bonus = project_score
		score += project_bonus
	elif town_role == "capital" and category in ["support", "civic", "magic"]:
		role_bonus = 110.0
		score += role_bonus
	elif town_role == "stronghold" and category in ["support", "civic", "dwelling"]:
		role_bonus = 80.0
		score += role_bonus
	var efficiency_divisor = max(400.0, float(_resource_value(cost)))
	var final_score: float = score / (efficiency_divisor / 400.0)
	var reason_codes := _town_build_reason_codes(
		marginal_income,
		growth_value,
		quality_value,
		readiness_value,
		pressure_value,
		recovery_value,
		market_value,
		garrison_need_bonus,
		raid_need_bonus,
		planned_task_build_bonus,
		project_bonus,
		category
	)
	return {
		"income_value": marginal_income,
		"growth_value": growth_value,
		"quality_value": quality_value,
		"readiness_value": readiness_value,
		"pressure_value": pressure_value,
		"recovery_value": recovery_value,
		"market_value": market_value,
		"weighted_income_value": weighted_income_value,
		"weighted_growth_value": weighted_growth_value,
		"weighted_quality_value": weighted_quality_value,
		"weighted_readiness_value": weighted_readiness_value,
		"weighted_pressure_value": weighted_pressure_value,
		"weighted_market_value": weighted_market_value,
		"category_bonus": weighted_category_bonus,
		"upgrade_bonus": upgrade_bonus,
		"garrison_need_bonus": garrison_need_bonus,
		"raid_need_bonus": raid_need_bonus,
		"front_bonus": front_bonus,
		"planned_task_build_bonus": planned_task_build_bonus,
		"project_bonus": project_bonus,
		"role_bonus": role_bonus,
		"cost_value": _resource_value(cost),
		"efficiency_divisor": efficiency_divisor,
		"final_score": final_score,
		"reason_codes": reason_codes,
		"public_reason": _town_build_public_reason(reason_codes),
		"debug_reason": _town_build_debug_reason(reason_codes, category),
	}

static func _planned_task_build_preparation_bonus(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	town: Dictionary,
	building: Dictionary,
	category: String,
	growth_value: float,
	quality_value: float,
	readiness_value: float
) -> float:
	if session == null or faction_id == "" or town.is_empty() or building.is_empty():
		return 0.0
	var planned_target := _best_planned_task_recruitment_target(session, config, faction_id, town)
	if planned_target.is_empty() or int(planned_target.get("need", 0)) <= 0:
		return 0.0
	var target_kind := String(planned_target.get("target_kind", ""))
	var fit_profile := String(planned_target.get("commander_fit_profile", ""))
	var need: int = max(0, int(planned_target.get("need", 0)))
	var bonus: float = min(240.0, 80.0 + (float(need) * 0.45))
	match category:
		"dwelling":
			bonus += 110.0
			if growth_value > 0.0:
				bonus += min(160.0, growth_value * 0.25)
			if target_kind in ["town", "hero", "resource"]:
				bonus += 45.0
		"support":
			bonus += 70.0
			bonus += min(130.0, (quality_value * 0.75) + (readiness_value * 0.45))
		"magic":
			if "magic" in fit_profile or target_kind in ["artifact", "encounter"]:
				bonus += 95.0
			else:
				bonus += 35.0
		"civic":
			bonus += 35.0
		_:
			bonus += 18.0
	if int(planned_target.get("commander_fit_bonus", 0)) > 0:
		bonus += min(70.0, float(int(planned_target.get("commander_fit_bonus", 0))) * 0.55)
	return max(0.0, bonus)

static func _town_build_reason_codes(
	income_value: float,
	growth_value: float,
	quality_value: float,
	readiness_value: float,
	pressure_value: float,
	recovery_value: float,
	market_value: float,
	garrison_need_bonus: float,
	raid_need_bonus: float,
	planned_task_build_bonus: float,
	project_bonus: float,
	category: String
) -> Array:
	var codes := []
	if pressure_value > 0.0 or project_bonus > 0.0:
		codes.append("builds_pressure")
	if planned_task_build_bonus > 0.0:
		codes.append("prepares_commander_task")
	if growth_value > 0.0 or category == "dwelling":
		codes.append("unlocks_recruits")
	if raid_need_bonus > 0.0:
		codes.append("feeds_raid_hosts")
	if garrison_need_bonus > 0.0 or quality_value > 0.0 or readiness_value > 0.0:
		codes.append("stabilizes_garrison")
	if income_value > 0.0:
		codes.append("expands_income")
	if market_value > 0.0:
		codes.append("market_support")
	if recovery_value > 0.0:
		codes.append("recovery_support")
	if codes.is_empty():
		codes.append("town_development")
	return codes

static func _town_build_public_reason(reason_codes: Array) -> String:
	var codes := _normalize_string_array(reason_codes)
	if "prepares_commander_task" in codes:
		return "prepares command"
	if "feeds_raid_hosts" in codes:
		return "feeds raid hosts"
	if "builds_pressure" in codes:
		return "builds pressure"
	if "unlocks_recruits" in codes:
		return "unlocks recruits"
	if "stabilizes_garrison" in codes:
		return "stabilizes garrison"
	if "expands_income" in codes or "market_support" in codes:
		return "expands income"
	if "recovery_support" in codes:
		return "supports recovery"
	return "town development"

static func _town_build_debug_reason(reason_codes: Array, category: String) -> String:
	var public_reason := _town_build_public_reason(reason_codes)
	if category != "":
		return "%s through %s build" % [public_reason, category]
	return public_reason

static func _determine_posture(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	towns: Array
) -> String:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var front_state := _faction_front_state(session, faction_id)
	var threatened_towns = 0
	for town in towns:
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_controller_faction_id(town) != faction_id:
			continue
		if _army_strength(town.get("garrison", [])) < _desired_town_strength(session, town, config):
			threatened_towns += 1
	if (
		threatened_towns > 0
		or int(front_state.get("stabilizing_count", 0)) > 0
	) and EnemyAdventureRulesScript.strategy_scalar(strategy, "reinforcement", "garrison_bias", 1.0) >= 1.0:
		return "fortifying"
	if active_raid_count(session, faction_id) > 0:
		return "raiding"
	var threshold = _raid_threshold_for_strategy(session, config, faction_id)
	if int(front_state.get("retake_count", 0)) > 0:
		return "massing"
	if (
		int(state.get("pressure", 0)) >= threshold
		and not EnemyAdventureRulesScript.has_available_raid_commander(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		and (
			EnemyAdventureRulesScript.recovering_commander_count(
				session,
				faction_id,
				state.get("commander_roster", [])
			) > 0
			or EnemyAdventureRulesScript.rebuilding_commander_count(
				session,
				faction_id,
				state.get("commander_roster", [])
			) > 0
		)
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
				"faction_thornwake":
					return "Graftwardens are regrowing lanes after the last clash"
				"faction_brasshollow":
					return "Foundry officers are cooling engines before the next contract push"
				"faction_veilmourn":
					return "Black-sail crews are vanishing into fog to reset their routes"
			return "Hostile commanders are regrouping before the next push"
		"fortifying":
			match faction_id:
				"faction_embercourt":
					return "Beacon towns are drawing disciplined levies onto the walls"
				"faction_mireclaw":
					return "Stockades are beating the drums for a local stand"
				"faction_sunvault":
					return "Relay keeps are locking into prepared firing lines"
				"faction_thornwake":
					return "Root towns are thickening bramble roads around the walls"
				"faction_brasshollow":
					return "Foundries are plating the wall engines for a hard stand"
				"faction_veilmourn":
					return "Bell harbors are masking their docks behind fresh fog"
			return "Border towns are pulling fresh troops onto the walls"
		"raiding":
			match faction_id:
				"faction_embercourt":
					return "Charter columns are pushing measured raids down the lanes"
				"faction_mireclaw":
					return "Warbands are spilling forward in staggered packs"
				"faction_sunvault":
					return "Compact sorties are testing the frontier behind relay screens"
				"faction_thornwake":
					return "Root pilgrims are spreading bramble tolls onto the frontier"
				"faction_brasshollow":
					return "Contract columns are rolling engines toward production sites"
				"faction_veilmourn":
					return "Black-sail raiders are slipping through fog lanes toward weak backs"
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
					"faction_thornwake":
						return "A rooted nursery front is spreading behind the roads"
					"faction_brasshollow":
						return "A heavy foundry assault is staging behind the railhead"
					"faction_veilmourn":
						return "A deeper fog wake is gathering beyond the charted routes"
				return "A heavier strike is gathering behind the lines"
			match faction_id:
				"faction_embercourt":
					return "Quartermasters are assembling another road-bound column"
				"faction_mireclaw":
					return "Fresh cutters are massing for another sudden push"
				"faction_sunvault":
					return "Arrays are lining up for another focused push"
				"faction_thornwake":
					return "Graft hosts are massing around newly rooted roads"
				"faction_brasshollow":
					return "Boiler crews are massing for another siege-stage push"
				"faction_veilmourn":
					return "Mist crews are massing around a hidden approach"
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
				"faction_thornwake":
					return "Scouts report root pilgrims seeding the approaches"
				"faction_brasshollow":
					return "Scouts report ore contracts and pressure gauges moving forward"
				"faction_veilmourn":
					return "Scouts report bell wakes sounding from unseen routes"
			return "Scouts report patrols probing for openings"

static func _first_open_spawn_point(session: SessionStateStoreScript.SessionData, config: Dictionary) -> Dictionary:
	var points := _open_spawn_points(session, config)
	if points.is_empty():
		return {}
	return points[0]

static func _best_open_spawn_point(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary = {},
	faction_id: String = ""
) -> Dictionary:
	var points := _open_spawn_points(session, config)
	if points.is_empty():
		return {}
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", state.get("faction_id", "")))
	var occupied_commander_ids: Dictionary = EnemyAdventureRulesScript.occupied_raid_commander_ids(session, resolved_faction_id)
	var best := {}
	for index in range(points.size()):
		var point = points[index]
		if not (point is Dictionary):
			continue
		var candidate := _spawn_point_candidate(
			session,
			config,
			state,
			resolved_faction_id,
			point,
			occupied_commander_ids,
			index
		)
		if candidate.is_empty():
			continue
		if best.is_empty() or _spawn_point_candidate_beats(candidate, best):
			best = candidate
	return best

static func _spawn_point_candidate(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	point: Dictionary,
	occupied_commander_ids: Dictionary,
	spawn_order: int
) -> Dictionary:
	if faction_id == "" or point.is_empty():
		return {}
	var emergency_defense_candidate := _emergency_defense_spawn_candidate_for_point(
		session,
		config,
		state,
		faction_id,
		point,
		occupied_commander_ids,
		spawn_order
	)
	if not emergency_defense_candidate.is_empty():
		return emergency_defense_candidate
	var ready_saved_candidate := _ready_saved_task_spawn_candidate_for_point(
		session,
		config,
		state,
		faction_id,
		point,
		occupied_commander_ids,
		spawn_order
	)
	if not ready_saved_candidate.is_empty():
		return ready_saved_candidate
	var saved_candidate := _saved_task_spawn_candidate_for_point(
		session,
		config,
		state,
		faction_id,
		point,
		occupied_commander_ids,
		spawn_order
	)
	if not saved_candidate.is_empty():
		return saved_candidate
	var fresh_candidate := _fresh_spawn_target_candidate_for_point(
		session,
		config,
		state,
		faction_id,
		point,
		occupied_commander_ids,
		spawn_order
	)
	return fresh_candidate

static func _saved_task_spawn_candidate_for_point(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	point: Dictionary,
	occupied_commander_ids: Dictionary,
	spawn_order: int
) -> Dictionary:
	var best := {}
	var candidates := EnemyAdventureRulesScript._raid_commander_spawn_candidates(
		session,
		faction_id,
		int(state.get("commander_counter", 0)),
		occupied_commander_ids,
		state.get("commander_roster", [])
	)
	for commander_value in candidates:
		if not (commander_value is Dictionary):
			continue
		var roster_hero_id := String(commander_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		var plan := EnemyAdventureRulesScript._ai_hero_task_spawn_saved_plan_for_actor(
			session,
			faction_id,
			roster_hero_id,
			point
		)
		if plan.is_empty():
			continue
		var candidate := _spawn_point_candidate_from_plan(
			point,
			plan,
			roster_hero_id,
			"saved_task",
			spawn_order + int(commander_value.get("rotation_order", 0))
		)
		candidate = _apply_spawn_plan_adventure_spell_projection(session, config, state, faction_id, candidate)
		if best.is_empty() or _spawn_point_candidate_beats(candidate, best):
			best = candidate
	return best

static func _fresh_spawn_target_candidate_for_point(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	point: Dictionary,
	occupied_commander_ids: Dictionary,
	spawn_order: int
) -> Dictionary:
	if session == null or faction_id == "" or point.is_empty():
		return {}
	var target_candidates: Array = EnemyAdventureRulesScript._target_candidates(
		session,
		config,
		Vector2i(int(point.get("x", 0)), int(point.get("y", 0)))
	)
	if target_candidates.is_empty():
		return _exploration_spawn_candidate_for_point(
			session,
			config,
			state,
			faction_id,
			point,
			occupied_commander_ids,
			spawn_order
		)
	var commander_candidates := EnemyAdventureRulesScript._raid_commander_spawn_candidates(
		session,
		faction_id,
		int(state.get("commander_counter", 0)),
		occupied_commander_ids,
		state.get("commander_roster", [])
	)
	var best := {}
	for commander_value in commander_candidates:
		if not (commander_value is Dictionary):
			continue
		var roster_hero_id := String(commander_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		var fitted_targets := EnemyAdventureRulesScript._ai_hero_task_planner_candidates_for_commander(
			session,
			faction_id,
			roster_hero_id,
			target_candidates
		)
		if fitted_targets.is_empty() or not (fitted_targets[0] is Dictionary):
			continue
		var candidate := _spawn_point_candidate_from_plan(
			point,
			fitted_targets[0],
			roster_hero_id,
			"fresh_target",
			spawn_order + int(commander_value.get("rotation_order", 0))
		)
		candidate["spawn_plan_commander_fit_bonus"] = int(fitted_targets[0].get("commander_fit_bonus", 0))
		candidate["spawn_plan_commander_fit_profile"] = String(fitted_targets[0].get("commander_fit_profile", ""))
		candidate = _apply_spawn_plan_adventure_spell_projection(session, config, state, faction_id, candidate)
		if best.is_empty() or _spawn_point_candidate_beats(candidate, best):
			best = candidate
	return best

static func _exploration_spawn_candidate_for_point(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	point: Dictionary,
	occupied_commander_ids: Dictionary,
	spawn_order: int
) -> Dictionary:
	if session == null or faction_id == "" or point.is_empty():
		return {}
	var plan := EnemyAdventureRulesScript._no_known_target_exploration_plan(
		session,
		config,
		Vector2i(int(point.get("x", 0)), int(point.get("y", 0)))
	)
	if plan.is_empty():
		return {}
	var commander_candidates := EnemyAdventureRulesScript._raid_commander_spawn_candidates(
		session,
		faction_id,
		int(state.get("commander_counter", 0)),
		occupied_commander_ids,
		state.get("commander_roster", [])
	)
	if commander_candidates.is_empty():
		return {}
	var best := {}
	for commander_value in commander_candidates:
		if not (commander_value is Dictionary):
			continue
		var roster_hero_id := String(commander_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		var candidate := _spawn_point_candidate_from_plan(
			point,
			plan,
			roster_hero_id,
			"exploration",
			spawn_order + int(commander_value.get("rotation_order", 0))
		)
		candidate["spawn_plan_score"] = int(candidate.get("spawn_plan_score", 0)) + _exploration_commander_spawn_bonus(session, faction_id, roster_hero_id)
		candidate["spawn_plan_public_importance"] = "medium"
		candidate = _apply_spawn_plan_adventure_spell_projection(session, config, state, faction_id, candidate)
		if best.is_empty() or _spawn_point_candidate_beats(candidate, best):
			best = candidate
	return best

static func _exploration_commander_spawn_bonus(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String
) -> int:
	if session == null or faction_id == "" or roster_hero_id == "":
		return 0
	var entry := EnemyAdventureRulesScript._commander_roster_entry(
		EnemyAdventureRulesScript.commander_roster_for_faction(session, faction_id),
		roster_hero_id
	)
	var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
	var hero_template := ContentService.get_hero(roster_hero_id)
	var bonus := 0
	var focus_ids := _normalize_string_array(
		commander_state.get("specialty_focus_ids", hero_template.get("specialty_focus_ids", []))
	)
	if "wayfinder" in focus_ids:
		bonus += 45
	if "spellwright" in focus_ids:
		bonus += 20
	if String(commander_state.get("archetype", hero_template.get("archetype", ""))) in ["scout", "raider", "pathfinder"]:
		bonus += 25
	return bonus

static func _ready_saved_task_spawn_candidate_for_point(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	point: Dictionary,
	occupied_commander_ids: Dictionary,
	spawn_order: int
) -> Dictionary:
	var best := {}
	var candidates := EnemyAdventureRulesScript._raid_commander_spawn_candidates(
		session,
		faction_id,
		int(state.get("commander_counter", 0)),
		occupied_commander_ids,
		state.get("commander_roster", [])
	)
	for commander_value in candidates:
		if not (commander_value is Dictionary):
			continue
		var roster_hero_id := String(commander_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		var plan := EnemyAdventureRulesScript._ai_hero_task_spawn_saved_plan_for_actor(
			session,
			faction_id,
			roster_hero_id,
			point
		)
		if plan.is_empty():
			continue
		var candidate := _spawn_point_candidate_from_plan(
			point,
			plan,
			roster_hero_id,
			"saved_task",
			spawn_order
		)
		candidate = _apply_spawn_plan_adventure_spell_projection(session, config, state, faction_id, candidate)
		var ready_report := _spawn_point_candidate_ready_launch_report(session, config, state, faction_id, candidate)
		if ready_report.is_empty():
			continue
		candidate["spawn_plan_ready_launch"] = true
		candidate["spawn_plan_encounter_id"] = String(ready_report.get("base_encounter_id", ""))
		candidate["spawn_plan_current_strength"] = int(ready_report.get("current_strength", 0))
		candidate["spawn_plan_target_strength"] = int(ready_report.get("target_strength", 0))
		candidate["spawn_plan_score"] = int(candidate.get("spawn_plan_score", 0)) + 200000
		if best.is_empty() or _spawn_point_candidate_beats(candidate, best):
			best = candidate
	return best

static func _spawn_point_candidate_from_plan(
	point: Dictionary,
	plan: Dictionary,
	roster_hero_id: String,
	plan_source: String,
	spawn_order: int
) -> Dictionary:
	var priority := int(plan.get("priority", plan.get("final_priority", 0)))
	var goal_distance := int(plan.get("goal_distance", 9999))
	if goal_distance >= 9999 and plan.has("target_x") and plan.has("target_y"):
		goal_distance = abs(int(point.get("x", 0)) - int(plan.get("target_x", 0))) \
			+ abs(int(point.get("y", 0)) - int(plan.get("target_y", 0)))
	var score: int = (priority * 100) - (mini(goal_distance, 9999) * 5) - spawn_order
	if plan_source == "saved_task":
		score += 100000
	var candidate := point.duplicate(true)
	candidate["roster_hero_id"] = roster_hero_id
	candidate["spawn_plan_source"] = plan_source
	candidate["spawn_plan_target_kind"] = String(plan.get("target_kind", ""))
	candidate["spawn_plan_target_id"] = String(plan.get("target_placement_id", ""))
	candidate["spawn_plan_target_label"] = String(plan.get("target_label", plan.get("target_placement_id", "")))
	candidate["spawn_plan_target_x"] = int(plan.get("target_x", point.get("x", 0)))
	candidate["spawn_plan_target_y"] = int(plan.get("target_y", point.get("y", 0)))
	candidate["spawn_plan_goal_x"] = int(plan.get("goal_x", plan.get("target_x", point.get("x", 0))))
	candidate["spawn_plan_goal_y"] = int(plan.get("goal_y", plan.get("target_y", point.get("y", 0))))
	candidate["spawn_plan_priority"] = priority
	candidate["spawn_plan_goal_distance"] = goal_distance
	candidate["spawn_plan_score"] = score
	candidate["spawn_order"] = spawn_order
	candidate["spawn_plan_reason_codes"] = plan.get("target_reason_codes", [])
	candidate["spawn_plan_public_reason"] = String(plan.get("target_public_reason", ""))
	candidate["spawn_plan_public_importance"] = String(plan.get("target_public_importance", "high"))
	candidate["spawn_plan_debug_reason"] = String(plan.get("target_debug_reason", ""))
	return candidate

static func _emergency_defense_spawn_candidate_for_point(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	point: Dictionary,
	occupied_commander_ids: Dictionary,
	spawn_order: int
) -> Dictionary:
	if session == null or faction_id == "" or point.is_empty():
		return {}
	var base_encounter_id := _primary_raid_encounter_id(config)
	if base_encounter_id == "":
		return {}
	var roster: Variant = state.get("commander_roster", [])
	var candidates: Array = EnemyAdventureRulesScript._raid_commander_spawn_candidates(
		session,
		faction_id,
		int(state.get("commander_counter", 0)),
		occupied_commander_ids,
		roster
	)
	var best_town := {}
	var best_resource := {}
	for commander_value in candidates:
		if not (commander_value is Dictionary):
			continue
		var roster_hero_id := String(commander_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		var probe := {
			"placement_id": "__emergency_defense_probe:%s:%d" % [roster_hero_id, spawn_order],
			"encounter_id": base_encounter_id,
			"x": int(point.get("x", 0)),
			"y": int(point.get("y", 0)),
			"difficulty": "pressure",
			"spawned_by_faction_id": faction_id,
			"days_active": 0,
			"arrived": false,
			"goal_distance": 9999,
		}
		probe["enemy_commander_state"] = EnemyAdventureRulesScript.build_raid_commander_state(
			probe,
			roster_hero_id,
			faction_id,
			session,
			occupied_commander_ids,
			roster
		)
		probe = EnemyAdventureRulesScript.ensure_raid_army(probe, session, occupied_commander_ids)
		var town_defense := EnemyAdventureRulesScript._redirect_raid_to_threatened_town_defense(
			session,
			config,
			probe.duplicate(true),
			faction_id
		)
		var resource_defense := EnemyAdventureRulesScript._redirect_raid_to_threatened_resource_defense(
			session,
			config,
			probe.duplicate(true),
			faction_id
		)
		for redirected_value in [town_defense, resource_defense]:
			if not (redirected_value is Dictionary):
				continue
			var redirected: Dictionary = redirected_value
			if not _emergency_defense_redirect_applies(redirected):
				continue
			var candidate := _spawn_point_candidate_from_emergency_defense(
				point,
				redirected,
				roster_hero_id,
				spawn_order
			)
			if candidate.is_empty():
				continue
			if String(candidate.get("spawn_plan_target_kind", "")) == "town":
				if best_town.is_empty() or _spawn_point_candidate_beats(candidate, best_town):
					best_town = candidate
			elif best_resource.is_empty() or _spawn_point_candidate_beats(candidate, best_resource):
				best_resource = candidate
	return best_town if not best_town.is_empty() else best_resource

static func _emergency_defense_redirect_applies(raid: Dictionary) -> bool:
	var kind := String(raid.get("target_kind", ""))
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if kind == "town":
		return "town_defense" in reason_codes and "front_stabilization" in reason_codes
	if kind == "resource":
		return "site_defense" in reason_codes and "defend_front" in reason_codes
	return false

static func _spawn_point_candidate_from_emergency_defense(
	point: Dictionary,
	raid: Dictionary,
	roster_hero_id: String,
	spawn_order: int
) -> Dictionary:
	var target_kind := String(raid.get("target_kind", ""))
	var target_id := String(raid.get("target_placement_id", ""))
	if target_kind == "" or target_id == "" or roster_hero_id == "":
		return {}
	var goal_distance := int(raid.get("goal_distance", 9999))
	if goal_distance >= 9999:
		return {}
	var priority := 210 if target_kind == "town" else 170
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	var current_strength := EnemyAdventureRulesScript.raid_strength(raid)
	var target_strength := EnemyAdventureRulesScript.desired_raid_strength(raid)
	var score := (priority * 100) - (goal_distance * 8) - spawn_order
	score += current_strength
	var candidate := point.duplicate(true)
	candidate["roster_hero_id"] = roster_hero_id
	candidate["spawn_plan_source"] = "emergency_town_defense" if target_kind == "town" else "emergency_resource_defense"
	candidate["spawn_plan_target_kind"] = target_kind
	candidate["spawn_plan_target_id"] = target_id
	candidate["spawn_plan_target_label"] = String(raid.get("target_label", target_id))
	candidate["spawn_plan_priority"] = priority
	candidate["spawn_plan_goal_distance"] = goal_distance
	candidate["spawn_plan_score"] = score
	candidate["spawn_plan_current_strength"] = current_strength
	candidate["spawn_plan_target_strength"] = target_strength
	candidate["spawn_order"] = spawn_order
	candidate["spawn_plan_reason_codes"] = reason_codes
	candidate["spawn_plan_public_reason"] = String(raid.get("target_public_reason", "defending threatened town"))
	candidate["spawn_plan_public_importance"] = String(raid.get("target_public_importance", "high"))
	candidate["spawn_plan_debug_reason"] = String(raid.get("target_debug_reason", "emergency defensive launch"))
	return candidate

static func _apply_spawn_plan_adventure_spell_projection(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	faction_id: String,
	candidate: Dictionary
) -> Dictionary:
	if session == null or candidate.is_empty() or faction_id == "":
		return candidate
	var goal_distance := int(candidate.get("spawn_plan_goal_distance", 9999))
	if goal_distance <= EnemyAdventureRulesScript.RAID_BASE_MOVEMENT_STEPS or goal_distance >= 9999:
		return candidate
	var actor_id := String(candidate.get("roster_hero_id", ""))
	if actor_id == "":
		return candidate
	var commander := _commander_roster_entry_for_launch(session, faction_id, actor_id, state)
	var commander_state: Dictionary = commander.get("commander_state", {}) if commander.get("commander_state", {}) is Dictionary else {}
	if commander_state.is_empty():
		commander_state = EnemyAdventureRulesScript.build_roster_commander_state(actor_id, faction_id, {}, commander)
	if commander_state.is_empty():
		return candidate
	var movement := {
		"current": EnemyAdventureRulesScript.RAID_BASE_MOVEMENT_STEPS,
		"max": clampi(
			goal_distance,
			EnemyAdventureRulesScript.RAID_BASE_MOVEMENT_STEPS + 1,
			EnemyAdventureRulesScript.RAID_ADVENTURE_SPELL_MAX_MOVEMENT_STEPS
		),
	}
	var context := {
		"target_kind": String(candidate.get("spawn_plan_target_kind", "")),
		"target_label": String(candidate.get("spawn_plan_target_label", candidate.get("spawn_plan_target_id", ""))),
		"objective_steps_remaining": goal_distance,
		"route_pressure": true,
	}
	var report := EnemyAdventureRulesScript.adventure_spell_valuation_report(commander_state, movement, context)
	var selected := _spawn_plan_selected_adventure_spell_candidate(report, "restore_movement")
	if selected.is_empty():
		return candidate
	var movement_after := int(selected.get("movement_after", EnemyAdventureRulesScript.RAID_BASE_MOVEMENT_STEPS))
	var extra_steps: int = max(0, movement_after - EnemyAdventureRulesScript.RAID_BASE_MOVEMENT_STEPS)
	if extra_steps <= 0:
		return candidate
	var projected := candidate.duplicate(true)
	var effective_distance: int = max(0, goal_distance - movement_after)
	var tempo_bonus := (goal_distance - effective_distance) * 36
	if effective_distance <= EnemyAdventureRulesScript.RAID_BASE_MOVEMENT_STEPS:
		tempo_bonus += 220
	projected["spawn_plan_spell_tempo"] = true
	projected["spawn_plan_spell_id"] = String(selected.get("spell_id", ""))
	projected["spawn_plan_spell_name"] = String(selected.get("spell_name", selected.get("spell_id", "")))
	projected["spawn_plan_spell_steps"] = movement_after
	projected["spawn_plan_effective_goal_distance"] = effective_distance
	projected["spawn_plan_score"] = int(projected.get("spawn_plan_score", 0)) + tempo_bonus
	return projected

static func _spawn_plan_selected_adventure_spell_candidate(report: Dictionary, effect_type: String) -> Dictionary:
	var selected := {}
	for candidate_value in report.get("candidates", []):
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("effect_type", "")) != effect_type:
			continue
		if String(candidate.get("recommendation", "")) != "cast":
			continue
		if selected.is_empty() \
			or EnemyAdventureRulesScript._adventure_band_rank(String(candidate.get("value_band", ""))) > EnemyAdventureRulesScript._adventure_band_rank(String(selected.get("value_band", ""))) \
			or (
				EnemyAdventureRulesScript._adventure_band_rank(String(candidate.get("value_band", ""))) == EnemyAdventureRulesScript._adventure_band_rank(String(selected.get("value_band", "")))
				and int(candidate.get("movement_after", 0)) > int(selected.get("movement_after", 0))
			):
			selected = candidate
	return selected

static func _spawn_raid_encounter_id_from_plan(spawn_point: Dictionary, encounter_pool: Array, raid_counter: int) -> String:
	if encounter_pool.is_empty():
		return ""
	var planned_encounter_id := String(spawn_point.get("spawn_plan_encounter_id", ""))
	if bool(spawn_point.get("spawn_plan_ready_launch", false)) and planned_encounter_id != "":
		for encounter_id_value in encounter_pool:
			if String(encounter_id_value) == planned_encounter_id:
				return planned_encounter_id
	return String(encounter_pool[raid_counter % encounter_pool.size()])

static func _spawn_point_candidate_beats(candidate: Dictionary, best: Dictionary) -> bool:
	var candidate_emergency_town := String(candidate.get("spawn_plan_source", "")) == "emergency_town_defense"
	var best_emergency_town := String(best.get("spawn_plan_source", "")) == "emergency_town_defense"
	if candidate_emergency_town != best_emergency_town:
		return candidate_emergency_town
	if int(candidate.get("spawn_plan_score", 0)) == int(best.get("spawn_plan_score", 0)):
		if int(candidate.get("spawn_plan_goal_distance", 9999)) == int(best.get("spawn_plan_goal_distance", 9999)):
			return int(candidate.get("spawn_order", 9999)) < int(best.get("spawn_order", 9999))
		return int(candidate.get("spawn_plan_goal_distance", 9999)) < int(best.get("spawn_plan_goal_distance", 9999))
	return int(candidate.get("spawn_plan_score", 0)) > int(best.get("spawn_plan_score", 0))

static func _open_spawn_points(session: SessionStateStoreScript.SessionData, config: Dictionary) -> Array:
	var points := []
	var spawn_points = config.get("spawn_points", [])
	if not (spawn_points is Array):
		return points

	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var player_hero_occupied_tiles := _player_hero_occupied_tile_lookup(session)
	for point in spawn_points:
		if not (point is Dictionary):
			continue
		var x = int(point.get("x", -1))
		var y = int(point.get("y", -1))
		if player_hero_occupied_tiles.has(_tile_key_xy(x, y)):
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
			points.append({"x": x, "y": y})
	return points

static func _player_hero_occupied_tile_lookup(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var occupied := {}
	if session == null:
		return occupied
	_record_position_tile(occupied, session.overworld.get("hero_position", {}))
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		_record_position_tile(occupied, hero.get("position", {}))
	var player_heroes = session.overworld.get("player_heroes", [])
	if player_heroes is Array:
		for hero_value in player_heroes:
			if hero_value is Dictionary:
				_record_position_tile(occupied, hero_value.get("position", {}))
	var heroes = session.overworld.get("heroes", [])
	if heroes is Array:
		for hero_value in heroes:
			if not (hero_value is Dictionary):
				continue
			if String(hero_value.get("owner", "player")) != "player":
				continue
			_record_position_tile(occupied, hero_value.get("position", {}))
	return occupied

static func _record_position_tile(occupied: Dictionary, position_value: Variant) -> void:
	if not (position_value is Dictionary):
		return
	var position: Dictionary = position_value
	if position.is_empty():
		return
	occupied[_tile_key_xy(int(position.get("x", -9999)), int(position.get("y", -9999)))] = true

static func _tile_key_xy(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func _enemy_faction_configs_for_session(session: SessionStateStoreScript.SessionData) -> Array:
	if session == null:
		return []
	var scenario = ContentService.get_scenario(session.scenario_id)
	var configs = scenario.get("enemy_factions", [])
	if configs is Array and not configs.is_empty():
		var valid_configs := _valid_enemy_faction_configs(configs)
		if not valid_configs.is_empty():
			return _enemy_faction_configs_with_runtime_defaults(session, valid_configs)
	var runtime_record: Dictionary = session.overworld.get("native_random_map_runtime_scenario_record", {}) if session.overworld.get("native_random_map_runtime_scenario_record", {}) is Dictionary else {}
	configs = runtime_record.get("enemy_factions", [])
	if configs is Array:
		var valid_runtime_configs := _valid_enemy_faction_configs(configs)
		if not valid_runtime_configs.is_empty():
			return _enemy_faction_configs_with_runtime_defaults(session, valid_runtime_configs)
	var fallback_configs := []
	var seen := {}
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		var faction_id := _town_controller_faction_id(town)
		if faction_id == "" or bool(seen.get(faction_id, false)):
			continue
		var faction := ContentService.get_faction(faction_id)
		if faction.is_empty():
			continue
		seen[faction_id] = true
		fallback_configs.append({
			"faction_id": faction_id,
			"label": String(faction.get("name", faction_id)),
			"generated_package_town_config": true,
		})
	return _enemy_faction_configs_with_runtime_defaults(session, fallback_configs)

static func _enemy_config_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	if faction_id == "":
		return {}
	for config_value in _enemy_faction_configs_for_session(session):
		if config_value is Dictionary and String(config_value.get("faction_id", "")) == faction_id:
			return config_value
	return {}

static func _valid_enemy_faction_configs(configs: Array) -> Array:
	var result := []
	for config_value in configs:
		if not (config_value is Dictionary):
			continue
		var config: Dictionary = config_value
		if ContentService.get_faction(String(config.get("faction_id", ""))).is_empty():
			continue
		result.append(config.duplicate(true))
	return result

static func _enemy_faction_configs_with_runtime_defaults(session: SessionStateStoreScript.SessionData, configs: Array) -> Array:
	var result := []
	for config_value in configs:
		if not (config_value is Dictionary):
			continue
		result.append(_enemy_faction_config_with_runtime_defaults(session, config_value))
	return result

static func _enemy_faction_config_with_runtime_defaults(session: SessionStateStoreScript.SessionData, config: Dictionary) -> Dictionary:
	var normalized := config.duplicate(true)
	var faction_id := String(normalized.get("faction_id", ""))
	if faction_id == "":
		return normalized
	var faction := ContentService.get_faction(faction_id)
	if String(normalized.get("label", "")) == "":
		normalized["label"] = String(faction.get("name", faction_id))
	if int(normalized.get("pressure_per_day", 0)) <= 0:
		normalized["pressure_per_day"] = 2
	if int(normalized.get("pressure_per_enemy_town", 0)) <= 0:
		normalized["pressure_per_enemy_town"] = 1
	if int(normalized.get("raid_threshold", 0)) <= 0:
		normalized["raid_threshold"] = 5
	if int(normalized.get("max_active_raids", 0)) <= 0:
		normalized["max_active_raids"] = 2
	if int(normalized.get("raid_pillage_delay", 0)) <= 0:
		normalized["raid_pillage_delay"] = 1
	if not (normalized.get("raid_pillage", {}) is Dictionary) or normalized.get("raid_pillage", {}).is_empty():
		normalized["raid_pillage"] = {"gold": 150}
	if not (normalized.get("raid_encounter_ids", []) is Array) or normalized.get("raid_encounter_ids", []).is_empty():
		normalized["raid_encounter_ids"] = _default_raid_encounter_ids_for_faction(faction_id)
	if not (normalized.get("spawn_points", []) is Array) or normalized.get("spawn_points", []).is_empty():
		normalized["spawn_points"] = _default_spawn_points_for_faction(session, faction_id)
	if not (normalized.get("priority_target_placement_ids", []) is Array):
		normalized["priority_target_placement_ids"] = []
	if int(normalized.get("priority_target_bonus", 0)) <= 0:
		normalized["priority_target_bonus"] = 80
	if not bool(normalized.get("generated_package_town_config", false)) and _config_was_runtime_defaulted(config, normalized):
		normalized["generated_package_town_config"] = bool(session != null and bool(session.flags.get("generated_random_map", false)))
	return normalized

static func _config_was_runtime_defaulted(source: Dictionary, normalized: Dictionary) -> bool:
	for key in ["pressure_per_day", "pressure_per_enemy_town", "raid_threshold", "max_active_raids", "raid_pillage_delay", "raid_pillage", "raid_encounter_ids", "spawn_points"]:
		if not source.has(key) and normalized.has(key):
			return true
	return false

static func _default_raid_encounter_ids_for_faction(faction_id: String) -> Array:
	match faction_id:
		"faction_mireclaw":
			return ["encounter_mire_raid", "encounter_blackbranch_reavers"]
		"faction_sunvault":
			return ["encounter_aurora_battery", "encounter_daybreak_matrix"]
		"faction_thornwake":
			return ["encounter_graftroot_wardens"]
		"faction_brasshollow":
			return ["encounter_orevein_exactors"]
		"faction_veilmourn":
			return ["encounter_bellwake_privateers"]
		_:
			return ["encounter_ford_reavers", "encounter_mire_raid"]

static func _default_spawn_points_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var points := []
	if session == null:
		return points
	for entry in _owned_town_entries(session, faction_id):
		if not (entry is Dictionary):
			continue
		var town: Dictionary = entry.get("town", {}) if entry.get("town", {}) is Dictionary else {}
		if town.is_empty():
			continue
		points.append({"x": int(town.get("x", 0)), "y": int(town.get("y", 0))})
	return points

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
		if _town_controller_faction_id(town) != faction_id:
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
		if _town_controller_faction_id(town) != faction_id:
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
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
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
	if bool(front_state.get("active", false)) and String(front_state.get("mode", "")) == "stabilizing":
		target += 50 + int(round(float(int(front_state.get("garrison_bonus", 0))) / 2.5))
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
		if _town_controller_faction_id(town) != faction_id:
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
		if _town_controller_faction_id(town) != faction_id:
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
	threshold -= int(_faction_front_state(session, faction_id).get("threshold_reduction", 0))
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

static func _recruit_priority_for_destination(
	unit_id: String,
	config: Dictionary,
	faction_id: String,
	destination: Dictionary = {}
) -> float:
	var unit = ContentService.get_unit(unit_id)
	if unit.is_empty():
		return 0.0
	var score := _recruit_priority(unit_id, config, faction_id)
	var tier: int = max(1, int(unit.get("tier", 1)))
	var attack: int = max(0, int(unit.get("attack", 0)))
	var defense: int = max(0, int(unit.get("defense", 0)))
	var hp: int = max(1, int(unit.get("hp", 1)))
	var initiative: int = max(0, int(unit.get("initiative", 0)))
	var ranged := bool(unit.get("ranged", false))
	var flying := bool(unit.get("flying", false))
	var role := String(unit.get("role", ""))
	var abilities: Array = unit.get("ability_ids", []) if unit.get("ability_ids", []) is Array else []
	var destination_type := String(destination.get("type", "garrison"))
	var target_kind := String(destination.get("target_kind", ""))
	var reason_codes := _normalize_string_array(destination.get("reason_codes", []))
	var decision_rule := String(destination.get("decision_rule", ""))

	match destination_type:
		"garrison":
			score += float((defense * 12) + int(hp / 2))
			if "garrison_safety" in reason_codes or decision_rule in ["critical_garrison_gap", "stabilizing_front"]:
				score += float(defense * 10)
				if "brace" in abilities or "linekeeper" in abilities or role in ["melee", "defender"]:
					score += 28.0
				if ranged:
					score += 10.0
		"raid":
			score += float((attack * 10) + (initiative * 5))
			if target_kind == "town":
				score += float((tier * 9) + attack * 4)
			elif target_kind == "hero":
				score += float(initiative * 8)
				if flying:
					score += 20.0
			elif target_kind in ["resource", "artifact", "encounter"]:
				score += float(tier * 5)
			if "bloodrush" in abilities or "volley" in abilities:
				score += 18.0
		"planned":
			score += float(max(0, int(destination.get("commander_fit_bonus", 0))) * 0.35)
			match target_kind:
				"town":
					score += float((attack * 12) + (tier * 10))
				"hero":
					score += float((attack * 9) + (initiative * 10))
					if flying:
						score += 20.0
				"artifact", "encounter":
					score += float((tier * 8) + attack * 5)
					if ranged:
						score += 20.0
				"resource":
					score += float((defense * 8) + (attack * 6))
					if "recruit_denial" in reason_codes and tier <= 3:
						score += 12.0
			if "magic" in String(destination.get("commander_fit_profile", "")) and ranged:
				score += 40.0
		"rebuild":
			score += float((tier * 8) + attack * 7 + defense * 5)
			if ranged:
				score += 8.0
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

static func _max_affordable_from_pool_with_town_market(
	town: Dictionary,
	pool: Dictionary,
	unit_cost: Variant,
	current_day: int = -1,
	max_count: int = 999
) -> int:
	if not (unit_cost is Dictionary) or unit_cost.is_empty():
		return max(0, max_count)
	var direct_affordable: int = _max_affordable_from_pool(pool, unit_cost)
	var max_probe: int = min(max(0, max_count), max(direct_affordable, 1))
	var market_state: Dictionary = OverworldRulesScript.town_market_state(town)
	if bool(market_state.get("active", false)):
		var gold_price: int = max(1, int(unit_cost.get("gold", 0)))
		max_probe = min(max(0, max_count), max(max_probe, int(int(pool.get("gold", 0)) / gold_price) + 1))
		for resource_key in ["wood", "ore"]:
			var price: int = max(0, int(unit_cost.get(resource_key, 0)))
			if price > 0:
				var available_stock := int(pool.get(resource_key, 0)) + int(market_state.get("buy_caps", {}).get(resource_key, 0))
				max_probe = min(max(0, max_count), max(max_probe, int(available_stock / price) + 1))
	var affordable := 0
	for count in range(1, max_probe + 1):
		var scaled_cost := _scale_resource_pool(unit_cost, count)
		if not OverworldRulesScript.can_afford_cost_with_town_market(town, pool, scaled_cost, current_day):
			break
		affordable = count
	return affordable

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
	value += int(resources.get("aetherglass", 0)) * 800
	value += int(resources.get("embergrain", 0)) * 800
	value += int(resources.get("peatwax", 0)) * 800
	value += int(resources.get("verdant_grafts", 0)) * 800
	value += int(resources.get("brass_scrip", 0)) * 800
	value += int(resources.get("memory_salt", 0)) * 800
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

static func _normalize_hero_task_record(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"ok": false, "invalid_reason": "task_not_dictionary", "sanitized_field_count": 0}
	var task: Dictionary = value
	var required_strings := [
		"task_id",
		"owner_faction_id",
		"actor_id",
		"task_class",
		"target_id",
	]
	for required_key in required_strings:
		if String(task.get(String(required_key), "")) == "":
			return {
				"ok": false,
				"invalid_reason": "missing_%s" % String(required_key),
				"sanitized_field_count": _hero_task_record_sanitized_field_count(task),
			}
	var task_class := _normalize_hero_task_class(task.get("task_class", ""))
	var task_status := _normalize_hero_task_status(task.get("task_status", "planned"))
	var target_kind := _normalize_hero_task_target_kind(task.get("target_kind", ""))
	var validation := _normalize_hero_task_validation_code(task.get("last_validation", "valid"))
	if task_class == "" or task_status == "" or target_kind == "" or validation == "":
		return {
			"ok": false,
			"invalid_reason": "unsupported_task_enum",
			"sanitized_field_count": _hero_task_record_sanitized_field_count(task),
		}
	var normalized := {
		"task_id": String(task.get("task_id", "")),
		"owner_faction_id": String(task.get("owner_faction_id", "")),
		"actor_kind": _normalize_hero_task_actor_kind(task.get("actor_kind", "commander_roster")),
		"actor_id": String(task.get("actor_id", "")),
		"source_kind": _normalize_hero_task_source_kind(task.get("source_kind", "commander_role_adapter")),
		"source_id": String(task.get("source_id", "")),
		"task_class": task_class,
		"task_status": task_status,
		"target_kind": target_kind,
		"target_id": String(task.get("target_id", "")),
		"front_id": String(task.get("front_id", "")),
		"origin_kind": _normalize_hero_task_origin_kind(task.get("origin_kind", "town")),
		"origin_id": String(task.get("origin_id", "")),
		"priority_reason_codes": _normalize_string_array(task.get("priority_reason_codes", [])),
		"assigned_day": max(0, int(task.get("assigned_day", 0))),
		"expires_day": max(0, int(task.get("expires_day", 0))),
		"continuity_policy": _normalize_hero_task_continuity_policy(task.get("continuity_policy", "persist_until_invalid")),
		"route_policy": _normalize_hero_task_route_policy(task.get("route_policy", "derive_route_on_turn")),
		"last_validation": validation,
	}
	if task.has("invalidated_by_task_id"):
		normalized["invalidated_by_task_id"] = String(task.get("invalidated_by_task_id", ""))
	if task.get("reservation", {}) is Dictionary:
		normalized["reservation"] = _normalize_hero_task_reservation(task.get("reservation", {}))
	return {
		"ok": true,
		"task": normalized,
		"sanitized_field_count": _hero_task_record_sanitized_field_count(task),
	}

static func _hero_task_state_board_sanitized_field_count(board: Dictionary) -> int:
	var allowed := {"schema_version": true, "planner_epoch": true, "tasks": true}
	var sanitized := 0
	for key in board.keys():
		if not allowed.has(String(key)):
			sanitized += 1
	return sanitized

static func _hero_task_record_sanitized_field_count(task: Dictionary) -> int:
	var allowed := {
		"task_id": true,
		"owner_faction_id": true,
		"actor_kind": true,
		"actor_id": true,
		"source_kind": true,
		"source_id": true,
		"task_class": true,
		"task_status": true,
		"target_kind": true,
		"target_id": true,
		"front_id": true,
		"origin_kind": true,
		"origin_id": true,
		"priority_reason_codes": true,
		"assigned_day": true,
		"expires_day": true,
		"continuity_policy": true,
		"route_policy": true,
		"last_validation": true,
		"reservation": true,
		"invalidated_by_task_id": true,
	}
	var sanitized := 0
	for key in task.keys():
		if not allowed.has(String(key)):
			sanitized += 1
	return sanitized

static func _normalize_hero_task_class(value: Variant) -> String:
	var task_class := String(value)
	if task_class in ["raid_town", "retake_site", "contest_site", "stabilize_front", "defend_front", "scout_frontier", "recover_commander", "rebuild_host", "reserve"]:
		return task_class
	return ""

static func _normalize_hero_task_status(value: Variant) -> String:
	var task_status := String(value)
	if task_status in ["candidate", "planned", "reserved", "active", "suspended", "blocked", "completed", "failed", "cancelled", "invalid"]:
		return task_status
	return ""

static func _normalize_hero_task_target_kind(value: Variant) -> String:
	var target_kind := String(value)
	if target_kind in ["resource", "town", "artifact", "encounter", "hero", "regroup", "commander", "front"]:
		return target_kind
	if target_kind == "explore":
		return target_kind
	return ""

static func _normalize_hero_task_actor_kind(value: Variant) -> String:
	var actor_kind := String(value)
	return actor_kind if actor_kind in ["commander_roster", "active_encounter", "ai_hero"] else "commander_roster"

static func _normalize_hero_task_source_kind(value: Variant) -> String:
	var source_kind := String(value)
	return source_kind if source_kind in ["commander_role_adapter", "saved_task_state"] else "commander_role_adapter"

static func _normalize_hero_task_origin_kind(value: Variant) -> String:
	var origin_kind := String(value)
	return origin_kind if origin_kind in ["town", "front", "encounter"] else "town"

static func _normalize_hero_task_continuity_policy(value: Variant) -> String:
	var policy := String(value)
	return policy if policy in ["persist_until_invalid", "expire_on_day", "derive_each_turn"] else "persist_until_invalid"

static func _normalize_hero_task_route_policy(value: Variant) -> String:
	var policy := String(value)
	return policy if policy in ["derive_route_on_turn", "hold_position", "route_deferred"] else "derive_route_on_turn"

static func _normalize_hero_task_validation_code(value: Variant) -> String:
	var code := String(value)
	if code in [
		"valid",
		"invalid_target_missing",
		"invalid_target_resolved",
		"invalid_controller_changed",
		"invalid_target_reserved",
		"invalid_front_quiet",
		"invalid_actor_missing",
		"invalid_actor_recovering",
		"invalid_actor_rebuilding",
		"invalid_actor_active_elsewhere",
		"invalid_actor_defeated",
		"invalid_battle_defeat",
		"invalid_battle_withdrawal",
		"invalid_origin_missing",
		"invalid_origin_controller_changed",
		"invalid_route_unreachable",
		"invalid_approach_unavailable",
		"invalid_task_expired",
		"battle_stalemate",
		"cancelled_by_retask",
		"invalid_script_lock",
		"invalid_scenario_complete",
	]:
		return code
	return ""

static func _normalize_hero_task_reservation(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"reservation_status": "none", "reservation_scope": "none", "reservation_key": ""}
	var reservation: Dictionary = value
	var status := String(reservation.get("reservation_status", "none"))
	if status not in ["none", "primary", "shared", "released", "rejected_duplicate"]:
		status = "none"
	var scope := String(reservation.get("reservation_scope", "none"))
	if scope not in ["none", "exclusive_target", "shared_front"]:
		scope = "none"
	return {
		"reservation_status": status,
		"reservation_scope": scope,
		"reservation_key": String(reservation.get("reservation_key", "")),
	}

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

static func _set_town_owner(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	owner: String,
	controlling_faction_id: String = "",
	source: String = ""
) -> void:
	OverworldRulesScript.transition_town_control(
		session,
		placement_id,
		owner,
		controlling_faction_id,
		source
	)

static func _town_name(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("name", town_state.get("town_id", "Town")))

static func _town_faction_id(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("faction_id", ""))

static func _town_controller_faction_id(town_state: Dictionary) -> String:
	var controller := String(town_state.get("controlling_faction_id", ""))
	if String(town_state.get("owner", "neutral")) == "enemy" and controller != "":
		return controller
	return _town_faction_id(town_state)
