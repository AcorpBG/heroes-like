extends Node

const REPORT_ID := "AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const TREASURY := {"gold": 5200, "wood": 8, "ore": 8}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_version_before := int(SessionStateStore.SAVE_VERSION)
	var normalized_checks := [
		_old_save_absence_no_task_board(),
		_future_optional_field_preservation_valid_board(),
		_future_optional_empty_board_preservation(),
		_unknown_task_fields_sanitized(),
		_unknown_enemy_state_field_isolation(),
		_save_service_payload_boundary(),
		_commander_roster_continuity_with_malformed_task_state(),
	]
	var malformed_checks := [
		_malformed_non_dictionary_task_state(),
		_malformed_task_record_tolerance(),
	]
	if _failed:
		return

	var unknown_field_checks := [
		_case_by_id(normalized_checks, "unknown_task_fields_sanitized"),
		_case_by_id(normalized_checks, "unknown_enemy_state_field_isolation"),
	]
	var failures := []
	for check in normalized_checks + malformed_checks:
		if not (check is Dictionary) or not bool(check.get("ok", false)):
			failures.append(check)
	var payload := {
		"ok": failures.is_empty(),
		"report_id": REPORT_ID,
		"schema_status": "hero_task_state_normalizer_preservation_report_only",
		"behavior_policy": "observe_normalization_only",
		"save_policy": "no_hero_task_state_producer_no_disk_write",
		"save_service_policy": "payload_boundary_only_no_ai_task_semantics",
		"save_version_before": save_version_before,
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
		"cases_reviewed": normalized_checks.size() + malformed_checks.size(),
		"normalized_enemy_state_checks": normalized_checks,
		"malformed_state_checks": malformed_checks,
		"unknown_field_isolation_checks": unknown_field_checks,
		"failures": failures,
	}
	if not bool(payload.get("ok", false)):
		_fail("Normalizer preservation report failed: %s" % JSON.stringify(payload))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _old_save_absence_no_task_board() -> Dictionary:
	var session = _base_session()
	EnemyTurnRules.normalize_enemy_states(session)
	var state := _enemy_state(session, MIRECLAW)
	var ok := not state.has("hero_task_state")
	return {
		"case_id": "old_save_absence_no_task_board",
		"ok": ok,
		"scenario_id": RIVER_PASS,
		"faction_id": MIRECLAW,
		"input_present": false,
		"normalized_present": state.has("hero_task_state"),
		"input_task_count": 0,
		"normalized_task_count": 0,
		"expected_policy": "missing_field_means_no_saved_tasks",
		"observed_policy": "absent_preserved" if ok else "unexpected_empty_board_injected",
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
		"notes": [],
	}

func _future_optional_field_preservation_valid_board() -> Dictionary:
	var session = _base_session()
	var input_board := _task_board([_valid_task()])
	_put_task_state(session, input_board)
	var helper_report := EnemyTurnRules.normalize_optional_hero_task_state(input_board)
	EnemyTurnRules.normalize_enemy_states(session)
	var state := _enemy_state(session, MIRECLAW)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var task: Dictionary = tasks[0] if tasks.size() == 1 and tasks[0] is Dictionary else {}
	var ok := (
		state.has("hero_task_state")
		and int(task_state.get("schema_version", 0)) == 1
		and int(task_state.get("planner_epoch", -1)) == 3
		and tasks.size() == 1
		and String(task.get("task_id", "")) == String(_valid_task().get("task_id", ""))
		and not _has_sanitized_task_tokens(task_state)
	)
	return _case_payload(
		"future_optional_field_preservation_valid_board",
		ok,
		true,
		state.has("hero_task_state"),
		int(helper_report.get("input_task_count", 0)),
		tasks.size(),
		"preserve_explicit_optional_field_only",
		String(helper_report.get("observed_policy", "")),
		[]
	)

func _future_optional_empty_board_preservation() -> Dictionary:
	var session = _base_session()
	var input_board := _task_board([])
	_put_task_state(session, input_board)
	EnemyTurnRules.normalize_enemy_states(session)
	var state := _enemy_state(session, MIRECLAW)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var ok := state.has("hero_task_state") and tasks.is_empty()
	return _case_payload(
		"future_optional_empty_board_preservation",
		ok,
		true,
		state.has("hero_task_state"),
		0,
		tasks.size(),
		"preserve_explicit_empty_optional_field",
		"empty_board_preserved",
		[]
	)

func _malformed_non_dictionary_task_state() -> Dictionary:
	var session = _base_session()
	_put_task_state(session, "not a task board")
	var helper_report := EnemyTurnRules.normalize_optional_hero_task_state("not a task board")
	EnemyTurnRules.normalize_enemy_states(session)
	var state := _enemy_state(session, MIRECLAW)
	var ok := not state.has("hero_task_state") and not bool(helper_report.get("ok", true))
	return _case_payload(
		"malformed_non_dictionary_task_state",
		ok,
		true,
		state.has("hero_task_state"),
		0,
		0,
		"drop_invalid_optional_field",
		String(helper_report.get("observed_policy", "")),
		[String(helper_report.get("invalid_reason", ""))]
	)

func _malformed_task_record_tolerance() -> Dictionary:
	var session = _base_session()
	var input_board := _task_board([
		"not a task record",
		{"task_id": "task:missing:fields"},
		_valid_task({"task_id": "task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_2:seq_1", "assigned_day": 2}),
	])
	_put_task_state(session, input_board)
	var helper_report := EnemyTurnRules.normalize_optional_hero_task_state(input_board)
	EnemyTurnRules.normalize_enemy_states(session)
	var state := _enemy_state(session, MIRECLAW)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var roster_ok := _commander_roster_continuity_ok(session)
	var ok := state.has("hero_task_state") and tasks.size() == 1 and int(helper_report.get("dropped_task_count", 0)) == 2 and roster_ok
	return _case_payload(
		"malformed_task_record_tolerance",
		ok,
		true,
		state.has("hero_task_state"),
		int(helper_report.get("input_task_count", 0)),
		tasks.size(),
		"drop_invalid_task_records_keep_valid_records",
		String(helper_report.get("observed_policy", "")),
		["dropped_task_count:%d" % int(helper_report.get("dropped_task_count", 0))]
	)

func _unknown_task_fields_sanitized() -> Dictionary:
	var session = _base_session()
	var input_board := _task_board([
		_valid_task({
			"debug_score": 999,
			"fixture_state": {"source": "test"},
			"route_tiles": [{"x": 1, "y": 2}],
			"approach": {"x": 2, "y": 3},
			"public_reason": "internal route scoring",
			"target_label": "Free Company",
			"target_x": 4,
			"target_y": 5,
		})
	])
	_put_task_state(session, input_board)
	var helper_report := EnemyTurnRules.normalize_optional_hero_task_state(input_board)
	EnemyTurnRules.normalize_enemy_states(session)
	var state := _enemy_state(session, MIRECLAW)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var ok := state.has("hero_task_state") and not _has_sanitized_task_tokens(task_state) and int(helper_report.get("sanitized_field_count", 0)) >= 7
	return _case_payload(
		"unknown_task_fields_sanitized",
		ok,
		true,
		state.has("hero_task_state"),
		1,
		_task_count(task_state),
		"sanitize_unknown_task_fields",
		String(helper_report.get("observed_policy", "")),
		["sanitized_field_count:%d" % int(helper_report.get("sanitized_field_count", 0))]
	)

func _unknown_enemy_state_field_isolation() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session, MIRECLAW)
	state["hero_task_state"] = _task_board([_valid_task()])
	state["debug_ai_blob"] = {"score": 99}
	state["temporary_planner_state"] = {"route_tiles": []}
	state["future_magic_state"] = {"spell": "debug"}
	_set_enemy_state(session, MIRECLAW, state)
	EnemyTurnRules.normalize_enemy_states(session)
	var normalized := _enemy_state(session, MIRECLAW)
	var forbidden := ["debug_ai_blob", "temporary_planner_state", "future_magic_state"]
	var ok := normalized.has("hero_task_state")
	for key in forbidden:
		if normalized.has(key):
			ok = false
	return _case_payload(
		"unknown_enemy_state_field_isolation",
		ok,
		true,
		normalized.has("hero_task_state"),
		1,
		_task_count(normalized.get("hero_task_state", {})),
		"preserve_only_known_state_plus_explicit_task_state",
		"unknown_enemy_state_fields_dropped",
		["normalized_state_keys:%s" % JSON.stringify(normalized.keys())]
	)

func _save_service_payload_boundary() -> Dictionary:
	var session = _base_session()
	_put_task_state(session, _task_board([_valid_task()]))
	var payload: Dictionary = session.to_dict()
	var normalized_payload := SessionStateStore.normalize_payload(payload)
	var save_service_text := ""
	var handle := FileAccess.open("res://scripts/autoload/SaveService.gd", FileAccess.READ)
	if handle != null:
		save_service_text = handle.get_as_text()
	var save_service_has_task_semantics := (
		save_service_text.contains("hero_task_state")
		or save_service_text.contains("ai_hero_task")
		or save_service_text.contains("task_class")
	)
	var overworld: Dictionary = normalized_payload.get("overworld", {}) if normalized_payload.get("overworld", {}) is Dictionary else {}
	var states: Array = overworld.get("enemy_states", []) if overworld.get("enemy_states", []) is Array else []
	var preserved_by_payload_boundary := false
	for state_value in states:
		if state_value is Dictionary and String(state_value.get("faction_id", "")) == MIRECLAW:
			preserved_by_payload_boundary = state_value.has("hero_task_state")
	var ok := (
		not save_service_has_task_semantics
		and preserved_by_payload_boundary
		and int(normalized_payload.get("save_version", 0)) == int(SessionStateStore.SAVE_VERSION)
	)
	return _case_payload(
		"save_service_payload_boundary",
		ok,
		true,
		preserved_by_payload_boundary,
		1,
		1 if preserved_by_payload_boundary else 0,
		"payload_boundary_only_no_ai_task_semantics",
		"session_payload_normalized_without_save_service_semantics",
		["save_service_semantics:%s" % str(save_service_has_task_semantics)]
	)

func _commander_roster_continuity_with_malformed_task_state() -> Dictionary:
	var session = _base_session()
	var before := _commander_roster_signature(session)
	var state := _enemy_state(session, MIRECLAW)
	state["treasury"] = TREASURY.duplicate(true)
	state["hero_task_state"] = {"schema_version": 1, "planner_epoch": 4, "tasks": [{"task_id": "task:bad"}]}
	_set_enemy_state(session, MIRECLAW, state)
	EnemyTurnRules.normalize_enemy_states(session)
	var after := _commander_roster_signature(session)
	var normalized_state := _enemy_state(session, MIRECLAW)
	var ok := before == after and normalized_state.has("hero_task_state") and _task_count(normalized_state.get("hero_task_state", {})) == 0
	return _case_payload(
		"commander_roster_continuity_with_malformed_task_state",
		ok,
		true,
		normalized_state.has("hero_task_state"),
		1,
		0,
		"malformed_task_records_do_not_corrupt_roster",
		"roster_continuity_preserved",
		["before_count:%d" % before.size(), "after_count:%d" % after.size()]
	)

func _task_board(tasks: Array) -> Dictionary:
	return {
		"schema_version": 1,
		"planner_epoch": 3,
		"tasks": tasks,
	}

func _valid_task(patch: Dictionary = {}) -> Dictionary:
	var task := {
		"task_id": "task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_1:seq_1",
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": "hero_vaska",
		"source_kind": "commander_role_adapter",
		"source_id": "role:river-pass:faction_mireclaw:hero_vaska:retaker:resource:river_free_company:day_1",
		"task_class": "retake_site",
		"task_status": "planned",
		"target_kind": "resource",
		"target_id": "river_free_company",
		"front_id": "riverwatch_signal_yard",
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"priority_reason_codes": ["persistent_income_denial", "recruit_denial"],
		"assigned_day": 1,
		"expires_day": 4,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": "valid",
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "resource:river_free_company",
		},
	}
	for key in patch.keys():
		task[key] = patch[key]
	return task

func _case_payload(
	case_id: String,
	ok: bool,
	input_present: bool,
	normalized_present: bool,
	input_task_count: int,
	normalized_task_count: int,
	expected_policy: String,
	observed_policy: String,
	notes: Array
) -> Dictionary:
	return {
		"case_id": case_id,
		"ok": ok,
		"scenario_id": RIVER_PASS,
		"faction_id": MIRECLAW,
		"input_present": input_present,
		"normalized_present": normalized_present,
		"input_task_count": input_task_count,
		"normalized_task_count": normalized_task_count,
		"expected_policy": expected_policy,
		"observed_policy": observed_policy,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
		"notes": notes,
	}

func _base_session():
	var session = ScenarioFactory.create_session(RIVER_PASS, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _put_task_state(session, task_state: Variant) -> void:
	var state := _enemy_state(session, MIRECLAW)
	state["hero_task_state"] = task_state
	_set_enemy_state(session, MIRECLAW, state)

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state_value in session.overworld.get("enemy_states", []):
		if state_value is Dictionary and String(state_value.get("faction_id", "")) == faction_id:
			return state_value.duplicate(true)
	return {}

func _set_enemy_state(session, faction_id: String, state: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if states[index] is Dictionary and String(states[index].get("faction_id", "")) == faction_id:
			states[index] = state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not set enemy state for %s" % faction_id)

func _task_count(task_state_value: Variant) -> int:
	if not (task_state_value is Dictionary):
		return 0
	var tasks = task_state_value.get("tasks", [])
	return tasks.size() if tasks is Array else 0

func _has_sanitized_task_tokens(value: Variant) -> bool:
	var text := JSON.stringify(value)
	for token in ["debug_score", "fixture_state", "route_tiles", "approach", "public_reason", "target_label", "target_x", "target_y"]:
		if text.contains(token):
			return true
	return false

func _commander_roster_signature(session) -> Array:
	var signature := []
	var state := _enemy_state(session, MIRECLAW)
	for entry_value in state.get("commander_roster", []):
		if not (entry_value is Dictionary):
			continue
		signature.append({
			"roster_hero_id": String(entry_value.get("roster_hero_id", "")),
			"status": String(entry_value.get("status", "")),
			"active_placement_id": String(entry_value.get("active_placement_id", "")),
			"recovery_day": int(entry_value.get("recovery_day", 0)),
		})
	return signature

func _commander_roster_continuity_ok(session) -> bool:
	var signature := _commander_roster_signature(session)
	return signature.size() >= 2

func _case_by_id(cases: Array, case_id: String) -> Dictionary:
	for case_value in cases:
		if case_value is Dictionary and String(case_value.get("case_id", "")) == case_id:
			return case_value
	return {}

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
