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

const CASES := [
	{
		"case_id": "prismhearth_mireclaw_saboteurs",
		"scenario_id": "prismhearth-watch",
		"player_faction_id": "faction_sunvault",
		"faction_id": "faction_mireclaw",
		"forbidden_enemy_faction_id": "faction_embercourt",
		"origin": {"x": 8, "y": 1},
		"controlled_resource_ids": ["prismhearth_watch_relay", "prismhearth_lens_house"],
		"required_priority_targets": [
			"prismhearth_hold",
			"prismhearth_watch_relay",
			"prismhearth_lens_house",
			"prismhearth_halo_reserve",
		],
		"required_top_resource_ids": ["prismhearth_watch_relay", "prismhearth_lens_house"],
		"expected_strategy": {
			"raid_target_weights": {"resource": 1.3, "encounter": 1.25},
			"raid": {"hero_hunt_weight": 1.35},
		},
	},
	{
		"case_id": "glassroad_embercourt_charter_front",
		"scenario_id": "glassroad-sundering",
		"player_faction_id": "faction_sunvault",
		"faction_id": "faction_embercourt",
		"forbidden_enemy_faction_id": "faction_mireclaw",
		"origin": {"x": 9, "y": 1},
		"controlled_resource_ids": ["glassroad_watch_relay", "glassroad_starlens"],
		"required_priority_targets": [
			"halo_spire_bridgehead",
			"glassroad_watch_relay",
			"glassroad_starlens",
			"glassroad_beacon_wardens",
		],
		"required_top_resource_ids": ["glassroad_watch_relay", "glassroad_starlens"],
		"expected_strategy": {
			"site_family_weights": {"faction_outpost": 1.55, "frontier_shrine": 1.2},
			"raid_target_weights": {"town": 1.4, "encounter": 1.2},
			"raid": {"town_siege_weight": 1.5},
		},
		"expected_chosen_target": {"target_kind": "town", "target_placement_id": "halo_spire_bridgehead"},
	},
	{
		"case_id": "ninefold_mireclaw_marsh_claim",
		"scenario_id": "ninefold-confluence",
		"player_faction_id": "faction_embercourt",
		"faction_id": "faction_mireclaw",
		"forbidden_enemy_faction_id": "faction_embercourt",
		"origin": {"x": 30, "y": 24},
		"controlled_resource_ids": ["bog_drum_crossing", "dwelling_bogbell_croft"],
		"required_priority_targets": [
			"ninefold_embercourt_survey_camp",
			"bog_drum_crossing",
			"dwelling_bogbell_croft",
			"ninefold_basalt_gatehouse_watch",
		],
		"required_top_resource_ids": ["bog_drum_crossing", "dwelling_bogbell_croft"],
		"expected_strategy": {
			"site_family_weights": {"neutral_dwelling": 1.4, "faction_outpost": 1.5},
			"raid_target_weights": {"town": 1.2, "resource": 1.2},
			"raid": {"site_denial_weight": 1.4, "town_siege_weight": 1.3},
		},
		"expected_chosen_target": {"target_kind": "town", "target_placement_id": "ninefold_embercourt_survey_camp"},
	},
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var reports := []
	var public_events := []
	for case_config in CASES:
		var report := _run_case(case_config)
		if report.is_empty():
			return
		reports.append(report)
		var event: Dictionary = report.get("pressure_event", {})
		if not event.is_empty():
			public_events.append(event)
		for event_value in report.get("assignment_events", []):
			if event_value is Dictionary:
				public_events.append(event_value)

	var public_leak_check := EnemyAdventureRules.commander_role_public_leak_check(public_events)
	if not bool(public_leak_check.get("ok", false)):
		_fail(String(public_leak_check.get("error", "public leak check failed")))
		return

	var payload := {
		"ok": true,
		"report_marker": "FACTION_SCENARIO_AI_PRESSURE_REPORT",
		"cases": reports,
		"public_leak_check": public_leak_check,
		"slice_evidence": [
			"Prismhearth Watch remains Mireclaw pressure against a Sunvault front.",
			"Glassroad Sundering remains direct Embercourt charter-front pressure.",
			"Ninefold Confluence includes Mireclaw pressure and does not treat Embercourt as an enemy faction.",
			"Live AI pressure helpers produce compact public events from the authored front placements.",
		],
	}
	print("FACTION_SCENARIO_AI_PRESSURE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _run_case(case_config: Dictionary) -> Dictionary:
	var scenario_id := String(case_config.get("scenario_id", ""))
	var faction_id := String(case_config.get("faction_id", ""))
	var session = _base_session(scenario_id)
	for placement_id in case_config.get("controlled_resource_ids", []):
		_set_resource_controller(session, String(placement_id), "player")
		if _failed:
			return {}

	var scenario := ContentService.get_scenario(scenario_id)
	if String(scenario.get("player_faction_id", "")) != String(case_config.get("player_faction_id", "")):
		_fail("%s expected player faction %s, got %s" % [scenario_id, case_config.get("player_faction_id", ""), scenario.get("player_faction_id", "")])
		return {}
	if _has_enemy_config(scenario, String(case_config.get("forbidden_enemy_faction_id", ""))):
		_fail("%s must not use %s as enemy evidence" % [scenario_id, case_config.get("forbidden_enemy_faction_id", "")])
		return {}

	var config := _enemy_config(scenario, scenario_id, faction_id)
	if config.is_empty():
		return {}
	_assert_required_priority_targets(config, case_config)
	_assert_strategy(config, faction_id, case_config)
	if _failed:
		return {}

	var origin: Dictionary = case_config.get("origin", {})
	var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, faction_id, 0)
	var top_targets := _top_resource_targets(resource_report.get("targets", []), 6)
	_assert_required_top_targets(top_targets, case_config)
	if _failed:
		return {}

	var chosen := EnemyAdventureRules.choose_target(session, config, origin)
	if chosen.is_empty():
		_fail("%s %s produced no chosen AI pressure target" % [scenario_id, faction_id])
		return {}
	_assert_expected_chosen_target(chosen, case_config)
	if _failed:
		return {}

	var pressure_event := EnemyAdventureRules.ai_pressure_summary_event(session, config, chosen, {})
	_assert_public_event_compact("%s pressure event" % scenario_id, pressure_event)
	if _failed:
		return {}

	var assignment_events := []
	for target_id in case_config.get("required_top_resource_ids", []):
		var target := _target_by_placement(resource_report.get("targets", []), String(target_id))
		if target.is_empty():
			_fail("%s missing resource target %s" % [scenario_id, target_id])
			return {}
		var event := _assignment_event_from_target(session, config, faction_id, origin, target)
		_assert_public_event_compact("%s assignment %s" % [scenario_id, target_id], event)
		if _failed:
			return {}
		assignment_events.append(event)

	return {
		"case_id": String(case_config.get("case_id", "")),
		"scenario_id": scenario_id,
		"scenario_label": String(scenario.get("name", scenario_id)),
		"player_faction_id": String(scenario.get("player_faction_id", "")),
		"enemy_faction_id": faction_id,
		"enemy_label": String(config.get("label", faction_id)),
		"enemy_factions_present": _enemy_faction_ids(scenario),
		"priority_target_placement_ids": config.get("priority_target_placement_ids", []),
		"strategy_summary": EnemyAdventureRules.public_strategy_summary(config, faction_id),
		"strategy_overrides": config.get("strategy_overrides", {}),
		"staged_player_controlled_resources": case_config.get("controlled_resource_ids", []),
		"top_resource_targets": top_targets,
		"chosen_target": _target_snapshot(chosen),
		"pressure_event": pressure_event,
		"assignment_events": assignment_events,
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

func _enemy_config(scenario: Dictionary, scenario_id: String, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	_fail("Could not find enemy config for %s in %s" % [faction_id, scenario_id])
	return {}

func _has_enemy_config(scenario: Dictionary, faction_id: String) -> bool:
	if faction_id == "":
		return false
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return true
	return false

func _enemy_faction_ids(scenario: Dictionary) -> Array:
	var result := []
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary:
			result.append(String(config.get("faction_id", "")))
	return result

func _assert_required_priority_targets(config: Dictionary, case_config: Dictionary) -> void:
	var priority_targets: Array = config.get("priority_target_placement_ids", [])
	for placement_id in case_config.get("required_priority_targets", []):
		if String(placement_id) not in priority_targets:
			_fail("%s missing priority target %s" % [case_config.get("case_id", ""), placement_id])
			return

func _assert_strategy(config: Dictionary, faction_id: String, case_config: Dictionary) -> void:
	var strategy := EnemyAdventureRules.enemy_strategy(config, faction_id)
	var expected: Dictionary = case_config.get("expected_strategy", {})
	for bucket_key in expected.keys():
		var bucket: Dictionary = strategy.get(String(bucket_key), {})
		var expected_bucket: Dictionary = expected.get(bucket_key, {})
		for value_key in expected_bucket.keys():
			var actual := float(bucket.get(String(value_key), 0.0))
			var minimum := float(expected_bucket.get(value_key, 0.0))
			if actual < minimum:
				_fail("%s expected %s.%s >= %.2f, got %.2f" % [case_config.get("case_id", ""), bucket_key, value_key, minimum, actual])
				return

func _assert_required_top_targets(top_targets: Array, case_config: Dictionary) -> void:
	var top_ids := []
	for target in top_targets:
		if target is Dictionary:
			top_ids.append(String(target.get("placement_id", "")))
	for placement_id in case_config.get("required_top_resource_ids", []):
		if String(placement_id) not in top_ids:
			_fail("%s expected %s in top resource pressure targets, got %s" % [case_config.get("case_id", ""), placement_id, top_ids])
			return
		var target := _target_by_placement(top_targets, String(placement_id))
		if String(target.get("public_reason", "")) == "":
			_fail("%s target %s missing public reason" % [case_config.get("case_id", ""), placement_id])
			return
		if int(target.get("final_priority", 0)) <= 0:
			_fail("%s target %s did not receive positive pressure priority" % [case_config.get("case_id", ""), placement_id])
			return

func _assert_expected_chosen_target(chosen: Dictionary, case_config: Dictionary) -> void:
	var expected: Dictionary = case_config.get("expected_chosen_target", {})
	if expected.is_empty():
		return
	for key in expected.keys():
		if String(chosen.get(String(key), "")) != String(expected.get(key, "")):
			_fail("%s expected chosen target %s=%s, got %s" % [case_config.get("case_id", ""), key, expected.get(key, ""), _target_snapshot(chosen)])
			return

func _assignment_event_from_target(
	session,
	config: Dictionary,
	faction_id: String,
	origin: Dictionary,
	target: Dictionary
) -> Dictionary:
	var node := _resource_node(session, String(target.get("placement_id", "")))
	var actor := {
		"placement_id": "%s_%s_pressure_report" % [faction_id, String(target.get("placement_id", ""))],
		"name": String(config.get("label", faction_id)),
		"spawned_by_faction_id": faction_id,
		"x": int(origin.get("x", 0)),
		"y": int(origin.get("y", 0)),
		"target_kind": "resource",
		"target_placement_id": String(target.get("placement_id", "")),
		"target_label": String(target.get("target_label", target.get("placement_id", ""))),
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"target_reason_codes": target.get("reason_codes", []),
		"target_public_reason": String(target.get("public_reason", "")),
		"target_public_importance": String(target.get("public_importance", "high")),
		"target_debug_reason": String(target.get("debug_reason", "")),
	}
	return EnemyAdventureRules.ai_target_assignment_event(session, config, actor, {})

func _resource_node(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

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

func _target_snapshot(target: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target.get("target_kind", "")),
		"target_placement_id": String(target.get("target_placement_id", target.get("placement_id", ""))),
		"target_label": String(target.get("target_label", "")),
		"priority": int(target.get("priority", target.get("final_priority", 0))),
		"public_reason": String(target.get("target_public_reason", target.get("public_reason", ""))),
		"debug_reason": String(target.get("target_debug_reason", target.get("debug_reason", ""))),
		"reason_codes": target.get("target_reason_codes", target.get("reason_codes", [])),
	}

func _assert_public_event_compact(label: String, event: Dictionary) -> void:
	if event.is_empty():
		_fail("%s missing compact public event" % label)
		return
	if String(event.get("public_reason", "")) == "":
		_fail("%s missing public reason" % label)
		return
	var event_text := JSON.stringify(event)
	for key in LEAK_KEYS:
		if event.has(String(key)) or event_text.contains(String(key)):
			_fail("%s leaked score-table key %s" % [label, key])
			return

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"error": message,
	}
	push_error(message)
	print("FACTION_SCENARIO_AI_PRESSURE_REPORT %s" % JSON.stringify(payload))
	_failed = true
	get_tree().quit(1)
