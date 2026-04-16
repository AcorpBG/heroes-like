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
		"actions": [],
	}

	if launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var recap := CampaignProgression.outcome_recap(session)
		model["progression_summary"] = String(recap.get("progression_summary", ""))
		model["campaign_arc_summary"] = String(recap.get("campaign_arc_summary", ""))
		model["carryover_summary"] = String(recap.get("carryover_summary", ""))
		model["aftermath_summary"] = String(recap.get("aftermath_summary", ""))
		model["journal_summary"] = String(recap.get("journal_summary", ""))
		model["actions"] = CampaignProgression.outcome_actions(session)
	else:
		model["progression_summary"] = "\n".join(
			[
				"Skirmish results are self-contained and do not change campaign progression.",
				"Final state: %s | Hero, army, and resources shown above are the surviving expedition snapshot." % status_label,
			]
		)
		model["campaign_arc_summary"] = "Campaign arc closure is only tracked for launched campaign chapters."
		model["carryover_summary"] = "Skirmish runs do not import or export campaign carryover."
		model["aftermath_summary"] = _build_skirmish_aftermath_summary(session, scenario)
		model["journal_summary"] = "Campaign chronicle updates are only recorded for launched campaign chapters."
		model["actions"] = _build_skirmish_outcome_actions(session)
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
	session.flags["campaign"] = status
	if SessionStateStoreScript.normalize_launch_mode(session.launch_mode) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
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

static func _last_battle_aftermath_text(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var report = session.flags.get("last_battle_aftermath", {})
	if not (report is Dictionary) or report.is_empty():
		return ""
	var lines := []
	for key in [
		"headline",
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
	match terrain_id:
		"grass":
			return "Grassland"
		"forest":
			return "Forest"
		"water":
			return "Sea"
		"mire":
			return "Mire"
		_:
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
