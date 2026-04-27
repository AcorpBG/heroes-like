extends Node

const REPORT_ID := "AI_PUBLIC_EVENT_LOG_BOUNDARY_REPORT"
const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_version_before := int(SessionStateStore.SAVE_VERSION)
	var session = _base_session()
	_set_resource_controller(session, "river_signal_post", "player")
	_set_resource_controller(session, "river_free_company", "player")
	var config := _enemy_config()
	var origin := {"x": 7, "y": 1}
	var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, FACTION_ID, 0)
	var free_company := _target_by_id(resource_report.get("targets", []), "river_free_company")
	if free_company.is_empty():
		_fail("Missing Riverwatch Free Company target in resource pressure report")
		return

	var assignment_event := _assignment_event_from_breakdown(session, config, free_company, "boundary_commander_free_company")
	assignment_event["summary"] = "debug_reason final_priority score_ref target_debug_reason"
	assignment_event["score_ref"] = "resource_score_breakdown:river_free_company"
	assignment_event["resource_score_breakdown"] = free_company
	assignment_event["final_priority"] = int(free_company.get("final_priority", 0))

	var chosen := EnemyAdventureRules.choose_target(session, config, origin)
	var pressure_event := EnemyAdventureRules.ai_pressure_summary_event(session, config, chosen, {})

	var seizure_result := _run_arrival_case(
		"river_free_company_boundary_seizure_raid",
		0,
		4,
		"river_free_company",
		"Riverwatch Free Company Yard",
		"recruit and income denial",
		["persistent_income_denial", "recruit_denial", "player_town_support"],
		"high"
	)
	var seizure_event := _event_by_type_and_target(seizure_result.get("events", []), "ai_site_seized", "river_free_company")
	if seizure_event.is_empty():
		_fail("Resource seizure did not produce ai_site_seized")
		return

	var hidden_debug_event := assignment_event.duplicate(true)
	hidden_debug_event["visibility"] = "hidden_debug"
	hidden_debug_event["target_id"] = "hidden_debug_target"
	hidden_debug_event["target_label"] = "Hidden debug target"
	var scored_event := assignment_event.duplicate(true)
	scored_event["event_type"] = "ai_target_scored"
	scored_event["target_id"] = "report_only_score"

	var source_events := [
		assignment_event,
		pressure_event,
		seizure_event,
		hidden_debug_event,
		scored_event,
	]
	var boundary_report := EnemyAdventureRules.ai_public_event_log_boundary_report(source_events, 3)
	var public_events: Array = boundary_report.get("public_events", [])
	_assert_boundary_report(boundary_report, save_version_before, 3)
	if _failed:
		return
	_assert_public_event(public_events, "ai_target_assigned", "river_free_company", ["persistent_income_denial", "recruit_denial"])
	_assert_public_event(public_events, "ai_pressure_summary", "riverwatch_hold", ["town_siege", "objective_front"])
	_assert_public_event(public_events, "ai_site_seized", "river_free_company", ["site_seized", "persistent_income_denial", "recruit_denial"])
	_assert_no_public_event(public_events, "hidden_debug_target")
	_assert_no_public_event(public_events, "report_only_score")
	if _failed:
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"boundary_policy": "derived_ephemeral_report_only",
		"save_version_before": save_version_before,
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
		"durable_log_selected": false,
		"public_event_count": public_events.size(),
		"public_events": public_events,
		"leak_check": boundary_report.get("leak_check", {}),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_boundary_report(report: Dictionary, save_version_before: int, expected_public_count: int) -> void:
	if not bool(report.get("ok", false)):
		_fail("Boundary report failed: %s" % JSON.stringify(report))
		return
	if int(report.get("public_event_count", -1)) != expected_public_count:
		_fail("Expected %d public events, got %s" % [expected_public_count, report.get("public_event_count", -1)])
		return
	if bool(report.get("durable_log_selected", true)):
		_fail("Boundary report unexpectedly selected a durable log")
		return
	if bool(report.get("save_migration_required", true)):
		_fail("Boundary report unexpectedly requires save migration")
		return
	if int(SessionStateStore.SAVE_VERSION) != save_version_before:
		_fail("SAVE_VERSION changed during public event boundary report")
		return
	var session = _base_session()
	if session.overworld.has("ai_public_event_log") or session.overworld.has("recent_ai_events"):
		_fail("Base session unexpectedly contains durable AI event log fields")
		return

func _assert_public_event(public_events: Array, event_type: String, target_id: String, required_codes: Array) -> void:
	var event := _event_by_type_and_target(public_events, event_type, target_id)
	if event.is_empty():
		_fail("Missing public event %s for %s" % [event_type, target_id])
		return
	if String(event.get("summary", "")) == "":
		_fail("%s for %s did not retain a public summary" % [event_type, target_id])
		return
	if String(event.get("public_reason", "")) == "":
		_fail("%s for %s did not retain a public reason" % [event_type, target_id])
		return
	for code in required_codes:
		if String(code) not in event.get("reason_codes", []):
			_fail("%s for %s missing reason code %s" % [event_type, target_id, code])
			return
	_assert_public_event_safe(event_type, event)

func _assert_no_public_event(public_events: Array, target_id: String) -> void:
	for event_value in public_events:
		if event_value is Dictionary and String(event_value.get("target_id", "")) == target_id:
			_fail("Public event log leaked filtered target %s" % target_id)
			return

func _assert_public_event_safe(label: String, event: Dictionary) -> void:
	var leak_check := EnemyAdventureRules.ai_public_event_log_leak_check([event])
	if not bool(leak_check.get("ok", false)):
		_fail("%s failed public leak check: %s" % [label, leak_check.get("error", "")])
		return
	for key in event.keys():
		if String(key) not in [
			"day",
			"event_type",
			"faction_id",
			"faction_label",
			"actor_label",
			"target_kind",
			"target_id",
			"target_label",
			"visibility",
			"public_importance",
			"summary",
			"reason_codes",
			"public_reason",
		]:
			_fail("%s leaked non-public key %s" % [label, key])
			return

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
	raid_id: String,
	x: int,
	y: int,
	target_id: String,
	target_label: String,
	public_reason: String,
	reason_codes: Array,
	importance: String
) -> Dictionary:
	var session = _base_session()
	_set_resource_controller(session, target_id, "player")
	_add_report_raid(session, raid_id, x, y, target_id, target_label, public_reason, reason_codes, importance)
	var result := EnemyAdventureRules.advance_raids(session, _enemy_config(), FACTION_ID, _enemy_state())
	if result.get("events", []) is Array and not result.get("events", []).is_empty():
		return result
	_fail("%s did not produce an AI event" % raid_id)
	return {}

func _add_report_raid(
	session,
	raid_id: String,
	x: int,
	y: int,
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
			"target_kind": "resource",
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

func _base_session():
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session

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
		"report_id": REPORT_ID,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"error": message,
	}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
