class_name ScenarioRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")

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

static func normalize_scenario_state(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if session.scenario_status == "":
		session.scenario_status = "in_progress"
	if session.scenario_summary == "":
		session.scenario_summary = ""
	_scenario_script_rules().normalize_script_state(session)
	_enemy_turn_rules().normalize_enemy_states(session)

static func evaluate_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_scenario_state(session)
	if session == null or session.scenario_id == "":
		return {"status": "invalid", "message": ""}
	if session.scenario_status != "in_progress":
		return {"status": session.scenario_status, "message": session.scenario_summary}

	var scenario := ContentService.get_scenario(session.scenario_id)
	var script_result: Dictionary = _scenario_script_rules().process_hooks(session)
	var script_message := String(script_result.get("message", ""))
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return {"status": "in_progress", "message": script_message}

	var defeat_objectives = objectives.get("defeat", [])
	if defeat_objectives is Array:
		for objective in defeat_objectives:
			if objective is Dictionary and _objective_met(session, objective):
				return _merge_result_messages(
					_complete_session(session, "defeat", _resolution_text(scenario, "defeat")),
					script_message
				)

	var victory_objectives = objectives.get("victory", [])
	if victory_objectives is Array and not victory_objectives.is_empty():
		var all_met := true
		for objective in victory_objectives:
			if not (objective is Dictionary) or not _objective_met(session, objective):
				all_met = false
				break
		if all_met:
			return _merge_result_messages(
				_complete_session(session, "victory", _resolution_text(scenario, "victory")),
				script_message
			)

	return {"status": "in_progress", "message": script_message}

static func evaluate_session_for_event(session: SessionStateStoreScript.SessionData, event_facts: Dictionary = {}) -> Dictionary:
	normalize_scenario_state(session)
	var profile := _scenario_event_dependency_profile(session, event_facts)
	if session == null or session.scenario_id == "":
		profile["dependency_mode"] = "full_fallback_unknown"
		profile["fallback_reason"] = "missing_session_or_scenario"
		return {"status": "invalid", "message": "", "profile": profile}

	if session.scenario_status != "in_progress":
		profile["dependency_mode"] = "full_fallback_not_in_progress"
		profile["fallback_reason"] = "scenario_not_in_progress"
		var inactive_result := evaluate_session(session)
		inactive_result["profile"] = profile
		return inactive_result

	var scenario := ContentService.get_scenario(session.scenario_id)
	if event_facts.is_empty() or bool(event_facts.get("requires_full_scenario_eval", false)):
		profile["dependency_mode"] = "full"
		profile["fallback_reason"] = String(event_facts.get("fallback_reason", "no_event_facts"))
		profile["fallback_used"] = true
		var full_result := evaluate_session(session)
		full_result["profile"] = profile
		return full_result

	var dependency := _scenario_dependency_metadata(scenario)
	profile["objective_count"] = int(dependency.get("objective_count", 0))
	profile["hook_count"] = int(dependency.get("hook_count", 0))
	profile["dependency_metadata_known"] = bool(dependency.get("known", false))
	if not bool(dependency.get("known", false)):
		profile["dependency_mode"] = "full_fallback_unknown"
		profile["fallback_reason"] = String(dependency.get("unknown_reason", "unknown_dependency"))
		profile["fallback_used"] = true
		var unknown_result := evaluate_session(session)
		unknown_result["profile"] = profile
		return unknown_result

	var event_dependency := _scenario_event_dependency(event_facts)
	if bool(event_dependency.get("broad", false)):
		profile["dependency_mode"] = "full_fallback_unknown"
		profile["fallback_reason"] = String(event_dependency.get("reason", "broad_event"))
		profile["fallback_used"] = true
		var broad_result := evaluate_session(session)
		broad_result["profile"] = profile
		return broad_result

	if int(profile.get("objective_count", 0)) == 0 and int(profile.get("hook_count", 0)) == 0:
		profile["dependency_mode"] = "event_gated_skip"
		profile["skip_reason"] = "no_observable_dependencies"
		profile["fallback_reason"] = ""
		return {"status": session.scenario_status, "message": "", "profile": profile}

	if bool(scenario.get("generated", false)):
		profile["dependency_mode"] = "full_fallback_generated"
		profile["fallback_reason"] = "generated_scenario_dependencies"
		profile["fallback_used"] = true
		profile["objectives_checked"] = int(profile.get("objective_count", 0))
		profile["hooks_checked"] = int(profile.get("hook_count", 0))
		var generated_result := evaluate_session(session)
		generated_result["profile"] = profile
		return generated_result

	var affected_objectives := 0
	var objectives: Array = dependency.get("objectives", []) if dependency.get("objectives", []) is Array else []
	for objective_dependency in objectives:
		if objective_dependency is Dictionary and _scenario_event_affects_dependency(event_dependency, objective_dependency):
			affected_objectives += 1
	var affected_hooks := 0
	var hooks: Array = dependency.get("hooks", []) if dependency.get("hooks", []) is Array else []
	for hook_dependency in hooks:
		if hook_dependency is Dictionary and _scenario_event_affects_dependency(event_dependency, hook_dependency):
			affected_hooks += 1

	profile["objectives_checked"] = affected_objectives
	profile["objectives_skipped"] = maxi(0, int(profile.get("objective_count", 0)) - affected_objectives)
	profile["hooks_checked"] = affected_hooks
	profile["hooks_skipped"] = maxi(0, int(profile.get("hook_count", 0)) - affected_hooks)
	profile["affected_objective_count"] = affected_objectives
	profile["affected_hook_count"] = affected_hooks
	if affected_objectives <= 0 and affected_hooks <= 0:
		profile["dependency_mode"] = "event_gated_skip"
		profile["fallback_reason"] = ""
		return {"status": session.scenario_status, "message": "", "profile": profile}

	profile["dependency_mode"] = "scoped"
	profile["fallback_reason"] = ""
	profile["semantic_evaluation"] = "full_existing_evaluator_for_affected_dependencies"
	var scoped_result := evaluate_session(session)
	scoped_result["profile"] = profile
	return scoped_result

static func _scenario_event_dependency_profile(session: SessionStateStoreScript.SessionData, event_facts: Dictionary) -> Dictionary:
	return {
		"dependency_mode": "full",
		"fallback_reason": "",
		"event_type": String(event_facts.get("event_type", event_facts.get("event", ""))),
		"event_family": String(event_facts.get("family", "")),
		"objective_count": 0,
		"hook_count": 0,
		"objectives_checked": 0,
		"objectives_skipped": 0,
		"hooks_checked": 0,
		"hooks_skipped": 0,
		"affected_objective_count": 0,
		"affected_hook_count": 0,
		"dependency_metadata_known": false,
		"fallback_used": false,
		"skip_reason": "",
	}

static func _scenario_dependency_metadata(scenario: Dictionary) -> Dictionary:
	var result := {
		"known": true,
		"unknown_reason": "",
		"objective_count": 0,
		"hook_count": 0,
		"objectives": [],
		"hooks": [],
	}
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var objective_index := {}
		for bucket_name in ["victory", "defeat"]:
			var bucket = objectives.get(bucket_name, [])
			if not (bucket is Array):
				continue
			for objective in bucket:
				if objective is Dictionary:
					var objective_id := String(objective.get("id", ""))
					if objective_id != "":
						objective_index[objective_id] = objective
		for bucket_name in ["victory", "defeat"]:
			var bucket = objectives.get(bucket_name, [])
			if not (bucket is Array):
				continue
			for objective in bucket:
				if not (objective is Dictionary):
					var unknown_objective_dependency := _empty_dependency()
					unknown_objective_dependency["known"] = false
					unknown_objective_dependency["unknown_reason"] = "objective_not_dictionary"
					result["known"] = false
					result["unknown_reason"] = "objective_not_dictionary"
					result["objective_count"] = int(result.get("objective_count", 0)) + 1
					result["objectives"].append(unknown_objective_dependency)
					continue
				var objective_dependency := _scenario_objective_dependency(objective, objective_index, {})
				if not bool(objective_dependency.get("known", false)):
					result["known"] = false
					result["unknown_reason"] = String(objective_dependency.get("unknown_reason", "unsupported_objective"))
				result["objective_count"] = int(result.get("objective_count", 0)) + 1
				result["objectives"].append(objective_dependency)
	elif scenario.has("objectives"):
		result["known"] = false
		result["unknown_reason"] = "objectives_not_dictionary"

	var raw_hooks = scenario.get("script_hooks", [])
	if raw_hooks is Array:
		for hook in raw_hooks:
			if not (hook is Dictionary):
				var unknown_hook_dependency := _empty_dependency()
				unknown_hook_dependency["known"] = false
				unknown_hook_dependency["unknown_reason"] = "hook_not_dictionary"
				result["known"] = false
				result["unknown_reason"] = "hook_not_dictionary"
				result["hook_count"] = int(result.get("hook_count", 0)) + 1
				result["hooks"].append(unknown_hook_dependency)
				continue
			var hook_dependency := _scenario_hook_dependency(hook, result.get("objectives", []), objectives)
			if not bool(hook_dependency.get("known", false)):
				result["known"] = false
				result["unknown_reason"] = String(hook_dependency.get("unknown_reason", "unsupported_hook"))
			result["hook_count"] = int(result.get("hook_count", 0)) + 1
			result["hooks"].append(hook_dependency)
	elif scenario.has("script_hooks"):
		result["known"] = false
		result["unknown_reason"] = "script_hooks_not_array"
	return result

static func _scenario_objective_dependency(objective: Dictionary, objective_index: Dictionary, seen: Dictionary) -> Dictionary:
	var dependency := _empty_dependency()
	dependency["id"] = String(objective.get("id", ""))
	match String(objective.get("type", "")):
		"town_owned_by_player", "town_not_owned_by_player":
			_add_dependency_value(dependency, "town_placement_ids", String(objective.get("placement_id", "")))
			_add_dependency_value(dependency, "town_ids", String(objective.get("town_id", "")))
		"flag_true", "session_flag_equals":
			_add_dependency_value(dependency, "flags", String(objective.get("flag", "")))
		"enemy_pressure_at_least":
			_add_dependency_value(dependency, "enemy_pressure_faction_ids", String(objective.get("faction_id", "")))
		"encounter_resolved":
			_add_dependency_value(dependency, "encounter_placement_ids", String(objective.get("placement_id", "")))
		"hook_fired":
			_add_dependency_value(dependency, "hook_ids", String(objective.get("hook_id", "")))
		"day_at_least":
			dependency["day"] = true
		_:
			dependency["known"] = false
			dependency["unknown_reason"] = "unsupported_objective_type:%s" % String(objective.get("type", ""))
	return dependency

static func _scenario_hook_dependency(hook: Dictionary, objective_dependencies: Array, objectives: Variant) -> Dictionary:
	var dependency := _empty_dependency()
	dependency["id"] = String(hook.get("id", ""))
	var conditions = hook.get("conditions", [])
	if not (conditions is Array):
		dependency["known"] = false
		dependency["unknown_reason"] = "hook_conditions_not_array"
		return dependency
	if conditions.is_empty():
		return dependency
	var objective_index := {}
	if objectives is Dictionary:
		for bucket_name in ["victory", "defeat"]:
			var bucket = objectives.get(bucket_name, [])
			if not (bucket is Array):
				continue
			for objective in bucket:
				if objective is Dictionary and String(objective.get("id", "")) != "":
					objective_index[String(objective.get("id", ""))] = objective
	for condition in conditions:
		if not (condition is Dictionary):
			dependency["known"] = false
			dependency["unknown_reason"] = "hook_condition_not_dictionary"
			continue
		var condition_dependency := _scenario_condition_dependency(condition, objective_index)
		_merge_dependency(dependency, condition_dependency)
	return dependency

static func _scenario_condition_dependency(condition: Dictionary, objective_index: Dictionary) -> Dictionary:
	var dependency := _empty_dependency()
	match String(condition.get("type", "")):
		"day_at_least":
			dependency["day"] = true
		"town_owned_by_player", "town_not_owned_by_player":
			_add_dependency_value(dependency, "town_placement_ids", String(condition.get("placement_id", "")))
			_add_dependency_value(dependency, "town_ids", String(condition.get("town_id", "")))
		"flag_true", "session_flag_equals":
			_add_dependency_value(dependency, "flags", String(condition.get("flag", "")))
		"enemy_pressure_at_least":
			_add_dependency_value(dependency, "enemy_pressure_faction_ids", String(condition.get("faction_id", "")))
		"encounter_resolved":
			_add_dependency_value(dependency, "encounter_placement_ids", String(condition.get("placement_id", "")))
		"objective_met", "objective_not_met":
			var objective_id := String(condition.get("objective_id", ""))
			var objective = objective_index.get(objective_id, {})
			if objective is Dictionary and not objective.is_empty():
				_merge_dependency(dependency, _scenario_objective_dependency(objective, objective_index, {objective_id: true}))
			else:
				dependency["known"] = false
				dependency["unknown_reason"] = "hook_objective_dependency_missing:%s" % objective_id
		"active_raid_count_at_least", "active_raid_count_at_most":
			_add_dependency_value(dependency, "active_raid_faction_ids", String(condition.get("faction_id", "")))
		"hook_fired", "hook_not_fired":
			_add_dependency_value(dependency, "hook_ids", String(condition.get("hook_id", "")))
		_:
			dependency["known"] = false
			dependency["unknown_reason"] = "unsupported_hook_condition_type:%s" % String(condition.get("type", ""))
	return dependency

static func _empty_dependency() -> Dictionary:
	return {
		"known": true,
		"unknown_reason": "",
		"town_placement_ids": [],
		"town_ids": [],
		"flags": [],
		"enemy_pressure_faction_ids": [],
		"active_raid_faction_ids": [],
		"encounter_placement_ids": [],
		"hook_ids": [],
		"resources": [],
		"artifact_ids": [],
		"day": false,
	}

static func _scenario_event_dependency(event_facts: Dictionary) -> Dictionary:
	var dependency := _empty_dependency()
	if bool(event_facts.get("broad", false)):
		dependency["broad"] = true
		dependency["reason"] = String(event_facts.get("fallback_reason", "broad_event"))
		return dependency
	for key in [
		"town_placement_ids",
		"town_ids",
		"flags",
		"enemy_pressure_faction_ids",
		"active_raid_faction_ids",
		"encounter_placement_ids",
		"hook_ids",
		"resources",
		"artifact_ids",
	]:
		for value in _string_array(event_facts.get(key, [])):
			_add_dependency_value(dependency, key, value)
	dependency["day"] = bool(event_facts.get("day_changed", false))
	return dependency

static func _scenario_event_affects_dependency(event_dependency: Dictionary, dependency: Dictionary) -> bool:
	if not bool(dependency.get("known", false)):
		return true
	if bool(event_dependency.get("day", false)) and bool(dependency.get("day", false)):
		return true
	for key in [
		"town_placement_ids",
		"town_ids",
		"flags",
		"enemy_pressure_faction_ids",
		"active_raid_faction_ids",
		"encounter_placement_ids",
		"hook_ids",
		"resources",
		"artifact_ids",
	]:
		if _arrays_intersect(event_dependency.get(key, []), dependency.get(key, [])):
			return true
	return false

static func _merge_dependency(target: Dictionary, source: Dictionary) -> void:
	if not bool(source.get("known", false)):
		target["known"] = false
		target["unknown_reason"] = String(source.get("unknown_reason", "unknown_dependency"))
	for key in [
		"town_placement_ids",
		"town_ids",
		"flags",
		"enemy_pressure_faction_ids",
		"active_raid_faction_ids",
		"encounter_placement_ids",
		"hook_ids",
		"resources",
		"artifact_ids",
	]:
		for value in _string_array(source.get(key, [])):
			_add_dependency_value(target, key, value)
	if bool(source.get("day", false)):
		target["day"] = true

static func _add_dependency_value(dependency: Dictionary, key: String, value: String) -> void:
	var normalized := value.strip_edges()
	if normalized == "":
		return
	var values: Array = dependency.get(key, []) if dependency.get(key, []) is Array else []
	if normalized not in values:
		values.append(normalized)
	dependency[key] = values

static func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	else:
		var text := String(value).strip_edges()
		if text != "":
			result.append(text)
	return result

static func _arrays_intersect(left: Variant, right: Variant) -> bool:
	if not (left is Array) or not (right is Array):
		return false
	for value in left:
		if value in right:
			return true
	return false

static func is_objective_met(
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
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
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
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
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
	var scenario := ContentService.get_scenario(scenario_id)
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

	var scenario := ContentService.get_scenario(session.scenario_id)
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

	var objectives = scenario.get("objectives", {})
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

static func describe_session_progress_recap(
	session: SessionStateStoreScript.SessionData,
	include_header: bool = true
) -> String:
	if session == null or session.scenario_id == "":
		return "Progress Recap\nNo active scenario progress is available." if include_header else ""
	_overworld_rules().normalize_overworld_state(session)
	normalize_scenario_state(session)
	var scenario := ContentService.get_scenario(session.scenario_id)
	if scenario.is_empty():
		return "Progress Recap\nScenario progress is unavailable." if include_header else ""

	var lines := []
	if include_header:
		lines.append("Progress Recap")
	var context_line := _progress_recap_context_line(session, scenario)
	if context_line != "":
		lines.append(context_line)
	var status_line := _progress_recap_status_line(session)
	if status_line != "":
		lines.append(status_line)
	var recent_line := _progress_recap_recent_line(session, scenario)
	if recent_line != "":
		lines.append(recent_line)
	var next_step_line := _progress_recap_next_step_line(session, scenario)
	if next_step_line != "":
		lines.append(next_step_line)
	return "\n".join(lines)

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
	var scenario := ContentService.get_scenario(session.scenario_id)
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
	normalize_scenario_state(session)
	if session == null or session.scenario_id == "":
		return {
			"header": "No Scenario Outcome",
			"summary": "No resolved scenario is active.",
			"mode_summary": "",
			"hero_summary": "",
			"army_summary": "",
			"resource_summary": "",
			"progression_summary": "",
			"campaign_arc_summary": "",
			"carryover_summary": "",
			"aftermath_summary": "",
			"journal_summary": "",
			"post_result_handoff_summary": "Post-result handoff: no resolved scenario is active.",
			"action_cue_summary": "Action cue: return to the menu and choose a campaign, skirmish, save, or guide entry.",
			"actions": [{"id": "return_to_menu", "label": "Return to Menu", "summary": "Return to the main menu.", "disabled": false}],
		}

	_overworld_rules().normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(session.scenario_id)
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	var status_label := String(session.scenario_status).capitalize()
	var model := {
		"header": "%s | %s" % [status_label, String(scenario.get("name", session.scenario_id))],
		"summary": session.scenario_summary if session.scenario_summary != "" else "Scenario resolution recorded.",
		"mode_summary": "%s | %s | Day %d" % [
			_scenario_select_rules().launch_mode_label(launch_mode),
			_scenario_select_rules().difficulty_label(session.difficulty),
			session.day,
		],
		"hero_summary": _overworld_rules().describe_hero(session),
		"army_summary": _overworld_rules().describe_army(session),
		"resource_summary": _overworld_rules().describe_resources(session),
		"progression_summary": "",
		"campaign_arc_summary": "",
		"carryover_summary": "",
		"aftermath_summary": "",
		"journal_summary": "",
		"next_step_summary": "",
		"next_play_action_summary": "",
		"continuity_choice_summary": "",
		"post_result_handoff_summary": "",
		"action_cue_summary": "",
		"actions": [],
	}
	var progress_recap := describe_session_progress_recap(session, true)
	var next_step := _progress_recap_next_step_line(session, scenario)
	model["next_step_summary"] = next_step
	model["next_play_action_summary"] = _outcome_next_play_action_line(session, scenario)

	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var recap := CampaignProgression.outcome_recap(session)
		model["continuity_choice_summary"] = CampaignProgression.outcome_continuity_choice(session)
		var progression_lines := []
		if progress_recap != "":
			progression_lines.append(progress_recap)
		var campaign_progression := String(recap.get("progression_summary", ""))
		if campaign_progression != "":
			progression_lines.append(campaign_progression)
		model["progression_summary"] = "\n".join(progression_lines)
		model["campaign_arc_summary"] = String(recap.get("campaign_arc_summary", ""))
		model["carryover_summary"] = String(recap.get("carryover_summary", ""))
		model["aftermath_summary"] = String(recap.get("aftermath_summary", ""))
		model["journal_summary"] = String(recap.get("journal_summary", ""))
		model["actions"] = CampaignProgression.outcome_actions(session)
	else:
		var skirmish_lines := []
		if progress_recap != "":
			skirmish_lines.append(progress_recap)
		skirmish_lines.append_array(
			[
				"Skirmish results are self-contained and do not change campaign progression.",
				"Final state: %s | Hero, army, and resources shown above are the surviving expedition snapshot." % status_label,
			]
		)
		model["progression_summary"] = "\n".join(skirmish_lines)
		model["campaign_arc_summary"] = "Campaign arc closure is only tracked for launched campaign chapters."
		model["carryover_summary"] = "Skirmish runs do not import or export campaign carryover."
		model["aftermath_summary"] = _build_skirmish_aftermath_summary(session, scenario)
		model["journal_summary"] = "Campaign chronicle updates are only recorded for launched campaign chapters."
		model["continuity_choice_summary"] = _skirmish_outcome_continuity_choice_line(session)
		model["actions"] = _build_skirmish_outcome_actions(session)
	model["actions"] = _decorate_outcome_actions(session, scenario, model["actions"])
	model["post_result_handoff_summary"] = _outcome_post_result_handoff_line(session, scenario, model["actions"])
	model["action_cue_summary"] = _outcome_action_cue_line(session, scenario, model["actions"])
	return model

static func perform_outcome_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	if action_id == "" or action_id == "return_to_menu":
		return {"ok": true, "route": "main_menu", "message": ""}

	if action_id.begins_with("campaign_start:"):
		var scenario_id := action_id.trim_prefix("campaign_start:")
		var campaign_id := CampaignProgression.campaign_id_for_session(session)
		var next_session := CampaignProgression.start_scenario(scenario_id, session.difficulty, campaign_id)
		if next_session.scenario_id == "":
			return {"ok": false, "route": "stay", "message": "The requested campaign chapter could not be started."}
		return {"ok": true, "route": "overworld", "message": ""}

	if action_id.begins_with("skirmish_start:"):
		var skirmish_session: SessionStateStoreScript.SessionData = _scenario_select_rules().start_skirmish_session(action_id.trim_prefix("skirmish_start:"), session.difficulty)
		if skirmish_session.scenario_id == "":
			return {"ok": false, "route": "stay", "message": "The requested skirmish could not be started."}
		return {"ok": true, "route": "overworld", "message": ""}

	return {"ok": false, "route": "stay", "message": "That outcome action is not supported."}

static func _complete_session(session: SessionStateStoreScript.SessionData, status: String, summary: String) -> Dictionary:
	session.scenario_status = status
	session.scenario_summary = summary
	session.flags["scenario_result"] = status
	if SessionStateStoreScript.normalize_launch_mode(session.launch_mode) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		session.flags["campaign"] = status
		CampaignProgression.record_session_completion(session)
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

static func _build_skirmish_outcome_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return [
		{
			"id": "skirmish_start:%s" % session.scenario_id,
			"label": "Retry Skirmish",
			"summary": "Launch this authored scenario again at %s difficulty." % _scenario_select_rules().difficulty_label(session.difficulty),
			"disabled": false,
		},
		{
			"id": "return_to_menu",
			"label": "Return to Menu",
			"summary": "Return to the play, guide, settings, and saves shell.",
			"disabled": false,
		},
	]

static func _decorate_outcome_actions(session: SessionStateStoreScript.SessionData, scenario: Dictionary, actions: Array) -> Array:
	var decorated := []
	for action in actions:
		if not (action is Dictionary):
			continue
		var action_copy: Dictionary = action.duplicate(true)
		var cue := _outcome_action_cue_text(session, scenario, action_copy)
		if cue != "":
			action_copy["action_cue"] = cue
			var summary := String(action_copy.get("summary", "")).strip_edges()
			action_copy["summary"] = "%s\nAction cue: %s" % [summary, cue] if summary != "" else "Action cue: %s" % cue
		decorated.append(action_copy)
	return decorated

static func _outcome_action_cue_text(session: SessionStateStoreScript.SessionData, scenario: Dictionary, action: Dictionary) -> String:
	if bool(action.get("disabled", false)):
		return "This is informational; choose another available outcome action or return to the menu."
	var action_id := String(action.get("id", ""))
	if action_id == "" or action_id == "return_to_menu":
		return "Autosaves this outcome, then opens the menu so Continue Latest can return here."
	if action_id.begins_with("skirmish_start:"):
		return "Starts this skirmish fresh; save first if you want this outcome available later."
	if action_id.begins_with("campaign_start:"):
		var target_scenario_id := action_id.trim_prefix("campaign_start:")
		if target_scenario_id == session.scenario_id:
			if session.scenario_status == "victory":
				return "Replays this chapter fresh; save first if you want this outcome available later."
			return "Retries this chapter fresh; save first if you want this outcome available later."
		var target_scenario := ContentService.get_scenario(target_scenario_id)
		var target_name := String(target_scenario.get("name", target_scenario_id))
		if target_name != "":
			return "Starts %s at current difficulty; save this outcome first to keep the handoff." % target_name
		return "Starts the next campaign chapter; save this outcome first to keep the handoff."
	return ""

static func _outcome_action_cue_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary, actions: Array) -> String:
	var enabled_labels := []
	for action in actions:
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var label := String(action.get("label", "")).strip_edges()
		if label != "":
			enabled_labels.append(label)
	if enabled_labels.is_empty():
		return "Action cue: no follow-up action is available; use Return to Menu from the save panel."
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var next_chapter := _next_campaign_chapter_label(session, scenario)
		if session.scenario_status == "victory" and next_chapter != "":
			return "Action cue: save first; start %s to continue, replay this chapter to practice, or return to the campaign board." % next_chapter
		if session.scenario_status == "victory":
			return "Action cue: save first; replay this chapter if needed, or return to the campaign board for the next available choice."
		return "Action cue: save first; retry this chapter fresh, or return to the campaign board and saves."
	if session.scenario_status == "victory":
		return "Action cue: save first; Return to Menu keeps this outcome resumable, while Retry Skirmish starts fresh."
	return "Action cue: save first; Retry Skirmish starts fresh, while Return to Menu keeps this outcome resumable."

static func _outcome_post_result_handoff_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary, actions: Array) -> String:
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	var save_label := "Save Outcome"
	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var primary_label := _first_enabled_outcome_action_label(actions, "return_to_menu")
		if session.scenario_status == "victory":
			var next_chapter := _next_campaign_chapter_label(session, scenario)
			if next_chapter != "":
				var start_label := primary_label if primary_label != "" else "Start %s" % next_chapter
				return "Post-result handoff: campaign progression is already recorded in the profile; %s keeps this review, and %s begins a fresh campaign chapter from that record." % [
					save_label,
					start_label,
				]
			return "Post-result handoff: campaign progression is already recorded in the profile; %s keeps this review, and Return to Menu opens the campaign board for replay or another arc." % save_label
		var retry_label := primary_label if primary_label != "" else "Retry Chapter"
		return "Post-result handoff: defeat is review-only for campaign progression; %s keeps this review, and %s starts the chapter fresh without banking carryover." % [
			save_label,
			retry_label,
		]
	var retry_label := _first_enabled_outcome_action_label(actions, "return_to_menu")
	if retry_label == "":
		retry_label = "Retry Skirmish"
	return "Post-result handoff: this skirmish result is review-only; %s keeps this outcome review, %s starts a fresh run, and campaign progression stays unchanged." % [
		save_label,
		retry_label,
	]

static func _first_enabled_outcome_action_label(actions: Array, excluded_id: String = "") -> String:
	for action in actions:
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var action_id := String(action.get("id", ""))
		if excluded_id != "" and action_id == excluded_id:
			continue
		var label := String(action.get("label", "")).strip_edges()
		if label != "":
			return label
	return ""

static func _skirmish_outcome_continuity_choice_line(session: SessionStateStoreScript.SessionData) -> String:
	if session.scenario_status == "victory":
		return "Continuity choice: skirmish result stays self-contained; retry starts fresh, and return to menu can resume this outcome later."
	return "Continuity choice: retry starts this skirmish fresh; no campaign carryover is banked, and return to menu can resume this outcome later."

static func _build_skirmish_aftermath_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var lines := []
	var battle_aftermath := _last_battle_aftermath_text(session)
	if battle_aftermath != "":
		lines.append(battle_aftermath)
	var outcome_text := _resolution_text(scenario, session.scenario_status)
	if outcome_text != "":
		lines.append(outcome_text)
	var recent_events: String = _scenario_script_rules().describe_recent_events(session, 3)
	if recent_events != "":
		lines.append("Field report: %s." % recent_events)
	return "\n".join(lines)

static func _progress_recap_context_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var scenario_name := String(scenario.get("name", session.scenario_id))
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var campaign_id := String(session.flags.get("campaign_id", ""))
		if campaign_id == "":
			campaign_id = _campaign_id_for_scenario(session.scenario_id)
		var campaign := ContentService.get_campaign(campaign_id)
		var campaign_name := String(session.flags.get("campaign_name", campaign.get("name", campaign_id)))
		var chapter_label := String(session.flags.get("campaign_chapter_label", ""))
		if chapter_label == "":
			chapter_label = _campaign_chapter_label(campaign, session.scenario_id, scenario_name)
		if campaign_name != "" and chapter_label != "":
			return "Campaign: %s | %s | Day %d" % [campaign_name, chapter_label, session.day]
		if campaign_name != "":
			return "Campaign: %s | Day %d" % [campaign_name, session.day]
	return "%s: %s | Day %d" % [
		_scenario_select_rules().launch_mode_label(launch_mode),
		scenario_name,
		session.day,
	]

static func _progress_recap_status_line(session: SessionStateStoreScript.SessionData) -> String:
	var objective_counts := _objective_progress_counts(session)
	if objective_counts.is_empty():
		return ""
	var status_text := "Current progress: %d/%d victory complete | %d/%d defeat risks active" % [
		int(objective_counts.get("victory_met", 0)),
		int(objective_counts.get("victory_total", 0)),
		int(objective_counts.get("defeat_met", 0)),
		int(objective_counts.get("defeat_total", 0)),
	]
	if session.scenario_status != "in_progress":
		status_text += " | Result %s" % String(session.scenario_status).capitalize()
	return status_text

static func _progress_recap_recent_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var recent_events: String = _scenario_script_rules().describe_recent_events(session, 2)
	if recent_events != "":
		return "Recently resolved: %s" % recent_events
	var battle_aftermath := _last_battle_aftermath_compact_text(session)
	if battle_aftermath != "":
		return "Recently resolved: %s" % battle_aftermath
	if session.scenario_status != "in_progress":
		var summary := session.scenario_summary if session.scenario_summary != "" else _resolution_text(scenario, session.scenario_status)
		if summary != "":
			return "Recently resolved: %s" % summary
	var completed := _completed_objective_labels(session, 2)
	if not completed.is_empty():
		return "Recently resolved: %s" % "; ".join(completed)
	return ""

static func _progress_recap_next_step_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	if session.scenario_status != "in_progress":
		return "Next step: %s" % _resolved_next_step_text(session, scenario)
	var next_objective := _next_unmet_victory_objective_label(session)
	if next_objective != "":
		return "Next step: Push toward %s." % next_objective
	var objective_counts := _objective_progress_counts(session)
	if int(objective_counts.get("victory_total", 0)) > 0:
		return "Next step: All victory objectives are ready; finish the turn or resolve the scenario outcome."
	return "Next step: Scout the nearest lane, secure income, and choose the next contact."

static func _objective_progress_counts(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.scenario_id == "":
		return {}
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return {}
	var counts := {
		"victory_total": 0,
		"victory_met": 0,
		"defeat_total": 0,
		"defeat_met": 0,
	}
	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		counts["victory_total"] = int(counts.get("victory_total", 0)) + 1
		if _objective_met(session, objective):
			counts["victory_met"] = int(counts.get("victory_met", 0)) + 1
	for objective in objectives.get("defeat", []):
		if not (objective is Dictionary):
			continue
		counts["defeat_total"] = int(counts.get("defeat_total", 0)) + 1
		if _objective_met(session, objective):
			counts["defeat_met"] = int(counts.get("defeat_met", 0)) + 1
	return counts

static func _next_unmet_victory_objective_label(session: SessionStateStoreScript.SessionData) -> String:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return ""
	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		if not _objective_met(session, objective):
			return _objective_label(session, objective)
	return ""

static func _completed_objective_labels(session: SessionStateStoreScript.SessionData, limit: int) -> Array:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	var labels := []
	if not (objectives is Dictionary):
		return labels
	for objective in objectives.get("victory", []):
		if not (objective is Dictionary) or not _objective_met(session, objective):
			continue
		var label := _objective_label(session, objective)
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= limit:
			break
	return labels

static func _last_battle_aftermath_compact_text(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var report = session.flags.get("last_battle_aftermath", {})
	if not (report is Dictionary) or report.is_empty():
		return ""
	var lines := []
	for key in ["headline", "result_summary", "reward_summary", "world_summary", "summary"]:
		var line := String(report.get(key, "")).strip_edges()
		if line != "" and line not in lines:
			lines.append(line)
		if lines.size() >= 2:
			break
	return " | ".join(lines)

static func _resolved_next_step_text(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	if session.scenario_status == "victory":
		if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
			var next_chapter := _next_campaign_chapter_label(session, scenario)
			if next_chapter != "":
				return "Open %s, or replay this chapter from the campaign board." % next_chapter
			return "Return to the campaign board; this authored arc has no further unlocked chapter."
		return "Return to the menu, or retry this skirmish for a cleaner run."
	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		return "Retry this chapter from the outcome actions or campaign board."
	return "Retry this skirmish from the outcome actions or return to the menu."

static func _outcome_next_play_action_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	if session.scenario_status == "victory":
		if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
			var next_chapter := _next_campaign_chapter_label(session, scenario)
			if next_chapter != "":
				return "Next play action: Save this outcome, then start %s from the outcome actions or campaign board." % next_chapter
			return "Next play action: Save this outcome, then return to the campaign board for replay or another available chapter."
		return "Next play action: Save this outcome, then return to the menu or retry the skirmish."
	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		return "Next play action: Save this outcome, then retry the chapter from the outcome actions or campaign board."
	return "Next play action: Save this outcome, then retry the skirmish or return to the menu."

static func _campaign_id_for_scenario(scenario_id: String) -> String:
	if scenario_id == "":
		return ""
	for campaign in ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for entry in campaign.get("scenarios", []):
			if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
				return String(campaign.get("id", ""))
	return ""

static func _campaign_chapter_label(campaign: Dictionary, scenario_id: String, fallback: String) -> String:
	for entry in campaign.get("scenarios", []):
		if not (entry is Dictionary) or String(entry.get("scenario_id", "")) != scenario_id:
			continue
		var chapter_index := int(entry.get("chapter_index", 0))
		var chapter_title := String(entry.get("chapter_title", ""))
		if chapter_index > 0 and chapter_title != "":
			return "Chapter %d: %s" % [chapter_index, chapter_title]
		if chapter_title != "":
			return chapter_title
		return String(entry.get("label", fallback))
	return fallback

static func _next_campaign_chapter_label(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var campaign_id := String(session.flags.get("campaign_id", ""))
	if campaign_id == "":
		campaign_id = _campaign_id_for_scenario(session.scenario_id)
	var campaign := ContentService.get_campaign(campaign_id)
	var found_current := false
	for entry in campaign.get("scenarios", []):
		if not (entry is Dictionary):
			continue
		var scenario_id := String(entry.get("scenario_id", ""))
		if found_current and scenario_id != "":
			var next_scenario := ContentService.get_scenario(scenario_id)
			return _campaign_chapter_label(campaign, scenario_id, String(next_scenario.get("name", scenario_id)))
		if scenario_id == session.scenario_id:
			found_current = true
	return ""

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
	var objectives = scenario.get("objectives", {})
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
	var objectives = scenario.get("objectives", {})
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
	var lines := []
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		var label := String(config.get("label", ""))
		if label == "":
			label = String(ContentService.get_faction(faction_id).get("name", faction_id))
		var base_pressure: int = max(
			0,
			int(config.get("pressure_per_day", 0)) + int(config.get("pressure_per_enemy_town", 0))
		)
		var scaled_pressure := DifficultyRulesScript.adjust_enemy_pressure_gain(session, base_pressure)
		var raid_threshold := DifficultyRulesScript.adjust_raid_threshold(session, max(1, int(config.get("raid_threshold", 1))))
		var max_raids: int = max(1, int(config.get("max_active_raids", 1)))
		var strategy_summary: String = EnemyAdventureRulesScript.public_strategy_summary(config, faction_id)
		var line := "Enemy posture: %s | +%d pressure/day | raids at %d | up to %d active raids" % [
			label,
			scaled_pressure,
			raid_threshold,
			max_raids,
		]
		if strategy_summary != "":
			line = "%s | %s" % [line, strategy_summary]
		var priority_labels := _priority_target_labels(scenario, config)
		if not priority_labels.is_empty():
			line = "%s | Focus %s" % [line, ", ".join(priority_labels)]
		lines.append(line)
	return lines

static func _opening_objective_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var objectives = scenario.get("objectives", {})
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
		parts.append("raid pressure accelerates counterstrokes")
	if capture_driven:
		parts.append("captured towns can trigger immediate pushback")
	return " | ".join(parts)

static func _objective_labels_from_bucket(session: SessionStateStoreScript.SessionData, bucket: Variant, limit: int) -> Array:
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
	var base_label := String(objective.get("label", objective.get("id", "Objective")))
	match String(objective.get("type", "")):
		"enemy_pressure_at_least":
			return "%s (%d/%d)" % [
				base_label,
				_enemy_turn_rules().get_pressure(session, String(objective.get("faction_id", ""))),
				int(objective.get("threshold", 0)),
			]
		"encounter_resolved":
			return "%s (%s)" % [
				base_label,
				"Cleared" if _scenario_script_rules()._encounter_resolved(session, String(objective.get("placement_id", ""))) else "Active",
			]
		"hook_fired":
			return "%s (%s)" % [
				base_label,
				"Triggered" if _scenario_script_rules()._hook_fired(session, String(objective.get("hook_id", ""))) else "Pending",
			]
		"town_owned_by_player", "town_not_owned_by_player":
			var town := _find_town(session, objective)
			if not town.is_empty():
				return "%s (%s)" % [base_label, String(town.get("owner", "neutral")).capitalize()]
		"session_flag_equals":
			return "%s (%s)" % [base_label, String(session.flags.get(String(objective.get("flag", "")), "unset"))]
	return base_label

static func _objective_marker(is_victory: bool, met: bool) -> String:
	if is_victory:
		return "[x]" if met else "[ ]"
	return "[!]" if met else "[ ]"

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
