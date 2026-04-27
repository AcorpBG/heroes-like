extends Node

const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _base_session()
	_set_resource_controller(session, "river_signal_post", "player")
	_set_resource_controller(session, "river_free_company", "player")
	var config := _enemy_config()
	var origin := {"x": 7, "y": 1}
	var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, FACTION_ID, 0)
	var free_company := _target_by_id(resource_report.get("targets", []), "river_free_company")
	var signal_post := _target_by_id(resource_report.get("targets", []), "river_signal_post")
	if free_company.is_empty() or signal_post.is_empty():
		_fail("Missing signal-yard targets in resource pressure report")
		return

	var free_company_assignment := _assignment_event_from_breakdown(session, config, free_company, "report_commander_free_company")
	var signal_assignment := _assignment_event_from_breakdown(session, config, signal_post, "report_commander_signal_post")
	_assert_event(free_company_assignment, "ai_target_assigned", "river_free_company", ["persistent_income_denial", "recruit_denial"])
	_assert_event(signal_assignment, "ai_target_assigned", "river_signal_post", ["persistent_income_denial", "route_vision"])
	if _failed:
		return

	var chosen := EnemyAdventureRules.choose_target(session, config, origin)
	var pressure_event := EnemyAdventureRules.ai_pressure_summary_event(session, config, chosen, {})
	_assert_event(pressure_event, "ai_pressure_summary", "riverwatch_hold", ["town_siege", "objective_front"])
	if _failed:
		return

	var threat_session = _base_session()
	_add_report_raid(threat_session, "visible_signal_pressure", 2, 3, "resource", "river_signal_post", "Ember Signal Post", "income and route vision denial", ["persistent_income_denial", "route_vision", "player_town_support"], "high")
	var threat_text := EnemyTurnRules.describe_threats(threat_session)
	var dispatch_text := OverworldRules.describe_dispatch(threat_session, "Scout the signal yard.")
	_assert_no_score_leak("threat text", threat_text)
	_assert_no_score_leak("dispatch text", dispatch_text)
	if not threat_text.contains("income and route vision denial") and not dispatch_text.contains("income and route vision denial"):
		_fail("Threat/dispatch surface did not expose compact public reason")
		return

	var seizure_result := _run_arrival_case(
		"resource_seizure",
		"river_free_company_seizure_raid",
		0,
		4,
		"resource",
		"river_free_company",
		"Riverwatch Free Company Yard",
		"recruit and income denial",
		["persistent_income_denial", "recruit_denial", "player_town_support"],
		"high"
	)
	var seizure_event := _event_by_type_and_target(seizure_result.get("events", []), "ai_site_seized", "river_free_company")
	_assert_event(seizure_event, "ai_site_seized", "river_free_company", ["site_seized", "persistent_income_denial", "recruit_denial"])
	if not String(seizure_result.get("message", "")).contains("denies its logistics route"):
		_fail("Resource seizure message did not keep compact logistics denial wording")
		return
	if _failed:
		return

	var contest_result := _run_arrival_case(
		"objective_contest",
		"reed_totemist_contest_raid",
		3,
		1,
		"encounter",
		"river_pass_ghoul_grove",
		"Ghoul Grove",
		"objective front",
		["site_contested", "objective_front"],
		"high"
	)
	var contest_event := _event_by_type_and_target(contest_result.get("events", []), "ai_site_contested", "river_pass_ghoul_grove")
	_assert_event(contest_event, "ai_site_contested", "river_pass_ghoul_grove", ["site_contested", "objective_front"])
	if _failed:
		return

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"assignment_events": [free_company_assignment, signal_assignment],
		"pressure_event": pressure_event,
		"seizure_event": seizure_event,
		"contest_event": contest_event,
		"threat_excerpt": threat_text,
		"dispatch_excerpt": dispatch_text,
	}
	print("AI_EVENT_SURFACING_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _base_session():
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session

func _assignment_event_from_breakdown(session, config: Dictionary, breakdown: Dictionary, actor_id: String) -> Dictionary:
	var actor := {
		"placement_id": actor_id,
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": FACTION_ID,
		"x": 7,
		"y": 1,
		"target_kind": "resource",
		"target_placement_id": String(breakdown.get("placement_id", "")),
		"target_label": String(breakdown.get("target_label", "")),
		"target_x": 0,
		"target_y": 0,
		"target_reason_codes": breakdown.get("reason_codes", []),
		"target_public_reason": String(breakdown.get("public_reason", "")),
		"target_public_importance": String(breakdown.get("public_importance", "high")),
		"target_debug_reason": String(breakdown.get("debug_reason", "")),
	}
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == String(breakdown.get("placement_id", "")):
			actor["target_x"] = int(node.get("x", 0))
			actor["target_y"] = int(node.get("y", 0))
			break
	return EnemyAdventureRules.ai_target_assignment_event(session, config, actor, {})

func _run_arrival_case(
	case_id: String,
	raid_id: String,
	x: int,
	y: int,
	target_kind: String,
	target_id: String,
	target_label: String,
	public_reason: String,
	reason_codes: Array,
	importance: String
) -> Dictionary:
	var session = _base_session()
	if target_kind == "resource":
		_set_resource_controller(session, target_id, "player")
	_add_report_raid(session, raid_id, x, y, target_kind, target_id, target_label, public_reason, reason_codes, importance)
	var result := EnemyAdventureRules.advance_raids(session, _enemy_config(), FACTION_ID, _enemy_state())
	if result.get("events", []) is Array and not result.get("events", []).is_empty():
		return result
	_fail("%s did not produce an AI event" % case_id)
	return {}

func _add_report_raid(
	session,
	raid_id: String,
	x: int,
	y: int,
	target_kind: String,
	target_id: String,
	target_label: String,
	public_reason: String,
	reason_codes: Array,
	importance: String
) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(
		{
			"placement_id": raid_id,
			"encounter_id": "encounter_mire_raid",
			"x": x,
			"y": y,
			"difficulty": "pressure",
			"combat_seed": hash("%s:%s" % [SCENARIO_ID, raid_id]),
			"spawned_by_faction_id": FACTION_ID,
			"days_active": 0,
			"arrived": true,
			"goal_distance": 0,
			"target_kind": target_kind,
			"target_placement_id": target_id,
			"target_label": target_label,
			"target_x": x,
			"target_y": y,
			"goal_x": x,
			"goal_y": y,
			"target_public_reason": public_reason,
			"target_reason_codes": reason_codes,
			"target_public_importance": importance,
			"target_debug_reason": public_reason,
		}
	)
	session.overworld["encounters"] = encounters

func _target_by_id(targets: Array, placement_id: String) -> Dictionary:
	for target in targets:
		if target is Dictionary and String(target.get("placement_id", "")) == placement_id:
			return target
	return {}

func _event_by_type_and_target(events: Array, event_type: String, target_id: String) -> Dictionary:
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) == event_type and String(event.get("target_id", "")) == target_id:
			return event
	return {}

func _assert_event(event: Dictionary, event_type: String, target_id: String, required_codes: Array) -> void:
	if event.is_empty():
		_fail("Missing event %s for %s" % [event_type, target_id])
		return
	if String(event.get("event_type", "")) != event_type:
		_fail("Expected event type %s, got %s" % [event_type, event.get("event_type", "")])
		return
	if String(event.get("target_id", "")) != target_id:
		_fail("Expected target %s, got %s" % [target_id, event.get("target_id", "")])
		return
	if String(event.get("public_reason", "")) == "":
		_fail("%s missing public reason" % event_type)
		return
	for code in required_codes:
		if String(code) not in event.get("reason_codes", []):
			_fail("%s missing reason code %s in %s" % [event_type, code, event.get("reason_codes", [])])
			return
	_assert_event_compact(event_type, event)

func _assert_event_compact(label: String, event: Dictionary) -> void:
	for key in ["base_value", "persistent_income_value", "recruit_value", "scarcity_value", "denial_value", "route_pressure_value", "town_enablement_value", "resource_affinity_value", "weighted_claim_value", "weighted_income_value", "objective_value", "faction_bias", "travel_cost", "guard_cost", "assignment_penalty", "final_priority"]:
		if event.has(key):
			_fail("%s leaked score key %s" % [label, key])
			return

func _assert_no_score_leak(label: String, text: String) -> void:
	for needle in ["base_value", "persistent_income_value", "resource_affinity_value", "weighted_claim_value", "weighted_income_value", "final_priority", "assignment_penalty", "route_pressure_value", "denial_value"]:
		if text.contains(needle):
			_fail("%s leaked score token %s" % [label, needle])
			return

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
	_fail("Could not find resource placement %s" % placement_id)

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _enemy_state() -> Dictionary:
	return {
		"faction_id": FACTION_ID,
		"pressure": 0,
		"treasury": {},
		"raid_counter": 0,
		"commander_counter": 0,
		"commander_roster": [],
	}

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"error": message,
	}
	push_error(message)
	print("AI_EVENT_SURFACING_REPORT %s" % JSON.stringify(payload))
	_failed = true
	get_tree().quit(1)
