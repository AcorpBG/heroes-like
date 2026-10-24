class_name ScenarioRules
extends RefCounted

const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const GeneratedObjectives = preload("res://scripts/core/GeneratedScenarioObjectiveRules.gd")
const TownDevelopmentRulesScript = preload("res://scripts/core/TownDevelopmentRules.gd")
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static var _scenario_dependency_metadata_cache: Dictionary = {}

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func _scenario_select_rules() -> Variant:
	# Validator anchor: ScenarioSelectRules.start_skirmish_session
	return load("res://scripts/core/ScenarioSelectRules.gd")

static func _overworld_rules() -> Variant:
	# Validator anchors: OverworldRules.describe_hero, OverworldRules.describe_army, OverworldRules.describe_resources
	return load("res://scripts/core/OverworldRules.gd")

## normalize_enemies false: the caller has just normalized the enemy states.
static func normalize_scenario_state(session: SessionStateStoreScript.SessionData, normalize_enemies: bool = true) -> void:
	HumanEngine.native_writing(&"ScenarioRules.normalize_scenario_state", [session, normalize_enemies])

static func scenario_record_for_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules.scenario_record_for_session", [session])

static func evaluate_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return DayEngine.native_writing(&"ScenarioRules.evaluate_session", [session])

static func objective_definitions(scenario: Dictionary) -> Variant:
	return HumanEngine.native_writing(&"ScenarioRules.objective_definitions", [scenario])

static func objectives_for_session(session: SessionStateStoreScript.SessionData) -> Variant:
	return HumanEngine.native_writing(&"ScenarioRules.objectives_for_session", [session])

static func evaluate_session_for_event(session: SessionStateStoreScript.SessionData, event_facts: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules.evaluate_session_for_event", [session, event_facts])

static func _scenario_objective_dependency(objective: Dictionary, objective_index: Dictionary, seen: Dictionary) -> Dictionary:
	return HumanEngine.native(&"ScenarioRules._scenario_objective_dependency", [objective, objective_index, seen])

static func clear_dependency_metadata_cache() -> void:
	_scenario_dependency_metadata_cache.clear()

static func is_objective_met(session: SessionStateStoreScript.SessionData, objective_id: String, bucket: String = "") -> bool:
	return HumanEngine.native_writing(&"ScenarioRules.is_objective_met", [session, objective_id, bucket])

static func describe_scenario_briefing(scenario_id: String) -> String:
	var scenario := ContentService.get_scenario_readonly(scenario_id)
	if scenario.is_empty():
		return ""
	return "\n".join(_scenario_briefing_lines(scenario))

static func describe_scenario_launch_preview(
	scenario_id: String,
	difficulty_id: String = "normal",
	launch_mode: String = SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
	action_label: String = "Launch",
	context_label: String = ""
) -> String:
	var normalized_difficulty: String = _scenario_select_rules().normalize_difficulty(difficulty_id)
	var normalized_mode: String = SessionStateStoreScript.normalize_launch_mode(launch_mode)
	var session: SessionStateStoreScript.SessionData = _scenario_factory().create_session(
		scenario_id,
		normalized_difficulty,
		normalized_mode
	)
	if session.scenario_id == "":
		return "Launch preview unavailable."
	_overworld_rules().normalize_overworld_state(session)
	normalize_scenario_state(session)

	var scenario := scenario_record_for_session(session)
	var scenario_name := String(scenario.get("name", session.scenario_id))
	var mode_label: String = _scenario_select_rules().launch_mode_label(normalized_mode)
	var launch_context := context_label if context_label != "" else scenario_name
	var lines := [
		"Launch Preview",
		"%s | %s | %s"
		% [
			mode_label,
			_scenario_select_rules().difficulty_label(normalized_difficulty),
			launch_context,
		],
	]

	var objectives = objective_definitions(scenario)
	if objectives is Dictionary:
		var victory_labels := _objective_labels_from_bucket(session, objectives.get("victory", []), 3)
		if not victory_labels.is_empty():
			lines.append("Objective: %s" % "; ".join(victory_labels))
		var defeat_labels := _objective_labels_from_bucket(session, objectives.get("defeat", []), 2)
		if not defeat_labels.is_empty():
			lines.append("Failure watch: %s" % "; ".join(defeat_labels))

	var stakes_text := _scenario_stakes_text(scenario)
	if stakes_text != "":
		lines.append("Stakes: %s" % stakes_text)
	var progress_line := _progress_recap_status_line(session)
	var next_step_line := _progress_recap_next_step_line(session, scenario)
	if progress_line != "":
		lines.append(progress_line)
	if next_step_line != "":
		lines.append(next_step_line)
	lines.append(
		"Action: %s starts a fresh %s expedition on Day 1; it will not load a save."
		% [action_label, mode_label.to_lower()]
	)
	return "\n".join(lines)

static func describe_session_progress_recap(session: SessionStateStoreScript.SessionData, include_header: bool = true) -> String:
	return HumanEngine.native_writing(&"ScenarioRules.describe_session_progress_recap", [session, include_header])

static func describe_session_progress_recap_from_normalized_session(session: SessionStateStoreScript.SessionData, include_header: bool = true, preloaded_objective_surface: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"ScenarioRules.describe_session_progress_recap_from_normalized_session", [session, include_header, preloaded_objective_surface])

static func describe_scenario_operational_board(
	scenario_id: String,
	difficulty_id: String = "normal",
	launch_mode: String = SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
) -> String:
	var normalized_difficulty: String = _scenario_select_rules().normalize_difficulty(difficulty_id)
	var session: SessionStateStoreScript.SessionData = _scenario_factory().create_session(scenario_id, normalized_difficulty, launch_mode)
	if session.scenario_id == "":
		return "Operational board unavailable."
	_overworld_rules().normalize_overworld_state(session)
	normalize_scenario_state(session)
	return describe_session_operational_board(session)

static func describe_session_operational_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Operational board unavailable."
	_overworld_rules().normalize_overworld_state(session)
	normalize_scenario_state(session)
	var scenario := scenario_record_for_session(session)
	if scenario.is_empty():
		return "Operational board unavailable."

	var lines := ["Operational Board"]
	var terrain_summary := _operational_terrain_summary(session, scenario)
	if terrain_summary != "":
		lines.append(terrain_summary)
	lines.append_array(_enemy_operational_lines(session, scenario))
	var objective_summary := _opening_objective_summary(session, scenario)
	if objective_summary != "":
		lines.append(objective_summary)
	var first_contact_summary := _first_contact_summary(scenario)
	if first_contact_summary != "":
		lines.append(first_contact_summary)
	var escalation_summary := _reinforcement_risk_summary(scenario)
	if escalation_summary != "":
		lines.append(escalation_summary)
	return "\n".join(lines)

static func build_outcome_model(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules.build_outcome_model", [session])

static func perform_outcome_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules.perform_outcome_action", [session, action_id])

static func _progress_recap_status_line(session: SessionStateStoreScript.SessionData, preloaded_objective_surface: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._progress_recap_status_line", [session, preloaded_objective_surface])

static func _progress_recap_next_step_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary, preloaded_objective_surface: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._progress_recap_next_step_line", [session, scenario, preloaded_objective_surface])

static func _scenario_briefing_lines(scenario: Dictionary) -> Array:
	var selection = scenario.get("selection", {})
	var selection_dict: Dictionary = selection if selection is Dictionary else {}
	var lines := []
	var briefing_text := String(selection_dict.get("summary", scenario.get("description", scenario.get("name", ""))))
	if briefing_text != "":
		lines.append("Briefing: %s" % briefing_text)
	var player_text := String(selection_dict.get("player_summary", ""))
	if player_text != "":
		lines.append("Command: %s" % player_text)
	var intel_text := String(selection_dict.get("enemy_summary", ""))
	if intel_text != "":
		lines.append("Intel: %s" % intel_text)
	var stakes_text := _scenario_stakes_text(scenario)
	if stakes_text != "":
		lines.append("Stakes: %s" % stakes_text)
	return lines

static func _scenario_stakes_text(scenario: Dictionary) -> String:
	var objectives = objective_definitions(scenario)
	if objectives is Dictionary:
		var victory_text := String(objectives.get("victory_text", ""))
		var defeat_text := String(objectives.get("defeat_text", ""))
		if victory_text != "" and defeat_text != "":
			return "%s If you fail: %s" % [victory_text, defeat_text]
		if victory_text != "":
			return victory_text
		if defeat_text != "":
			return defeat_text
	return ""

static func _operational_terrain_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var start: Dictionary = session.overworld.get("hero_position", scenario.get("start", {}))
	var start_x := int(start.get("x", 0))
	var start_y := int(start.get("y", 0))
	var start_terrain := _terrain_label(String(_map_tile_id(scenario.get("map", []), start_x, start_y)))
	var terrain_counts := {}
	for row in scenario.get("map", []):
		if not (row is Array):
			continue
		for cell in row:
			var terrain_id := String(cell)
			if terrain_id == "":
				continue
			terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
	var terrain_ids := terrain_counts.keys()
	terrain_ids.sort_custom(func(a, b): return int(terrain_counts.get(String(a), 0)) > int(terrain_counts.get(String(b), 0)))
	var mix := []
	for terrain_id_value in terrain_ids:
		var terrain_label := _terrain_label(String(terrain_id_value))
		if terrain_label != "" and terrain_label not in mix:
			mix.append(terrain_label)
		if mix.size() >= 3:
			break
	return "Terrain: deploy on %s | Front mix %s" % [
		start_terrain,
		", ".join(mix) if not mix.is_empty() else "Unknown ground",
	]

static func _enemy_operational_lines(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> Array:
	return HumanEngine.native_writing(&"ScenarioRules._enemy_operational_lines", [session, scenario])

static func _opening_objective_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._opening_objective_summary", [session, scenario])

static func _first_contact_summary(scenario: Dictionary) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._first_contact_summary", [scenario])

static func _reinforcement_risk_summary(scenario: Dictionary) -> String:
	var escalation_hooks := 0
	var earliest_day := -1
	var delayed_objectives := false
	var raid_driven := false
	var pressure_driven := false
	var capture_driven := false
	for hook in scenario.get("script_hooks", []):
		if not (hook is Dictionary):
			continue
		var escalation := false
		for effect in hook.get("effects", []):
			if not (effect is Dictionary):
				continue
			var effect_type := String(effect.get("type", ""))
			if effect_type == "spawn_encounter" or effect_type == "add_enemy_pressure":
				escalation = true
				break
		if not escalation:
			continue
		escalation_hooks += 1
		for condition in hook.get("conditions", []):
			if not (condition is Dictionary):
				continue
			match String(condition.get("type", "")):
				"day_at_least":
					var day: int = max(1, int(condition.get("day", 1)))
					if earliest_day == -1 or day < earliest_day:
						earliest_day = day
				"objective_not_met":
					delayed_objectives = true
				"active_raid_count_at_least":
					raid_driven = true
				"enemy_pressure_at_least":
					pressure_driven = true
				"town_owned_by_player":
					capture_driven = true
	if escalation_hooks <= 0:
		return ""
	var parts := ["Reinforcement risk: %d escalation hook%s" % [escalation_hooks, "" if escalation_hooks == 1 else "s"]]
	if earliest_day > 0:
		parts.append("earliest by Day %d" % earliest_day)
	if delayed_objectives:
		parts.append("unresolved objectives invite fresh hosts")
	if raid_driven or pressure_driven:
		parts.append("enemy hero activity accelerates counterstrokes")
	if capture_driven:
		parts.append("captured towns can trigger immediate pushback")
	return " | ".join(parts)

static func _objective_labels_from_bucket(session: SessionStateStoreScript.SessionData, bucket: Variant, limit: int) -> Array:
	return HumanEngine.native_writing(&"ScenarioRules._objective_labels_from_bucket", [session, bucket, limit])

static func _map_tile_id(map_data: Variant, x: int, y: int) -> String:
	if not (map_data is Array) or y < 0 or y >= map_data.size():
		return ""
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return ""
	return String(row[x])

static func _terrain_label(terrain_id: String) -> String:
	return HumanEngine.native(&"ScenarioRules._terrain_label", [terrain_id])

static func _objective_label(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._objective_label", [session, objective])

static func _objective_progress_counts(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules._objective_progress_counts", [session])
