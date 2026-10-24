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
static var _human_engine_mode: int = HumanEngine.mode

static var _scenario_dependency_metadata_cache: Dictionary = {}

static func _scenario_script_rules() -> Variant:
	return load("res://scripts/core/ScenarioScriptRules.gd")

static func _enemy_turn_rules() -> Variant:
	return load("res://scripts/core/EnemyTurnRules.gd")

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
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		normalize_scenario_state__gd(session, normalize_enemies)
	elif _human_engine_mode == HumanEngine.NATIVE:
		HumanEngine.native_writing(&"ScenarioRules.normalize_scenario_state", [session, normalize_enemies])
	else:
		var before := HumanEngine.before_writing(&"ScenarioRules.normalize_scenario_state", [session, normalize_enemies])
		normalize_scenario_state__gd(session, normalize_enemies)
		HumanEngine.check_writing(&"ScenarioRules.normalize_scenario_state", before, [session, normalize_enemies], null)

static func normalize_scenario_state__gd(session: SessionStateStoreScript.SessionData, normalize_enemies: bool = true) -> void:
	if session == null:
		return
	if session.scenario_status == "":
		session.scenario_status = "in_progress"
	if session.scenario_summary == "":
		session.scenario_summary = ""
	_scenario_script_rules().normalize_script_state(session)
	if normalize_enemies:
		_enemy_turn_rules().normalize_enemy_states(session)

static func scenario_record_for_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return scenario_record_for_session__gd(session)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules.scenario_record_for_session", [session])
	var before := HumanEngine.before_writing(&"ScenarioRules.scenario_record_for_session", [session])
	var result = scenario_record_for_session__gd(session)
	HumanEngine.check_writing(&"ScenarioRules.scenario_record_for_session", before, [session], result)
	return result

static func scenario_record_for_session__gd(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.scenario_id == "":
		return {}
	var runtime_record: Dictionary = session.flags.get("native_random_map_runtime_scenario_record", {}) if session.flags.get("native_random_map_runtime_scenario_record", {}) is Dictionary else {}
	if not runtime_record.is_empty() and String(runtime_record.get("id", "")) == session.scenario_id:
		return runtime_record
	runtime_record = session.overworld.get("native_random_map_runtime_scenario_record", {}) if session.overworld.get("native_random_map_runtime_scenario_record", {}) is Dictionary else {}
	if not runtime_record.is_empty() and String(runtime_record.get("id", "")) == session.scenario_id:
		return runtime_record
	return ContentService.get_scenario_readonly(session.scenario_id)

static func evaluate_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return DayEngine.native_writing(&"ScenarioRules.evaluate_session", [session])

static func objective_definitions(scenario: Dictionary) -> Variant:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return objective_definitions__gd(scenario)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules.objective_definitions", [scenario])
	var before := HumanEngine.before_writing(&"ScenarioRules.objective_definitions", [scenario])
	var result = objective_definitions__gd(scenario)
	HumanEngine.check_writing(&"ScenarioRules.objective_definitions", before, [scenario], result)
	return result

static func objective_definitions__gd(scenario: Dictionary) -> Variant:
	return GeneratedObjectives.definitions(scenario)

static func objectives_for_session(session: SessionStateStoreScript.SessionData) -> Variant:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return objectives_for_session__gd(session)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules.objectives_for_session", [session])
	var before := HumanEngine.before_writing(&"ScenarioRules.objectives_for_session", [session])
	var result = objectives_for_session__gd(session)
	HumanEngine.check_writing(&"ScenarioRules.objectives_for_session", before, [session], result)
	return result

static func objectives_for_session__gd(session: SessionStateStoreScript.SessionData) -> Variant:
	return objective_definitions(scenario_record_for_session(session))

static func evaluate_session_for_event(session: SessionStateStoreScript.SessionData, event_facts: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules.evaluate_session_for_event", [session, event_facts])

static func _scenario_objective_dependency(objective: Dictionary, objective_index: Dictionary, seen: Dictionary) -> Dictionary:
	return HumanEngine.native(&"ScenarioRules._scenario_objective_dependency", [objective, objective_index, seen])

static func clear_dependency_metadata_cache() -> void:
	_scenario_dependency_metadata_cache.clear()

static func is_objective_met(session: SessionStateStoreScript.SessionData, objective_id: String, bucket: String = "") -> bool:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return is_objective_met__gd(session, objective_id, bucket)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules.is_objective_met", [session, objective_id, bucket])
	var before := HumanEngine.before_writing(&"ScenarioRules.is_objective_met", [session, objective_id, bucket])
	var result = is_objective_met__gd(session, objective_id, bucket)
	HumanEngine.check_writing(&"ScenarioRules.is_objective_met", before, [session, objective_id, bucket], result)
	return result

static func is_objective_met__gd(
	session: SessionStateStoreScript.SessionData,
	objective_id: String,
	bucket: String = ""
) -> bool:
	var objective := get_objective(session, objective_id, bucket)
	return not objective.is_empty() and _objective_met(session, objective)

static func get_objective(
	session: SessionStateStoreScript.SessionData,
	objective_id: String,
	bucket: String = ""
) -> Dictionary:
	if session == null or session.scenario_id == "" or objective_id == "":
		return {}
	var scenario := scenario_record_for_session(session)
	var objectives = objective_definitions(scenario)
	if not (objectives is Dictionary):
		return {}

	var buckets := []
	if bucket in ["victory", "defeat"]:
		buckets = [bucket]
	else:
		buckets = ["victory", "defeat"]
	for bucket_name in buckets:
		for objective in objectives.get(bucket_name, []):
			if objective is Dictionary and String(objective.get("id", "")) == objective_id:
				return objective
	return {}

static func describe_objectives(session: SessionStateStoreScript.SessionData) -> String:
	normalize_scenario_state(session)
	var scenario := scenario_record_for_session(session)
	var objectives = objective_definitions(scenario)
	if not (objectives is Dictionary):
		return "No authored objectives."

	var lines := []
	lines.append("Victory")
	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		lines.append("%s %s" % [_objective_marker(true, _objective_met(session, objective)), _objective_label(session, objective)])

	lines.append("Avoid Defeat")
	for objective in objectives.get("defeat", []):
		if not (objective is Dictionary):
			continue
		lines.append("%s %s" % [_objective_marker(false, _objective_met(session, objective)), _objective_label(session, objective)])

	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		lines.append("Outcome: %s" % session.scenario_summary)

	return "\n".join(lines)

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

static func _complete_session(session: SessionStateStoreScript.SessionData, status: String, summary: String) -> Dictionary:
	var pre_completion_snapshot := session.to_dict()
	session.scenario_status = status
	session.scenario_summary = summary
	session.flags["scenario_result"] = status
	if SessionStateStoreScript.normalize_launch_mode(session.launch_mode) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		session.flags["campaign"] = status
		var completion_result: Dictionary = CampaignProgression.record_session_completion(session)
		if not bool(completion_result.get("ok", false)):
			session.from_dict(pre_completion_snapshot)
			return {
				"status": session.scenario_status,
				"message": String(completion_result.get(
					"message",
					"Campaign progression could not be saved. The chapter remains active and will retry completion."
				)),
			}
	return {"status": status, "message": summary}

static func _merge_result_messages(result: Dictionary, prefix_message: String) -> Dictionary:
	var merged := result.duplicate(true)
	var messages := []
	if prefix_message != "":
		messages.append(prefix_message)
	var result_message := String(result.get("message", ""))
	if result_message != "":
		messages.append(result_message)
	merged["message"] = " ".join(messages)
	return merged

static func _progress_recap_status_line(session: SessionStateStoreScript.SessionData, preloaded_objective_surface: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._progress_recap_status_line", [session, preloaded_objective_surface])

static func _progress_recap_next_step_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary, preloaded_objective_surface: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._progress_recap_next_step_line", [session, scenario, preloaded_objective_surface])

static func _last_battle_aftermath_text(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var report = session.flags.get("last_battle_aftermath", {})
	if not (report is Dictionary) or report.is_empty():
		return ""
	var lines := []
	for key in [
		"headline",
		"result_summary",
		"reward_summary",
		"artifact_summary",
		"force_summary",
		"world_summary",
		"summary",
		"resource_summary",
		"army_summary",
		"pressure_summary",
		"recovery_summary",
		"front_summary",
		"logistics_summary",
		"commander_summary",
	]:
		var line := String(report.get(key, "")).strip_edges()
		if line != "" and line not in lines:
			lines.append(line)
	return "\n".join(lines)

static func _resolution_text(scenario: Dictionary, status: String) -> String:
	var objectives = objective_definitions(scenario)
	if objectives is Dictionary:
		var key := "%s_text" % status
		var explicit_text := String(objectives.get(key, ""))
		if explicit_text != "":
			return explicit_text
	return "Scenario %s." % status

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
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _enemy_operational_lines__gd(session, scenario)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules._enemy_operational_lines", [session, scenario])
	var before := HumanEngine.before_writing(&"ScenarioRules._enemy_operational_lines", [session, scenario])
	var result = _enemy_operational_lines__gd(session, scenario)
	HumanEngine.check_writing(&"ScenarioRules._enemy_operational_lines", before, [session, scenario], result)
	return result

static func _enemy_operational_lines__gd(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> Array:
	var lines := []
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		var label := String(config.get("label", ""))
		if label == "":
			label = String(ContentService.get_faction(faction_id).get("name", faction_id))
		# Computer players field heroes and build towns under the same rules.
		var strategy_summary: String = EnemyAdventureRulesScript.public_strategy_summary(config, faction_id)
		var line := "Enemy posture: %s | heroes and towns under the same rules" % label
		if strategy_summary != "":
			line = "%s | %s" % [line, strategy_summary]
		var priority_labels := _priority_target_labels(scenario, config)
		if not priority_labels.is_empty():
			line = "%s | Focus %s" % [line, ", ".join(priority_labels)]
		lines.append(line)
	return lines

static func _opening_objective_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _opening_objective_summary__gd(session, scenario)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules._opening_objective_summary", [session, scenario])
	var before := HumanEngine.before_writing(&"ScenarioRules._opening_objective_summary", [session, scenario])
	var result = _opening_objective_summary__gd(session, scenario)
	HumanEngine.check_writing(&"ScenarioRules._opening_objective_summary", before, [session, scenario], result)
	return result

static func _opening_objective_summary__gd(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var objectives = objective_definitions(scenario)
	if not (objectives is Dictionary):
		return ""
	var lines := []
	var victory_labels := _objective_labels_from_bucket(session, objectives.get("victory", []), 3)
	if not victory_labels.is_empty():
		lines.append("Opening objectives: %s" % "; ".join(victory_labels))
	var defeat_labels := _objective_labels_from_bucket(session, objectives.get("defeat", []), 2)
	if not defeat_labels.is_empty():
		lines.append("Failure watch: %s" % "; ".join(defeat_labels))
	return "\n".join(lines)

static func _first_contact_summary(scenario: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _first_contact_summary__gd(scenario)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules._first_contact_summary", [scenario])
	var before := HumanEngine.before_writing(&"ScenarioRules._first_contact_summary", [scenario])
	var result = _first_contact_summary__gd(scenario)
	HumanEngine.check_writing(&"ScenarioRules._first_contact_summary", before, [scenario], result)
	return result

static func _first_contact_summary__gd(scenario: Dictionary) -> String:
	var contacts := _nearest_encounter_placements(scenario, 3)
	if contacts.is_empty():
		return ""
	var labels := []
	var tag_labels := []
	var trait_labels := []
	for placement in contacts:
		if not (placement is Dictionary):
			continue
		var encounter := ContentService.get_encounter(String(placement.get("encounter_id", "")))
		if encounter.is_empty():
			continue
		labels.append("%s on %s" % [
			String(encounter.get("name", placement.get("encounter_id", "Hostile contact"))),
			_terrain_label(String(encounter.get("terrain", "grass"))),
		])
		for tag_value in encounter.get("battlefield_tags", []):
			var tag_label := _titleize_token(String(tag_value))
			if tag_label != "" and tag_label not in tag_labels:
				tag_labels.append(tag_label)
		for trait_value in encounter.get("enemy_commander", {}).get("battle_traits", []):
			var trait_label := _titleize_token(String(trait_value))
			if trait_label != "" and trait_label not in trait_labels:
				trait_labels.append(trait_label)
	var lines := []
	if not labels.is_empty():
		lines.append("Likely first contact: %s" % ", ".join(labels))
	if not tag_labels.is_empty():
		lines.append("Battlefield identity: %s" % ", ".join(tag_labels.slice(0, min(4, tag_labels.size()))))
	if not trait_labels.is_empty():
		lines.append("Enemy doctrine: %s" % ", ".join(trait_labels.slice(0, min(4, trait_labels.size()))))
	return "\n".join(lines)

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
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _objective_labels_from_bucket__gd(session, bucket, limit)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"ScenarioRules._objective_labels_from_bucket", [session, bucket, limit])
	var before := HumanEngine.before_writing(&"ScenarioRules._objective_labels_from_bucket", [session, bucket, limit])
	var result = _objective_labels_from_bucket__gd(session, bucket, limit)
	HumanEngine.check_writing(&"ScenarioRules._objective_labels_from_bucket", before, [session, bucket, limit], result)
	return result

static func _objective_labels_from_bucket__gd(session: SessionStateStoreScript.SessionData, bucket: Variant, limit: int) -> Array:
	var labels := []
	if not (bucket is Array):
		return labels
	for objective in bucket:
		if not (objective is Dictionary):
			continue
		var label := _objective_label(session, objective)
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= limit:
			break
	return labels

static func _nearest_encounter_placements(scenario: Dictionary, limit: int) -> Array:
	var start: Dictionary = scenario.get("start", {})
	var start_x := int(start.get("x", 0))
	var start_y := int(start.get("y", 0))
	var placements := []
	for placement in scenario.get("encounters", []):
		if not (placement is Dictionary):
			continue
		var entry: Dictionary = placement.duplicate(true)
		entry["distance"] = absi(int(entry.get("x", 0)) - start_x) + absi(int(entry.get("y", 0)) - start_y)
		placements.append(entry)
	placements.sort_custom(func(a, b): return int(a.get("distance", 9999)) < int(b.get("distance", 9999)))
	if placements.size() <= limit:
		return placements
	return placements.slice(0, limit)

static func _priority_target_labels(scenario: Dictionary, config: Dictionary) -> Array:
	var labels := []
	var targets = config.get("priority_target_placement_ids", [])
	if not (targets is Array):
		return labels
	for placement_id_value in targets:
		var label := _placement_label_for_scenario(scenario, String(placement_id_value))
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= 3:
			break
	return labels

static func _placement_label_for_scenario(scenario: Dictionary, placement_id: String) -> String:
	if placement_id == "":
		return ""
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return String(ContentService.get_town(String(town.get("town_id", ""))).get("name", placement_id))
	for node in scenario.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(ContentService.get_resource_site(String(node.get("site_id", ""))).get("name", placement_id))
	for node in scenario.get("artifact_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(ContentService.get_artifact(String(node.get("artifact_id", ""))).get("name", placement_id))
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return String(ContentService.get_encounter(String(encounter.get("encounter_id", ""))).get("name", placement_id))
	return _titleize_token(placement_id)

static func _map_tile_id(map_data: Variant, x: int, y: int) -> String:
	if not (map_data is Array) or y < 0 or y >= map_data.size():
		return ""
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return ""
	return String(row[x])

static func _terrain_label(terrain_id: String) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _terrain_label__gd(terrain_id)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native(&"ScenarioRules._terrain_label", [terrain_id])
	var result = _terrain_label__gd(terrain_id)
	HumanEngine.check(&"ScenarioRules._terrain_label", [terrain_id], result)
	return result

static func _terrain_label__gd(terrain_id: String) -> String:
	var biome := ContentService.get_biome_for_terrain(terrain_id)
	if not biome.is_empty():
		return String(biome.get("name", _titleize_token(terrain_id)))
	return _titleize_token(terrain_id) if terrain_id != "" else "Unknown terrain"

static func _titleize_token(value: String) -> String:
	if value == "":
		return ""
	var words := value.split("_")
	for index in range(words.size()):
		words[index] = String(words[index]).capitalize()
	return " ".join(words)

static func _objective_met(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> bool:
	match String(objective.get("type", "")):
		GeneratedObjectives.KIND:
			return bool(GeneratedObjectives.progress(session).get("complete", false))
		"artifact_owned_by_player":
			return _player_owns_artifact(session, String(objective.get("artifact_id", "")))
		"hero_artifact_set_equipped":
			return bool(_artifact_set_equipment_progress(session, objective).get("complete", false))
		"spell_known_by_player":
			return _player_knows_spell(session, String(objective.get("spell_id", "")))
		"building_built_in_player_town":
			var building_town := _find_town(session, objective)
			return (
				not building_town.is_empty()
				and String(building_town.get("owner", "neutral")) == "player"
				and _town_has_objective_building(building_town, String(objective.get("building_id", "")))
			)
		"hero_stationed_at_player_town":
			return bool(_hero_stationing_progress(session, objective).get("complete", false))
		"reserve_delivery_completed":
			return bool(_reserve_delivery_progress(session, objective).get("complete", false))
		"map_explored_at_least":
			return bool(_map_exploration_progress(session, objective).get("complete", false))
		"resource_stockpile_at_least":
			return bool(_resource_stockpile_progress(session, objective).get("complete", false))
		"resource_sites_controlled_at_least":
			return bool(_resource_site_control_progress(session, objective).get("complete", false))
		"hero_army_meets_requirements":
			return bool(_hero_army_requirement_progress(session, objective).get("complete", false))
		"town_garrison_meets_requirements":
			return bool(_town_garrison_requirement_progress(session, objective).get("complete", false))
		"hero_progression_meets_requirements":
			return bool(_hero_progression_requirement_progress(session, objective).get("complete", false))
		"town_owned_by_player":
			var town := _find_town(session, objective)
			return not town.is_empty() and String(town.get("owner", "neutral")) == "player"
		"town_not_owned_by_player":
			var town := _find_town(session, objective)
			return town.is_empty() or String(town.get("owner", "neutral")) != "player"
		"flag_true":
			return bool(session.flags.get(String(objective.get("flag", "")), false))
		"session_flag_equals":
			return String(session.flags.get(String(objective.get("flag", "")), "")) == String(objective.get("value", ""))
		"enemy_pressure_at_least":
			return _enemy_turn_rules().get_pressure(session, String(objective.get("faction_id", ""))) >= int(objective.get("threshold", 0))
		"encounter_resolved":
			return _scenario_script_rules()._encounter_resolved(session, String(objective.get("placement_id", "")))
		"hook_fired":
			return _scenario_script_rules()._hook_fired(session, String(objective.get("hook_id", "")))
		"day_at_least":
			return session.day >= int(objective.get("day", 0))
		_:
			return false

static func _objective_label(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> String:
	return HumanEngine.native_writing(&"ScenarioRules._objective_label", [session, objective])

static func _hero_stationing_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var hero_id := String(objective.get("hero_id", ""))
	var hero := _controlled_hero_state(session, hero_id)
	var town := _find_town(session, objective)
	var hero_found := not hero.is_empty()
	var town_found := not town.is_empty()
	var town_controlled := town_found and String(town.get("owner", "neutral")) == "player"
	var hero_position = hero.get("position", {}) if hero_found else {}
	var position_matches := (
		hero_position is Dictionary
		and town_found
		and LevelRules.position(hero_position) == LevelRules.town_entrance(town)
	)
	return {
		"hero_id": hero_id,
		"hero_found": hero_found,
		"town_found": town_found,
		"town_controlled": town_controlled,
		"position_matches": position_matches,
		"complete": hero_found and town_controlled and position_matches,
	}

static func _reserve_delivery_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var site_placement_id := String(objective.get("site_placement_id", "")).strip_edges()
	var target_kind := String(objective.get("target_kind", "town")).strip_edges()
	var target_id := String(objective.get("target_id", "")).strip_edges()
	var minimum_count: int = max(1, int(objective.get("minimum_count", 1)))
	var relay: Dictionary = {}
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == site_placement_id:
			relay = node
			break
	var receipt_key := "%s:%s" % [target_kind, target_id]
	var completion_counts: Variant = relay.get("delivery_completion_counts", {}) if not relay.is_empty() else {}
	var completed_count: int = max(0, int(completion_counts.get(receipt_key, 0))) if completion_counts is Dictionary else 0
	return {
		"site_placement_id": site_placement_id,
		"target_kind": target_kind,
		"target_id": target_id,
		"relay_found": not relay.is_empty(),
		"completed_count": completed_count,
		"minimum_count": minimum_count,
		"complete": not relay.is_empty() and completed_count >= minimum_count,
	}

static func _map_exploration_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var minimum_percent: int = clampi(int(objective.get("minimum_percent", 1)), 1, 100)
	var fog: Dictionary = session.overworld.get("fog", {}) if session.overworld.get("fog", {}) is Dictionary else {}
	var map_size: Vector2i = _overworld_rules().derive_map_size(session)
	var expected_total_tiles: int = max(0, map_size.x) * max(0, map_size.y)
	var total_tiles: int = max(0, int(fog.get("total_tiles", expected_total_tiles)))
	if total_tiles != expected_total_tiles:
		total_tiles = expected_total_tiles
	var explored_count: int = clampi(int(fog.get("explored_count", 0)), 0, total_tiles)
	var required_count: int = ceili(float(total_tiles * minimum_percent) / 100.0) if total_tiles > 0 else 1
	var explored_percent: int = int(floor(float(explored_count * 100) / float(total_tiles))) if total_tiles > 0 else 0
	return {
		"explored_count": explored_count,
		"total_tiles": total_tiles,
		"required_count": required_count,
		"explored_percent": explored_percent,
		"minimum_percent": minimum_percent,
		"complete": total_tiles > 0 and explored_count >= required_count,
	}

static func _resource_stockpile_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var authored_requirements = objective.get("requirements", {})
	if not (authored_requirements is Dictionary) or authored_requirements.is_empty():
		return {"requirements": [], "complete": false}
	var resource_ids: Array[String] = []
	for resource_id in authored_requirements.keys():
		resource_ids.append(String(resource_id))
	resource_ids.sort()
	var rows: Array[Dictionary] = []
	var complete := true
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in resource_ids:
		var minimum_count: int = max(1, int(authored_requirements.get(resource_id, 1)))
		var current_count: int = max(0, int(resources.get(resource_id, 0)))
		var resource := ContentService.get_resource(resource_id)
		var met := current_count >= minimum_count
		rows.append({
			"resource_id": resource_id,
			"resource_name": String(resource.get("display_name", resource.get("name", _titleize_token(resource_id)))),
			"current_count": current_count,
			"minimum_count": minimum_count,
			"met": met,
		})
		complete = complete and met
	return {"requirements": rows, "complete": complete}

static func _resource_site_control_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var authored_placement_ids = objective.get("placement_ids", [])
	if not (authored_placement_ids is Array) or authored_placement_ids.is_empty():
		return {"placement_ids": [], "controlled_count": 0, "minimum_count": 1, "complete": false}
	var placement_ids: Array[String] = []
	for placement_id in authored_placement_ids:
		var normalized_id := String(placement_id).strip_edges()
		if normalized_id != "" and normalized_id not in placement_ids:
			placement_ids.append(normalized_id)
	var minimum_count: int = clampi(int(objective.get("minimum_count", placement_ids.size())), 1, max(1, placement_ids.size()))
	var controlled_ids: Array[String] = []
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var placement_id := String(node.get("placement_id", ""))
		if placement_id in placement_ids and String(node.get("collected_by_faction_id", "")) == "player":
			controlled_ids.append(placement_id)
	return {
		"placement_ids": placement_ids,
		"controlled_placement_ids": controlled_ids,
		"controlled_count": controlled_ids.size(),
		"minimum_count": minimum_count,
		"complete": controlled_ids.size() >= minimum_count,
	}

static func _hero_army_requirement_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var hero_id := String(objective.get("hero_id", ""))
	var army := _controlled_hero_army(session, hero_id)
	var requirements = objective.get("requirements", [])
	var rows := []
	var ready_count := 0
	if requirements is Array:
		for requirement in requirements:
			if not (requirement is Dictionary):
				continue
			var unit_id := String(requirement.get("unit_id", ""))
			var minimum_count: int = max(1, int(requirement.get("minimum_count", 0)))
			var current_count: int = _army_unit_count(army, unit_id)
			var met: bool = current_count >= minimum_count
			if met:
				ready_count += 1
			var unit := ContentService.get_unit(unit_id)
			rows.append({
				"unit_id": unit_id,
				"unit_name": String(unit.get("name", unit_id)),
				"minimum_count": minimum_count,
				"current_count": current_count,
				"met": met,
			})
	return {
		"hero_id": hero_id,
		"hero_found": not army.is_empty(),
		"requirement_count": rows.size(),
		"ready_count": ready_count,
		"requirements": rows,
		"complete": not rows.is_empty() and not army.is_empty() and ready_count == rows.size(),
	}

static func _town_garrison_requirement_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var town := _find_town(session, objective)
	var requirements = objective.get("requirements", [])
	var rows := []
	var ready_count := 0
	var garrison_army := {
		"stacks": town.get("garrison", []) if not town.is_empty() and town.get("garrison", []) is Array else [],
	}
	if requirements is Array:
		for requirement in requirements:
			if not (requirement is Dictionary):
				continue
			var unit_id := String(requirement.get("unit_id", ""))
			var minimum_count: int = max(1, int(requirement.get("minimum_count", 0)))
			var current_count: int = _army_unit_count(garrison_army, unit_id)
			var met: bool = current_count >= minimum_count
			if met:
				ready_count += 1
			var unit := ContentService.get_unit(unit_id)
			rows.append({
				"unit_id": unit_id,
				"unit_name": String(unit.get("name", unit_id)),
				"minimum_count": minimum_count,
				"current_count": current_count,
				"met": met,
			})
	var town_controlled := not town.is_empty() and String(town.get("owner", "neutral")) == "player"
	return {
		"placement_id": String(objective.get("placement_id", "")),
		"town_found": not town.is_empty(),
		"town_controlled": town_controlled,
		"requirement_count": rows.size(),
		"ready_count": ready_count,
		"requirements": rows,
		"complete": not rows.is_empty() and town_controlled and ready_count == rows.size(),
	}

static func _artifact_set_equipment_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var hero_id := String(objective.get("hero_id", ""))
	var set_id := String(objective.get("set_id", ""))
	var hero := _controlled_hero_state(session, hero_id)
	var artifact_set := ArtifactRulesScript.artifact_set_record(set_id)
	var piece_ids = artifact_set.get("piece_ids", [])
	var result := {
		"hero_id": hero_id,
		"set_id": set_id,
		"set_name": String(artifact_set.get("name", set_id)),
		"hero_found": not hero.is_empty(),
		"piece_count": piece_ids.size() if piece_ids is Array else 0,
		"equipped_piece_count": 0,
		"equipped_piece_ids": [],
		"complete": false,
	}
	if hero.is_empty() or artifact_set.is_empty():
		return result
	for set_state_value in ArtifactRulesScript.artifact_set_runtime_state(hero):
		if not (set_state_value is Dictionary):
			continue
		var set_state: Dictionary = set_state_value
		if String(set_state.get("set_id", "")) != set_id:
			continue
		result["equipped_piece_count"] = int(set_state.get("equipped_piece_count", 0))
		result["equipped_piece_ids"] = set_state.get("equipped_piece_ids", []).duplicate()
		result["complete"] = bool(set_state.get("complete", false))
		break
	return result

static func _hero_progression_requirement_progress(
	session: SessionStateStoreScript.SessionData,
	objective: Dictionary
) -> Dictionary:
	var hero_id := String(objective.get("hero_id", ""))
	var hero := _controlled_hero_state(session, hero_id)
	var minimum_level: int = max(1, int(objective.get("minimum_level", 1)))
	var minimum_resolved_choice_count: int = max(0, int(objective.get("minimum_resolved_specialty_choices", 0)))
	var current_level: int = max(1, int(hero.get("level", 1))) if not hero.is_empty() else 0
	var specialties = hero.get("specialties", [])
	var starting_specialties = ContentService.get_hero(hero_id).get("starting_specialties", [])
	var starting_specialty_count: int = starting_specialties.size() if starting_specialties is Array else 0
	var resolved_choice_count: int = max(0, (specialties.size() if specialties is Array else 0) - starting_specialty_count)
	var pending_choices = hero.get("pending_specialty_choices", [])
	var pending_choice_count: int = pending_choices.size() if pending_choices is Array else 0
	var require_no_pending_choices := bool(objective.get("require_no_pending_specialty_choices", false))
	return {
		"hero_id": hero_id,
		"hero_found": not hero.is_empty(),
		"minimum_level": minimum_level,
		"current_level": current_level,
		"minimum_resolved_choice_count": minimum_resolved_choice_count,
		"resolved_choice_count": resolved_choice_count,
		"starting_specialty_count": starting_specialty_count,
		"require_no_pending_choices": require_no_pending_choices,
		"pending_choice_count": pending_choice_count,
		"complete": (
			not hero.is_empty()
			and current_level >= minimum_level
			and resolved_choice_count >= minimum_resolved_choice_count
			and (not require_no_pending_choices or pending_choice_count == 0)
		),
	}

static func _controlled_hero_state(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	if active_hero_id == hero_id:
		var active_hero = session.overworld.get("hero", {})
		if active_hero is Dictionary and String(active_hero.get("id", active_hero_id)) == hero_id:
			return active_hero
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return {}
	for hero in heroes:
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return hero
	return {}

static func _controlled_hero_army(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	if active_hero_id == hero_id:
		var active_army = session.overworld.get("army", {})
		if active_army is Dictionary:
			return active_army
	var hero := _controlled_hero_state(session, hero_id)
	var hero_army = hero.get("army", {})
	return hero_army if hero_army is Dictionary else {}

static func _army_unit_count(army: Dictionary, unit_id: String) -> int:
	if army.is_empty() or unit_id == "":
		return 0
	var total := 0
	var stacks = army.get("stacks", [])
	if not (stacks is Array):
		return 0
	for stack in stacks:
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += max(0, int(stack.get("count", 0)))
	return total

static func _player_owns_artifact(session: SessionStateStoreScript.SessionData, artifact_id: String) -> bool:
	if session == null or artifact_id == "":
		return false
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary and ArtifactRulesScript.has_artifact(active_hero, artifact_id):
		return true
	var active_hero_id := String(session.overworld.get("active_hero_id", active_hero.get("id", "") if active_hero is Dictionary else ""))
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return false
	for hero in heroes:
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		if ArtifactRulesScript.has_artifact(hero, artifact_id):
			return true
	return false

static func _player_knows_spell(session: SessionStateStoreScript.SessionData, spell_id: String) -> bool:
	if session == null or spell_id == "":
		return false
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary and SpellRulesScript.knows_spell(active_hero, spell_id):
		return true
	var active_hero_id := String(session.overworld.get("active_hero_id", active_hero.get("id", "") if active_hero is Dictionary else ""))
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return false
	for hero in heroes:
		if not (hero is Dictionary) or String(hero.get("id", "")) == active_hero_id:
			continue
		if SpellRulesScript.knows_spell(hero, spell_id):
			return true
	return false

static func _objective_marker(is_victory: bool, met: bool) -> String:
	if is_victory:
		return "[x]" if met else "[ ]"
	return "[!]" if met else "[ ]"

static func _town_has_objective_building(town: Dictionary, building_id: String) -> bool:
	if building_id == "":
		return false
	var built = town.get("built_buildings", [])
	if not (built is Array):
		return false
	if building_id in built:
		return true
	# Current-development towns store only the active stage of each building
	# line under current ids. Map older objective ids through the faction's
	# migration table and accept any later stage of that line.
	var migration: Dictionary = TownDevelopmentRulesScript.data().get("migration", {}).get(
		TownDevelopmentRulesScript.faction_id(town),
		{}
	)
	var required := String(migration.get(building_id, building_id))
	return TownDevelopmentRulesScript.satisfies(built, required)

static func _find_town(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> Dictionary:
	var placement_id := String(objective.get("placement_id", ""))
	var town_id := String(objective.get("town_id", ""))
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if placement_id != "" and String(town.get("placement_id", "")) == placement_id:
			return town
		if town_id != "" and String(town.get("town_id", "")) == town_id:
			return town
	return {}

static func _objective_progress_counts(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioRules._objective_progress_counts", [session])
