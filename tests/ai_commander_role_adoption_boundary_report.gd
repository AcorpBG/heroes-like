extends Node

const REPORT_ID := "AI_COMMANDER_ROLE_ADOPTION_BOUNDARY_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var state_report := _state_report_signal()
	var turn_report := _turn_report_signal()
	var boundary := EnemyAdventureRules.commander_role_adoption_boundary_report(
		state_report,
		turn_report,
		{
			"day": 1,
			"faction_id": MIRECLAW,
			"faction_label": "Mireclaw Compact",
		}
	)
	_assert_boundary(boundary)
	if _failed:
		return
	var payload := boundary.duplicate(true)
	payload["report_id"] = REPORT_ID
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _state_report_signal() -> Dictionary:
	return {
		"ok": true,
		"report_id": "AI_COMMANDER_ROLE_STATE_REPORT",
		"schema_status": "report_fixture_only",
		"day": 1,
		"cases": [
			{"case_id": "mireclaw_free_company_retaker", "ok": true},
			{"case_id": "mireclaw_free_company_raider", "ok": true},
			{"case_id": "mireclaw_signal_post_companion", "ok": true},
			{"case_id": "embercourt_glassroad_relay_defender", "ok": true},
			{"case_id": "embercourt_glassroad_relay_retaker", "ok": true},
			{"case_id": "embercourt_glassroad_stabilizer", "ok": true},
			{"case_id": "commander_recovery_blocks_assignment", "ok": true},
			{"case_id": "commander_memory_continuity", "ok": true},
		],
		"public_leak_check": {"ok": true, "checked_events": 8},
	}

func _turn_report_signal() -> Dictionary:
	return {
		"ok": true,
		"report_id": "AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT",
		"schema_status": "derived_turn_transcript_report_only",
		"behavior_policy": "observe_existing_enemy_turn_only",
		"save_policy": "no_commander_role_state_write",
		"cases": [
			_turn_case("river_pass_mireclaw_signal_yard_turn", "river_free_company", 11, 4),
			_turn_case("glassroad_embercourt_relay_turn", "glassroad_watch_relay", 10, 5),
		],
		"public_leak_check": {"ok": true, "checked_events": 21},
	}

func _turn_case(case_id: String, arrival_target_id: String, public_event_count: int, town_ref_count: int) -> Dictionary:
	var public_events := []
	for index in range(public_event_count):
		public_events.append({"event_type": "ai_commander_role_observed", "sequence": index})
	var town_refs := []
	for index in range(town_ref_count):
		town_refs.append({"event_type": "ai_town_built", "sequence": index})
	return {
		"case_id": case_id,
		"ok": true,
		"phase_records": [{}, {}, {}, {}, {}, {}, {}, {}, {}],
		"raid_arrival_summary": [{"target_kind": "resource", "target_id": arrival_target_id}],
		"target_no_op_records": [{"no_op_reason": "target_unchanged"}],
		"town_governor_supporting_event_refs": town_refs,
		"public_transcript_events": public_events,
	}

func _assert_boundary(boundary: Dictionary) -> void:
	if not bool(boundary.get("ok", false)):
		_fail("Adoption boundary report failed: %s" % JSON.stringify(boundary))
		return
	if String(boundary.get("schema_status", "")) != "commander_role_adoption_boundary_report_only":
		_fail("Unexpected boundary schema status %s" % String(boundary.get("schema_status", "")))
		return
	if String(boundary.get("behavior_policy", "")) != "no_live_commander_role_behavior_adoption":
		_fail("Unexpected behavior policy %s" % String(boundary.get("behavior_policy", "")))
		return
	if String(boundary.get("save_policy", "")) != "no_commander_role_state_write":
		_fail("Unexpected save policy %s" % String(boundary.get("save_policy", "")))
		return
	if int(boundary.get("save_version_before", -1)) != int(SessionStateStore.SAVE_VERSION) or int(boundary.get("save_version_after", -1)) != int(SessionStateStore.SAVE_VERSION):
		_fail("Boundary changed save version: %s" % JSON.stringify(boundary))
		return
	if bool(boundary.get("live_behavior_selected", true)) or bool(boundary.get("save_write_selected", true)) or bool(boundary.get("requires_save_migration", true)):
		_fail("Boundary selected forbidden live/save adoption: %s" % JSON.stringify(boundary))
		return
	var expected_status := {
		"derived_role_proposals": "adopt_report_only",
		"turn_transcript": "adopt_report_only",
		"compact_public_events": "adopt_report_only",
		"town_governor_refs": "adopt_report_only",
		"commander_role_state_write": "defer",
		"save_migration": "defer",
		"live_commander_role_behavior": "defer",
		"durable_event_log": "defer",
		"full_ai_hero_task_state": "defer",
	}
	var records: Array = boundary.get("boundary_records", [])
	for surface_id in expected_status.keys():
		var record := _record_by_surface(records, String(surface_id))
		if record.is_empty():
			_fail("Missing boundary record %s" % String(surface_id))
			return
		if String(record.get("boundary_status", "")) != String(expected_status[surface_id]):
			_fail("Unexpected status for %s: %s" % [String(surface_id), JSON.stringify(record)])
			return
		if bool(record.get("live_behavior_selected", true)) or bool(record.get("save_write_selected", true)) or bool(record.get("requires_save_migration", true)):
			_fail("Record selected forbidden adoption %s" % JSON.stringify(record))
			return
	var leak_check: Dictionary = boundary.get("public_leak_check", {}) if boundary.get("public_leak_check", {}) is Dictionary else {}
	if not bool(leak_check.get("ok", false)) or int(leak_check.get("checked_events", 0)) != expected_status.size():
		_fail("Public boundary leak check failed: %s" % JSON.stringify(leak_check))
		return
	var public_events: Array = boundary.get("public_boundary_events", [])
	if public_events.size() != expected_status.size():
		_fail("Expected %d public boundary events, got %d" % [expected_status.size(), public_events.size()])
		return
	for event in public_events:
		if not (event is Dictionary):
			_fail("Public boundary event is not a dictionary")
			return
		if String(event.get("event_type", "")) != "ai_commander_role_boundary":
			_fail("Unexpected public boundary event type %s" % String(event.get("event_type", "")))
			return

func _record_by_surface(records: Array, surface_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("surface_id", "")) == surface_id:
			return record
	return {}

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"report_id": REPORT_ID,
		"error": message,
	}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
