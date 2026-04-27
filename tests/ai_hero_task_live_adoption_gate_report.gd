extends Node

const REPORT_ID := "AI_HERO_TASK_LIVE_ADOPTION_GATE_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate := EnemyAdventureRules.ai_hero_task_live_adoption_gate_report(
		_task_boundary_signal(),
		_normalizer_signal(),
		_commander_boundary_signal(),
		{
			"day": 1,
			"faction_id": MIRECLAW,
			"faction_label": "Mireclaw Compact",
		}
	)
	_assert_gate(gate)
	if _failed:
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(gate)])
	get_tree().quit(0)

func _task_boundary_signal() -> Dictionary:
	return {
		"ok": true,
		"report_id": "AI_HERO_TASK_STATE_BOUNDARY_REPORT",
		"schema_status": "task_state_boundary_report_only",
		"behavior_policy": "derive_candidate_tasks_only",
		"save_policy": "no_hero_task_state_write",
		"faction_id": MIRECLAW,
		"day": 1,
		"cases": [
			{"case_id": "river_pass_free_company_task_candidate", "ok": true},
			{"case_id": "river_pass_signal_post_companion_task_candidate", "ok": true},
			{"case_id": "glassroad_relay_retake_to_defend_transition", "ok": true},
			{"case_id": "glassroad_starlens_stabilizer_candidate", "ok": true},
			{"case_id": "commander_recovery_rebuild_blocks_task_claim", "ok": true},
			{"case_id": "old_save_no_task_state_compatibility", "ok": true},
			{"case_id": "duplicate_target_reservation_report_only", "ok": true},
		],
		"candidate_task_id_check": {"ok": true, "checked_tasks": 9},
		"old_save_absence_check": {
			"ok": true,
			"saved_task_board_present": false,
			"saved_task_count": 0,
			"write_check": "no_hero_task_state_write",
		},
		"public_leak_check": {"ok": true, "checked_events": 8},
	}

func _normalizer_signal() -> Dictionary:
	return {
		"ok": true,
		"report_id": "AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT",
		"schema_status": "hero_task_state_normalizer_preservation_report_only",
		"behavior_policy": "observe_normalization_only",
		"save_policy": "no_hero_task_state_producer_no_disk_write",
		"save_service_policy": "payload_boundary_only_no_ai_task_semantics",
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
		"cases_reviewed": 9,
		"normalized_enemy_state_checks": [],
		"malformed_state_checks": [],
		"unknown_field_isolation_checks": [],
		"failures": [],
	}

func _commander_boundary_signal() -> Dictionary:
	return {
		"ok": true,
		"report_id": "AI_COMMANDER_ROLE_ADOPTION_BOUNDARY_REPORT",
		"schema_status": "commander_role_adoption_boundary_report_only",
		"behavior_policy": "no_live_commander_role_behavior_adoption",
		"save_policy": "no_commander_role_state_write",
		"public_leak_check": {"ok": true, "checked_events": 9},
		"live_behavior_selected": false,
		"save_write_selected": false,
		"requires_save_migration": false,
	}

func _assert_gate(gate: Dictionary) -> void:
	if not bool(gate.get("ok", false)):
		_fail("Live adoption gate failed: %s" % JSON.stringify(gate))
		return
	if String(gate.get("schema_status", "")) != "live_hero_task_adoption_gate_report_only":
		_fail("Unexpected schema status: %s" % String(gate.get("schema_status", "")))
		return
	if String(gate.get("behavior_policy", "")) != "no_live_hero_task_behavior_adoption":
		_fail("Unexpected behavior policy: %s" % String(gate.get("behavior_policy", "")))
		return
	if String(gate.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Unexpected save policy: %s" % String(gate.get("save_policy", "")))
		return
	if int(gate.get("save_version_before", -1)) != int(SessionStateStore.SAVE_VERSION) or int(gate.get("save_version_after", -1)) != int(SessionStateStore.SAVE_VERSION):
		_fail("Gate changed save version: %s" % JSON.stringify(gate))
		return
	if bool(gate.get("live_behavior_selected", true)) or bool(gate.get("schema_write_selected", true)) or bool(gate.get("requires_save_migration", true)):
		_fail("Gate selected forbidden live/save adoption: %s" % JSON.stringify(gate))
		return
	var expected_status := {
		"candidate_task_reports": "ready_report_only",
		"optional_task_normalizer": "ready_report_only",
		"commander_role_boundary": "ready_report_only",
		"task_schema_writer": "defer",
		"save_migration": "defer",
		"live_target_selection": "defer",
		"route_actor_execution": "defer",
		"save_resume_live_tasks": "defer",
		"manual_pacing_review": "defer",
		"durable_event_log": "defer",
	}
	var records: Array = gate.get("gate_records", [])
	for surface_id in expected_status.keys():
		var record := _record_by_surface(records, String(surface_id))
		if record.is_empty():
			_fail("Missing live adoption gate record %s" % String(surface_id))
			return
		if String(record.get("gate_status", "")) != String(expected_status[surface_id]):
			_fail("Unexpected status for %s: %s" % [String(surface_id), JSON.stringify(record)])
			return
		if bool(record.get("live_behavior_selected", true)) or bool(record.get("save_write_selected", true)) or bool(record.get("requires_save_migration", true)):
			_fail("Record selected forbidden adoption: %s" % JSON.stringify(record))
			return
	var ready_surfaces: Array = gate.get("report_only_ready_surfaces", [])
	var deferred_surfaces: Array = gate.get("deferred_surfaces", [])
	if ready_surfaces.size() != 3 or deferred_surfaces.size() != 7:
		_fail("Unexpected ready/deferred counts: %s" % JSON.stringify(gate))
		return
	var leak_check: Dictionary = gate.get("public_leak_check", {}) if gate.get("public_leak_check", {}) is Dictionary else {}
	if not bool(leak_check.get("ok", false)) or int(leak_check.get("checked_events", 0)) != expected_status.size():
		_fail("Public gate leak check failed: %s" % JSON.stringify(leak_check))
		return
	var public_events: Array = gate.get("public_gate_events", [])
	if public_events.size() != expected_status.size():
		_fail("Expected %d public events, got %d" % [expected_status.size(), public_events.size()])
		return
	for event in public_events:
		if not (event is Dictionary):
			_fail("Public gate event is not a dictionary")
			return
		if String(event.get("event_type", "")) != "ai_hero_task_live_gate":
			_fail("Unexpected public gate event type: %s" % String(event.get("event_type", "")))
			return

func _record_by_surface(records: Array, surface_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("surface_id", "")) == surface_id:
			return record
	return {}

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
