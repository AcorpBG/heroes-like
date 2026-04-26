extends Node

const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const PRIMARY_SITE := "river_free_company"
const COMPANION_SITE := "river_signal_post"
const SIMPLE_PICKUPS := ["north_timber", "southern_ore", "eastern_cache"]
const SCORE_KEYS := [
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"guard_cost",
	"assignment_penalty",
	"final_priority",
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _base_session()
	_set_resource_controller(session, COMPANION_SITE, "player")
	_set_resource_controller(session, PRIMARY_SITE, "player")

	var config := _enemy_config()
	var origin := {"x": 7, "y": 1}
	var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, FACTION_ID, 0)
	var targets: Array = resource_report.get("targets", [])
	var target_ids := _target_ids(targets)
	_assert_resource_order(target_ids)
	if _failed:
		return

	var free_company := _target_by_id(targets, PRIMARY_SITE)
	var signal_post := _target_by_id(targets, COMPANION_SITE)
	if free_company.is_empty() or signal_post.is_empty():
		_fail("Missing signal-yard targets in site-control resource report")
		return

	_assert_public_reason(free_company, "free company target", "recruit and income denial", ["persistent_income_denial", "recruit_denial", "player_town_support"])
	_assert_public_reason(signal_post, "signal post target", "income and route vision denial", ["persistent_income_denial", "route_vision", "player_town_support"])
	if _failed:
		return

	var assignment_event := _assignment_event_from_breakdown(session, config, free_company)
	_assert_event(
		assignment_event,
		"ai_target_assigned",
		PRIMARY_SITE,
		"recruit and income denial",
		["persistent_income_denial", "recruit_denial", "player_town_support"]
	)
	if _failed:
		return

	var chosen := EnemyAdventureRules.choose_target(session, config, origin)

	var seizure_case := _run_seizure_case()
	var seizure_event: Dictionary = seizure_case.get("event", {})
	_assert_event(
		seizure_event,
		"ai_site_seized",
		PRIMARY_SITE,
		"recruit and income denial",
		["site_seized", "persistent_income_denial", "recruit_denial"]
	)
	if not String(seizure_case.get("message", "")).contains("denies its logistics route"):
		_fail("Resource seizure message did not keep compact logistics denial wording")
		return
	if String(seizure_case.get("controller_after", "")) != FACTION_ID:
		_fail("Expected %s controller after seizure, got %s" % [FACTION_ID, seizure_case.get("controller_after", "")])
		return
	if _failed:
		return

	var public_leak_check := _public_leak_check([assignment_event, seizure_event])
	if not bool(public_leak_check.get("ok", false)):
		_fail(String(public_leak_check.get("error", "public leak check failed")))
		return

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"selected_path": {
			"primary_site": PRIMARY_SITE,
			"companion_site": COMPANION_SITE,
			"origin": origin,
		},
		"cases": {
			"resource_ordering": true,
			"assignment_event": true,
			"countercapture_controller_flip": true,
			"signal_post_denial_reason": true,
			"public_surface_compactness": true,
		},
		"resource_order": target_ids,
		"top_resource_targets": targets.slice(0, min(5, targets.size())),
		"chosen_target_sanity": {
			"target_kind": String(chosen.get("target_kind", "")),
			"target_placement_id": String(chosen.get("target_placement_id", "")),
			"target_label": String(chosen.get("target_label", "")),
			"target_debug_reason": String(chosen.get("target_debug_reason", "")),
		},
		"assignment_event": assignment_event,
		"seizure_event": seizure_event,
		"site_controller_before": String(seizure_case.get("controller_before", "")),
		"site_controller_after": String(seizure_case.get("controller_after", "")),
		"enemy_state_delta": seizure_case.get("enemy_state_delta", {}),
		"seizure_message": String(seizure_case.get("message", "")),
		"signal_post_reason_check": {
			"public_reason": String(signal_post.get("public_reason", "")),
			"reason_codes": signal_post.get("reason_codes", []),
			"debug_reason": String(signal_post.get("debug_reason", "")),
		},
		"public_leak_check": public_leak_check,
		"caveats": [
			"Full choose_target sanity is recorded and may prefer riverwatch_hold as the town front.",
			"This report stages a deterministic raid arrival; it is not a live-client enemy-turn pacing transcript.",
			"Detailed score fields remain in report/debug resource target rows only, not public event records.",
		],
	}
	print("AI_SITE_CONTROL_PROOF_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _run_seizure_case() -> Dictionary:
	var session = _base_session()
	_set_resource_controller(session, PRIMARY_SITE, "player")
	var before := _resource_controller(session, PRIMARY_SITE)
	_add_site_raid(session)
	var before_state := _enemy_state()
	var result := EnemyAdventureRules.advance_raids(session, _enemy_config(), FACTION_ID, before_state.duplicate(true))
	var after_state: Dictionary = result.get("state", {})
	var events: Array = result.get("events", [])
	return {
		"controller_before": before,
		"controller_after": _resource_controller(session, PRIMARY_SITE),
		"enemy_state_delta": _state_delta(before_state, after_state),
		"event": _event_by_type_and_target(events, "ai_site_seized", PRIMARY_SITE),
		"events": events,
		"message": String(result.get("message", "")),
	}

func _base_session():
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session

func _assignment_event_from_breakdown(session, config: Dictionary, breakdown: Dictionary) -> Dictionary:
	var actor := {
		"placement_id": "site_control_report_free_company_raid",
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

func _add_site_raid(session) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(
		{
			"placement_id": "site_control_report_free_company_seizure_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 0,
			"y": 4,
			"difficulty": "pressure",
			"combat_seed": hash("%s:%s" % [SCENARIO_ID, "site_control_report_free_company_seizure_raid"]),
			"spawned_by_faction_id": FACTION_ID,
			"days_active": 0,
			"arrived": true,
			"goal_distance": 0,
			"target_kind": "resource",
			"target_placement_id": PRIMARY_SITE,
			"target_label": "Riverwatch Free Company Yard",
			"target_x": 0,
			"target_y": 4,
			"goal_x": 0,
			"goal_y": 4,
			"target_public_reason": "recruit and income denial",
			"target_reason_codes": ["persistent_income_denial", "recruit_denial", "player_town_support"],
			"target_public_importance": "high",
			"target_debug_reason": "denies 40 gold daily, recruit denial, player-town support",
		}
	)
	session.overworld["encounters"] = encounters

func _assert_resource_order(target_ids: Array) -> void:
	if target_ids.is_empty():
		_fail("Resource pressure report returned no targets")
		return
	if target_ids.size() < 2 or String(target_ids[0]) != PRIMARY_SITE or String(target_ids[1]) != COMPANION_SITE:
		_fail("Expected %s then %s at top of resource order, got %s" % [PRIMARY_SITE, COMPANION_SITE, target_ids])
		return
	for owned_id in [PRIMARY_SITE, COMPANION_SITE]:
		var owned_rank := target_ids.find(owned_id)
		if owned_rank < 0:
			_fail("Missing owned signal-yard site %s in resource order %s" % [owned_id, target_ids])
			return
		for pickup_id in SIMPLE_PICKUPS:
			var pickup_rank := target_ids.find(pickup_id)
			if pickup_rank >= 0 and pickup_rank < owned_rank:
				_fail("Simple pickup %s outranked owned persistent site %s: %s" % [pickup_id, owned_id, target_ids])
				return

func _assert_public_reason(record: Dictionary, label: String, expected_reason: String, required_codes: Array) -> void:
	if String(record.get("public_reason", "")) != expected_reason:
		_fail("%s expected public reason %s, got %s" % [label, expected_reason, record.get("public_reason", "")])
		return
	for code in required_codes:
		if String(code) not in record.get("reason_codes", []):
			_fail("%s missing reason code %s in %s" % [label, code, record.get("reason_codes", [])])
			return

func _assert_event(event: Dictionary, event_type: String, target_id: String, expected_reason: String, required_codes: Array) -> void:
	if event.is_empty():
		_fail("Missing event %s for %s" % [event_type, target_id])
		return
	if String(event.get("event_type", "")) != event_type:
		_fail("Expected event type %s, got %s" % [event_type, event.get("event_type", "")])
		return
	if String(event.get("target_id", "")) != target_id:
		_fail("Expected event target %s, got %s" % [target_id, event.get("target_id", "")])
		return
	if String(event.get("public_reason", "")) != expected_reason:
		_fail("%s expected public reason %s, got %s" % [event_type, expected_reason, event.get("public_reason", "")])
		return
	for code in required_codes:
		if String(code) not in event.get("reason_codes", []):
			_fail("%s missing reason code %s in %s" % [event_type, code, event.get("reason_codes", [])])
			return
	for key in SCORE_KEYS:
		if event.has(key):
			_fail("%s leaked score key %s" % [event_type, key])
			return

func _public_leak_check(events: Array) -> Dictionary:
	for event in events:
		if not (event is Dictionary):
			continue
		for key in SCORE_KEYS:
			if event.has(key):
				return {"ok": false, "error": "%s leaked score key %s" % [event.get("event_type", "event"), key]}
		var text := JSON.stringify(event)
		for key in SCORE_KEYS:
			if text.contains(key):
				return {"ok": false, "error": "%s leaked score token %s" % [event.get("event_type", "event"), key]}
	return {
		"ok": true,
		"checked_events": events.size(),
		"blocked_score_keys": SCORE_KEYS,
	}

func _state_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"pressure_before": int(before.get("pressure", 0)),
		"pressure_after": int(after.get("pressure", 0)),
		"pressure_delta": int(after.get("pressure", 0)) - int(before.get("pressure", 0)),
		"treasury_before": before.get("treasury", {}),
		"treasury_after": after.get("treasury", {}),
	}

func _target_ids(targets: Array) -> Array:
	var ids := []
	for target in targets:
		if target is Dictionary:
			ids.append(String(target.get("placement_id", "")))
	return ids

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

func _resource_controller(session, placement_id: String) -> String:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(node.get("collected_by_faction_id", ""))
	return ""

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
	print("AI_SITE_CONTROL_PROOF_REPORT %s" % JSON.stringify(payload))
	_failed = true
	get_tree().quit(1)
