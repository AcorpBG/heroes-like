extends Node

const LEAK_KEYS := [
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"raid_score",
	"base_value",
	"persistent_income_value",
	"resource_affinity_value",
	"weighted_claim_value",
	"weighted_income_value",
	"assignment_penalty",
	"final_priority",
]

const FACTION_CASES := [
	{
		"case_id": "mireclaw_river_pass",
		"faction_id": "faction_mireclaw",
		"scenario_id": "river-pass",
		"town_placement_id": "duskfen_bastion",
		"origin": {"x": 7, "y": 1},
		"owned_resource_ids": ["river_signal_post", "river_free_company"],
		"raid_target_kind": "resource",
		"raid_target_id": "river_free_company",
		"raid_target_label": "Riverwatch Free Company Yard",
		"raid_encounter_id": "encounter_mire_raid",
	},
	{
		"case_id": "embercourt_glassroad",
		"faction_id": "faction_embercourt",
		"scenario_id": "glassroad-sundering",
		"town_placement_id": "riverwatch_market",
		"origin": {"x": 9, "y": 1},
		"owned_resource_ids": ["glassroad_watch_relay", "glassroad_starlens"],
		"raid_target_kind": "town",
		"raid_target_id": "halo_spire_bridgehead",
		"raid_target_label": "Halo Spire",
		"raid_encounter_id": "encounter_lantern_patrol",
	},
]

const RESOURCE_AFFINITY_CASES := [
	{
		"case_id": "thornwake_wood_affinity",
		"faction_id": "faction_thornwake",
		"scenario_id": "ninefold-confluence",
		"origin": {"x": 16, "y": 50},
		"preferred_target_id": "brightwood_sawmill",
		"comparison_target_id": "ridge_quarry",
		"preferred_resource": "wood",
	},
	{
		"case_id": "brasshollow_ore_affinity",
		"faction_id": "faction_brasshollow",
		"scenario_id": "ninefold-confluence",
		"origin": {"x": 9, "y": 36},
		"preferred_target_id": "ridge_quarry",
		"comparison_target_id": "brightwood_sawmill",
		"preferred_resource": "ore",
	},
]

const TREASURY := {"gold": 7200, "wood": 12, "ore": 12}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	for case_config in FACTION_CASES:
		var case_report := _run_faction_case(case_config)
		if case_report.is_empty():
			return
		cases.append(case_report)
	var resource_affinity_cases := []
	for affinity_config in RESOURCE_AFFINITY_CASES:
		var affinity_report := _run_resource_affinity_case(affinity_config)
		if affinity_report.is_empty():
			return
		resource_affinity_cases.append(affinity_report)

	var payload := {
		"ok": true,
		"report_marker": "AI_FACTION_PERSONALITY_EVIDENCE_REPORT",
		"cases": cases,
		"resource_affinity_cases": resource_affinity_cases,
		"shared_vocabulary": [
			"target_preferences",
			"pressure_summary",
			"town_build_reason",
			"recruitment_destination",
			"resource_affinity",
			"garrison_priority",
			"raid_priority",
			"commander_rebuild_priority",
			"compact_public_reason",
		],
	}
	print("AI_FACTION_PERSONALITY_EVIDENCE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _run_faction_case(case_config: Dictionary) -> Dictionary:
	var scenario_id := String(case_config.get("scenario_id", ""))
	var faction_id := String(case_config.get("faction_id", ""))
	var session = _base_session(scenario_id)
	for placement_id in case_config.get("owned_resource_ids", []):
		_set_resource_controller(session, String(placement_id), "player")
	if _failed:
		return {}
	var config := _enemy_config(scenario_id, faction_id)
	if config.is_empty():
		return {}
	var strategy := EnemyAdventureRules.enemy_strategy(config, faction_id)
	var origin: Dictionary = case_config.get("origin", {})
	var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, faction_id, 0)
	var top_targets := _top_resource_targets(resource_report.get("targets", []), 6)
	if top_targets.is_empty():
		_fail("%s has no resource pressure targets" % faction_id)
		return {}
	var chosen_target := EnemyAdventureRules.choose_target(session, config, origin)
	if chosen_target.is_empty():
		_fail("%s has no selected strategic target" % faction_id)
		return {}
	var pressure_event := EnemyAdventureRules.ai_pressure_summary_event(session, config, chosen_target, {})
	_assert_public_event_compact("%s pressure event" % faction_id, pressure_event)
	if _failed:
		return {}

	var governor_cases := []
	for governor_case_id in ["garrison", "raid", "commander_rebuild"]:
		var governor_case := _run_governor_case(case_config, governor_case_id)
		if governor_case.is_empty():
			return {}
		governor_cases.append(governor_case)

	return {
		"case_id": String(case_config.get("case_id", "")),
		"faction_id": faction_id,
		"faction_label": String(ContentService.get_faction(faction_id).get("name", faction_id)),
		"scenario_id": scenario_id,
		"scenario_label": String(ContentService.get_scenario(scenario_id).get("name", scenario_id)),
		"public_strategy_summary": EnemyAdventureRules.public_strategy_summary(config, faction_id),
		"config_personality": _strategy_snapshot(strategy),
		"scenario_pressure_config": _scenario_pressure_snapshot(config),
		"target_preferences": {
			"origin": origin,
			"top_resource_targets": top_targets,
			"chosen_target": _target_snapshot(chosen_target),
			"pressure_event": pressure_event,
		},
		"town_governor": governor_cases,
	}

func _run_governor_case(case_config: Dictionary, governor_case_id: String) -> Dictionary:
	var scenario_id := String(case_config.get("scenario_id", ""))
	var faction_id := String(case_config.get("faction_id", ""))
	var session = _base_session(scenario_id)
	_set_enemy_treasury(session, faction_id, TREASURY)
	match governor_case_id:
		"raid":
			_strengthen_enemy_town_garrison(session, faction_id, String(case_config.get("town_placement_id", "")))
			_add_active_raid(session, case_config)
		"commander_rebuild":
			_strengthen_enemy_town_garrison(session, faction_id, String(case_config.get("town_placement_id", "")))
			_set_shattered_commander_roster(session, faction_id)
		_:
			pass
	if _failed:
		return {}
	var config := _enemy_config(scenario_id, faction_id)
	var report := EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
	var town_report := _town_report_by_id(report.get("towns", []), String(case_config.get("town_placement_id", "")))
	if town_report.is_empty():
		_fail("%s missing town governor report for %s" % [faction_id, governor_case_id])
		return {}
	var selected_build: Dictionary = town_report.get("build", {}).get("selected_build", {})
	var selected_recruitment: Dictionary = town_report.get("recruitment", {}).get("selected_recruitment", {})
	if selected_build.is_empty():
		_fail("%s %s missing selected build" % [faction_id, governor_case_id])
		return {}
	if selected_recruitment.is_empty():
		_fail("%s %s missing selected recruitment" % [faction_id, governor_case_id])
		return {}
	if String(selected_build.get("public_reason", "")) == "":
		_fail("%s %s selected build missing public reason" % [faction_id, governor_case_id])
		return {}
	var destination: Dictionary = selected_recruitment.get("destination", {})
	if String(destination.get("public_reason", "")) == "":
		_fail("%s %s selected recruitment missing destination public reason" % [faction_id, governor_case_id])
		return {}
	var public_events := []
	for event in town_report.get("events", []):
		if event is Dictionary:
			_assert_public_event_compact("%s %s" % [faction_id, String(event.get("event_type", "event"))], event)
			if _failed:
				return {}
			public_events.append(event)
	return {
		"case_id": governor_case_id,
		"town_placement_id": String(town_report.get("placement_id", "")),
		"strategic_role": String(town_report.get("strategic_role", "")),
		"garrison_strength": int(town_report.get("garrison_strength", 0)),
		"desired_garrison_strength": int(town_report.get("desired_garrison_strength", 0)),
		"selected_build": _build_snapshot(selected_build),
		"selected_recruitment": _recruitment_snapshot(selected_recruitment),
		"event_types": _event_types(public_events),
		"public_events": public_events,
	}

func _run_resource_affinity_case(case_config: Dictionary) -> Dictionary:
	var scenario_id := String(case_config.get("scenario_id", ""))
	var faction_id := String(case_config.get("faction_id", ""))
	var preferred_target_id := String(case_config.get("preferred_target_id", ""))
	var comparison_target_id := String(case_config.get("comparison_target_id", ""))
	var origin: Dictionary = case_config.get("origin", {})
	var session = _base_session(scenario_id)
	var config := _enemy_config(scenario_id, faction_id)
	if config.is_empty():
		return {}
	var weighted_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, faction_id, 0)
	var neutral_config := _neutral_resource_affinity_config(config)
	var neutral_report := EnemyAdventureRules.resource_pressure_report(session, neutral_config, origin, faction_id, 0)
	var preferred := _target_by_placement(weighted_report.get("targets", []), preferred_target_id)
	var neutral_preferred := _target_by_placement(neutral_report.get("targets", []), preferred_target_id)
	var comparison := _target_by_placement(weighted_report.get("targets", []), comparison_target_id)
	if preferred.is_empty() or neutral_preferred.is_empty() or comparison.is_empty():
		_fail("%s missing affinity target(s)" % String(case_config.get("case_id", "")))
		return {}
	if int(preferred.get("resource_affinity_value", 0)) <= 0:
		_fail("%s did not add resource affinity value for %s" % [case_config.get("case_id", ""), preferred_target_id])
		return {}
	if int(preferred.get("final_priority", 0)) <= int(neutral_preferred.get("final_priority", 0)):
		_fail("%s affinity did not raise %s priority above neutral weights" % [case_config.get("case_id", ""), preferred_target_id])
		return {}
	var preferred_resource := String(case_config.get("preferred_resource", ""))
	var strategy := EnemyAdventureRules.enemy_strategy(config, faction_id)
	var resource_weights: Dictionary = strategy.get("resource_value_weights", {})
	if float(resource_weights.get(preferred_resource, 1.0)) <= 1.0:
		_fail("%s missing authored preferred resource weight" % case_config.get("case_id", ""))
		return {}
	return {
		"case_id": String(case_config.get("case_id", "")),
		"scenario_id": scenario_id,
		"faction_id": faction_id,
		"faction_label": String(ContentService.get_faction(faction_id).get("name", faction_id)),
		"origin": origin,
		"preferred_resource": preferred_resource,
		"preferred_target": _resource_affinity_snapshot(preferred, weighted_report.get("targets", [])),
		"neutral_preferred_target": _resource_affinity_snapshot(neutral_preferred, neutral_report.get("targets", [])),
		"comparison_target": _resource_affinity_snapshot(comparison, weighted_report.get("targets", [])),
		"strategy_resource_value_weights": resource_weights,
		"case_pass_criteria": [
			"Authored faction resource_value_weights are merged into EnemyAdventureRules.enemy_strategy.",
			"The preferred target receives a positive resource_affinity_value in the same resource_pressure_report used by AI target selection.",
			"Neutralized resource weights lower the same target priority, proving the identity hook affects the decision score.",
		],
	}

func _base_session(scenario_id: String):
	var session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session

func _strategy_snapshot(strategy: Dictionary) -> Dictionary:
	return {
		"build_category_weights": strategy.get("build_category_weights", {}),
		"build_value_weights": strategy.get("build_value_weights", {}),
		"raid_target_weights": strategy.get("raid_target_weights", {}),
		"resource_value_weights": strategy.get("resource_value_weights", {}),
		"site_family_weights": strategy.get("site_family_weights", {}),
		"reinforcement": strategy.get("reinforcement", {}),
		"raid": strategy.get("raid", {}),
	}

func _scenario_pressure_snapshot(config: Dictionary) -> Dictionary:
	return {
		"label": String(config.get("label", "")),
		"raid_threshold": int(config.get("raid_threshold", 0)),
		"max_active_raids": int(config.get("max_active_raids", 0)),
		"siege_target_placement_id": String(config.get("siege_target_placement_id", "")),
		"priority_target_bonus": int(config.get("priority_target_bonus", 0)),
		"priority_target_placement_ids": config.get("priority_target_placement_ids", []),
		"strategy_overrides": config.get("strategy_overrides", {}),
	}

func _target_snapshot(target: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target.get("target_kind", "")),
		"target_placement_id": String(target.get("target_placement_id", "")),
		"target_label": String(target.get("target_label", "")),
		"priority": int(target.get("priority", target.get("final_priority", 0))),
		"public_reason": String(target.get("target_public_reason", target.get("public_reason", ""))),
		"debug_reason": String(target.get("target_debug_reason", target.get("debug_reason", ""))),
		"reason_codes": target.get("target_reason_codes", target.get("reason_codes", [])),
	}

func _build_snapshot(build: Dictionary) -> Dictionary:
	return {
		"building_id": String(build.get("building_id", "")),
		"building_label": String(build.get("building_label", "")),
		"category": String(build.get("category", "")),
		"public_reason": String(build.get("public_reason", "")),
		"debug_reason": String(build.get("debug_reason", "")),
		"reason_codes": build.get("reason_codes", []),
		"affordable": bool(build.get("affordable", false)),
		"dominant_debug_components": _dominant_build_components(build),
	}

func _dominant_build_components(build: Dictionary) -> Array:
	var components := [
		{"key": "weighted_income_value", "value": float(build.get("weighted_income_value", 0.0))},
		{"key": "weighted_growth_value", "value": float(build.get("weighted_growth_value", 0.0))},
		{"key": "weighted_quality_value", "value": float(build.get("weighted_quality_value", 0.0))},
		{"key": "weighted_readiness_value", "value": float(build.get("weighted_readiness_value", 0.0))},
		{"key": "weighted_pressure_value", "value": float(build.get("weighted_pressure_value", 0.0))},
		{"key": "weighted_market_value", "value": float(build.get("weighted_market_value", 0.0))},
		{"key": "garrison_need_bonus", "value": float(build.get("garrison_need_bonus", 0.0))},
		{"key": "raid_need_bonus", "value": float(build.get("raid_need_bonus", 0.0))},
		{"key": "front_bonus", "value": float(build.get("front_bonus", 0.0))},
		{"key": "project_bonus", "value": float(build.get("project_bonus", 0.0))},
		{"key": "role_bonus", "value": float(build.get("role_bonus", 0.0))},
	]
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
	)
	var result := []
	for component in components:
		if float(component.get("value", 0.0)) <= 0.0:
			continue
		result.append(component)
		if result.size() >= 4:
			break
	return result

func _recruitment_snapshot(recruitment: Dictionary) -> Dictionary:
	var destination: Dictionary = recruitment.get("destination", {})
	return {
		"unit_id": String(recruitment.get("unit_id", "")),
		"unit_label": String(recruitment.get("unit_label", "")),
		"recruit_count": int(recruitment.get("recruit_count", 0)),
		"priority": float(recruitment.get("priority", 0.0)),
		"destination": {
			"type": String(destination.get("type", "")),
			"decision_rule": String(destination.get("decision_rule", "")),
			"public_reason": String(destination.get("public_reason", "")),
			"debug_reason": String(destination.get("debug_reason", "")),
			"reason_codes": destination.get("reason_codes", []),
			"garrison_score": float(destination.get("garrison_score", 0.0)),
			"raid_score": float(destination.get("raid_score", 0.0)),
			"rebuild_score": float(destination.get("rebuild_score", 0.0)),
			"target_id": String(destination.get("target_id", "")),
			"target_label": String(destination.get("target_label", "")),
			"commander_label": String(destination.get("commander_label", "")),
		},
	}

func _top_resource_targets(targets: Array, limit: int) -> Array:
	var result := []
	for target in targets:
		if not (target is Dictionary):
			continue
		result.append(
			{
				"placement_id": String(target.get("placement_id", "")),
				"site_id": String(target.get("site_id", "")),
				"site_family": String(target.get("site_family", "")),
				"target_label": String(target.get("target_label", "")),
				"controller_id": String(target.get("controller_id", "")),
				"player_controlled": bool(target.get("player_controlled", false)),
				"resource_affinity_value": int(target.get("resource_affinity_value", 0)),
				"final_priority": int(target.get("final_priority", 0)),
				"reason_codes": target.get("reason_codes", []),
				"public_reason": String(target.get("public_reason", "")),
				"debug_reason": String(target.get("debug_reason", "")),
			}
		)
		if result.size() >= limit:
			break
	return result

func _target_by_placement(targets: Array, placement_id: String) -> Dictionary:
	for target in targets:
		if target is Dictionary and String(target.get("placement_id", "")) == placement_id:
			return target
	return {}

func _target_rank(targets: Array, placement_id: String) -> int:
	for index in range(targets.size()):
		var target = targets[index]
		if target is Dictionary and String(target.get("placement_id", "")) == placement_id:
			return index + 1
	return -1

func _resource_affinity_snapshot(target: Dictionary, targets: Array) -> Dictionary:
	var placement_id := String(target.get("placement_id", ""))
	return {
		"placement_id": placement_id,
		"site_id": String(target.get("site_id", "")),
		"site_family": String(target.get("site_family", "")),
		"target_label": String(target.get("target_label", "")),
		"rank": _target_rank(targets, placement_id),
		"base_value": int(target.get("base_value", 0)),
		"persistent_income_value": int(target.get("persistent_income_value", 0)),
		"resource_affinity_value": int(target.get("resource_affinity_value", 0)),
		"weighted_claim_value": int(target.get("weighted_claim_value", 0)),
		"weighted_income_value": int(target.get("weighted_income_value", 0)),
		"final_priority": int(target.get("final_priority", 0)),
		"public_reason": String(target.get("public_reason", "")),
		"reason_codes": target.get("reason_codes", []),
	}

func _neutral_resource_affinity_config(config: Dictionary) -> Dictionary:
	var result := config.duplicate(true)
	var overrides := {}
	if result.get("strategy_overrides", {}) is Dictionary:
		overrides = result.get("strategy_overrides", {}).duplicate(true)
	overrides["resource_value_weights"] = {
		"gold": 1.0,
		"wood": 1.0,
		"ore": 1.0,
		"experience": 1.0,
	}
	result["strategy_overrides"] = overrides
	return result

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s in %s" % [placement_id, session.scenario_id])

func _set_enemy_treasury(session, faction_id: String, treasury: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != faction_id:
			continue
		state["treasury"] = treasury.duplicate(true)
		states[index] = state
		session.overworld["enemy_states"] = states
		return
	_fail("Could not set enemy treasury for %s" % faction_id)

func _strengthen_enemy_town_garrison(session, faction_id: String, town_placement_id: String) -> void:
	var units: Array = ContentService.get_faction(faction_id).get("unit_ladder_ids", [])
	var first_unit := String(units[0]) if units is Array and units.size() > 0 else ""
	var second_unit := String(units[1]) if units is Array and units.size() > 1 else first_unit
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("placement_id", "")) != town_placement_id:
			continue
		town["garrison"] = [
			{"unit_id": first_unit, "count": 70},
			{"unit_id": second_unit, "count": 45},
		]
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not strengthen town %s" % town_placement_id)

func _add_active_raid(session, case_config: Dictionary) -> void:
	var target_kind := String(case_config.get("raid_target_kind", "resource"))
	var target_id := String(case_config.get("raid_target_id", ""))
	var target_coords := _target_coords(session, target_kind, target_id)
	var origin: Dictionary = case_config.get("origin", {})
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(
		{
			"placement_id": "%s_report_raid" % String(case_config.get("case_id", "faction")),
			"encounter_id": String(case_config.get("raid_encounter_id", "")),
			"x": int(origin.get("x", 0)),
			"y": int(origin.get("y", 0)),
			"difficulty": "pressure",
			"combat_seed": hash("%s:%s" % [String(case_config.get("scenario_id", "")), String(case_config.get("case_id", ""))]),
			"spawned_by_faction_id": String(case_config.get("faction_id", "")),
			"days_active": 1,
			"arrived": false,
			"goal_distance": 2,
			"target_kind": target_kind,
			"target_placement_id": target_id,
			"target_label": String(case_config.get("raid_target_label", target_id)),
			"target_x": int(target_coords.get("x", 0)),
			"target_y": int(target_coords.get("y", 0)),
			"enemy_army": {"id": "%s_report_raid" % String(case_config.get("case_id", "faction")), "name": "Report Raid", "stacks": []},
		}
	)
	session.overworld["encounters"] = encounters

func _target_coords(session, target_kind: String, target_id: String) -> Dictionary:
	var bucket := "resource_nodes"
	if target_kind == "town":
		bucket = "towns"
	elif target_kind == "encounter":
		bucket = "encounters"
	for value in session.overworld.get(bucket, []):
		if not (value is Dictionary):
			continue
		if String(value.get("placement_id", "")) != target_id:
			continue
		return {"x": int(value.get("x", 0)), "y": int(value.get("y", 0))}
	return {"x": 0, "y": 0}

func _set_shattered_commander_roster(session, faction_id: String) -> void:
	var roster := []
	for hero_id_value in ContentService.get_faction(faction_id).get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id == "":
			continue
		roster.append(
			{
				"roster_hero_id": hero_id,
				"status": EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE,
				"renown": 0,
				"army_continuity": {
					"encounter_id": "personality_report_rebuild",
					"stacks": [],
					"base_strength": 240,
					"current_strength": 0,
					"rebuild_need": 240,
					"status": "shattered",
				},
			}
		)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != faction_id:
			continue
		state["commander_roster"] = roster
		states[index] = state
		session.overworld["enemy_states"] = states
		return
	_fail("Could not set shattered commander roster for %s" % faction_id)

func _town_report_by_id(towns: Array, placement_id: String) -> Dictionary:
	for town in towns:
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _event_types(events: Array) -> Array:
	var types := []
	for event in events:
		if not (event is Dictionary):
			continue
		var event_type := String(event.get("event_type", ""))
		if event_type != "" and event_type not in types:
			types.append(event_type)
	return types

func _assert_public_event_compact(label: String, event: Dictionary) -> void:
	if event.is_empty():
		_fail("%s missing compact event" % label)
		return
	var event_text := JSON.stringify(event)
	for key in LEAK_KEYS:
		if event.has(String(key)) or event_text.contains(String(key)):
			_fail("%s leaked score-table key %s" % [label, key])
			return
	if String(event.get("public_reason", "")) == "":
		_fail("%s missing public reason" % label)
		return

func _enemy_config(scenario_id: String, faction_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	_fail("Could not find enemy config for %s in %s" % [faction_id, scenario_id])
	return {}

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"error": message,
	}
	push_error(message)
	print("AI_FACTION_PERSONALITY_EVIDENCE_REPORT %s" % JSON.stringify(payload))
	_failed = true
	get_tree().quit(1)
