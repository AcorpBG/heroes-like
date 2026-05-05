extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_MEDIUM_LAND_START_COVERAGE_REGRESSION_REPORT"
const TEST_SEED := "medium-4-land-start-coverage-regression-10184"
const SIZE_CLASS_ID := "homm3_medium"
const TEMPLATE_ID := "translated_rmg_template_002_v1"
const PROFILE_ID := "translated_rmg_profile_002_v1"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()

	var direct_config := ScenarioSelectRulesScript.build_random_map_player_config(
		TEST_SEED,
		TEMPLATE_ID,
		PROFILE_ID,
		4,
		"land",
		false,
		SIZE_CLASS_ID
	)
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var direct: Dictionary = service.generate_random_map(direct_config, {"startup_path": "medium_land_start_coverage_regression"})
	if not _assert_direct_validation(direct):
		return

	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	if not bool(shell.call("validation_set_generated_seed", TEST_SEED)):
		_fail("Seed hook did not accept the medium land regression seed.")
		return
	if not bool(shell.call("validation_select_generated_size_class", SIZE_CLASS_ID)):
		_fail("Size-class hook did not select Medium.")
		return
	if not bool(shell.call("validation_select_generated_player_count", 4)):
		_fail("Player-count hook did not select four players.")
		return
	if not bool(shell.call("validation_select_generated_water_mode", "land")):
		_fail("Water-mode hook did not select land.")
		return
	if not bool(shell.call("validation_set_generated_underground", false)):
		_fail("Underground hook did not disable underground.")
		return

	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_medium_land_snapshot(snapshot):
		return

	var result: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(result.get("started", false)):
		_fail("Medium 4-player land/no-underground launch failed validation: %s" % JSON.stringify(result))
		return
	if not _assert_launch_identity(result):
		return

	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": TEST_SEED,
		"template_id": TEMPLATE_ID,
		"profile_id": PROFILE_ID,
		"direct_validation_status": _validation_report(direct).get("validation_status", _validation_report(direct).get("status", "")),
		"direct_failure_count": int(_validation_report(direct).get("failure_count", 0)),
		"retry_attempts": _compact_retry_attempts(_launch_retry_attempts(result)),
	})])
	get_tree().quit(0)

func _assert_direct_validation(result: Dictionary) -> bool:
	var report := _validation_report(result)
	if not bool(result.get("ok", false)):
		_fail("Direct native medium land generation failed: %s" % JSON.stringify(_compact_generation_result(result)))
		return false
	if String(report.get("validation_status", report.get("status", ""))) != "pass":
		_fail("Direct native medium land validation did not pass: %s" % JSON.stringify(_compact_validation_report(report)))
		return false
	if int(report.get("failure_count", 0)) != 0:
		_fail("Direct native medium land validation produced failures: %s" % JSON.stringify(_compact_validation_report(report)))
		return false
	var connection_summary: Dictionary = report.get("connection_payload_summary", {}) if report.get("connection_payload_summary", {}) is Dictionary else {}
	if String(connection_summary.get("validation_status", "")) != "pass":
		_fail("Medium land connection payload validation did not pass: %s" % JSON.stringify(connection_summary))
		return false
	return true

func _assert_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_open_skirmish_stage",
		"validation_set_generated_seed",
		"validation_select_generated_size_class",
		"validation_select_generated_player_count",
		"validation_select_generated_water_mode",
		"validation_set_generated_underground",
		"validation_generated_random_map_snapshot",
		"validation_start_generated_skirmish_staged",
	]:
		if not shell.has_method(method_name):
			_fail("Main menu missing generated-map hook %s." % method_name)
			return false
	return true

func _assert_medium_land_snapshot(snapshot: Dictionary) -> bool:
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	var internal_provenance: Dictionary = controls.get("internal_template_provenance", {}) if controls.get("internal_template_provenance", {}) is Dictionary else {}
	if String(controls.get("size_class_id", "")) != SIZE_CLASS_ID:
		_fail("Medium land snapshot did not preserve size class: %s" % JSON.stringify(controls))
		return false
	if int(controls.get("player_count", 0)) != 4 or String(controls.get("water_mode", "")) != "land" or bool(controls.get("underground", true)):
		_fail("Medium land snapshot did not preserve player/water/underground controls: %s" % JSON.stringify(controls))
		return false
	if String(internal_provenance.get("selection_source", "")) != "homm3_size_class_default":
		_fail("Medium land snapshot did not derive template/profile from size defaults: %s" % JSON.stringify(internal_provenance))
		return false
	if String(internal_provenance.get("template_id", "")) != TEMPLATE_ID or String(internal_provenance.get("profile_id", "")) != PROFILE_ID:
		_fail("Medium land snapshot selected the wrong template/profile: %s" % JSON.stringify(internal_provenance))
		return false
	if not bool(snapshot.get("start_enabled", false)):
		_fail("Medium land generated launch was disabled before validation: %s" % JSON.stringify(snapshot))
		return false
	return true

func _assert_launch_identity(result: Dictionary) -> bool:
	var active_provenance: Dictionary = result.get("active_provenance", {}) if result.get("active_provenance", {}) is Dictionary else {}
	var generated_identity: Dictionary = active_provenance.get("generated_identity", {}) if active_provenance.get("generated_identity", {}) is Dictionary else {}
	var input_config: Dictionary = active_provenance.get("input_config", {}) if active_provenance.get("input_config", {}) is Dictionary else {}
	if String(generated_identity.get("template_id", "")) != TEMPLATE_ID or String(generated_identity.get("profile_id", "")) != PROFILE_ID:
		_fail("Medium land launch used the wrong template/profile: %s" % JSON.stringify(generated_identity))
		return false
	var size_config: Dictionary = input_config.get("size", {}) if input_config.get("size", {}) is Dictionary else {}
	if String(generated_identity.get("size_class_id", "")) != SIZE_CLASS_ID or int(size_config.get("level_count", 0)) != 1:
		_fail("Medium land launch used the wrong size/underground config: %s" % JSON.stringify(active_provenance))
		return false
	var retry_attempts := _launch_retry_attempts(result)
	if retry_attempts.is_empty():
		_fail("Medium land launch did not expose retry attempts: %s" % JSON.stringify(_compact_launch_result(result)))
		return false
	var first_attempt: Dictionary = retry_attempts[0] if retry_attempts[0] is Dictionary else {}
	if int(first_attempt.get("failure_count", -1)) != 0:
		_fail("Medium land launch still reported validation failures: %s" % JSON.stringify(first_attempt))
		return false
	return true

func _launch_retry_attempts(result: Dictionary) -> Array:
	var active_provenance: Dictionary = result.get("active_provenance", {}) if result.get("active_provenance", {}) is Dictionary else {}
	var attempts: Variant = active_provenance.get("retry_attempts", result.get("retry_attempts", []))
	return attempts if attempts is Array else []

func _validation_report(result: Dictionary) -> Dictionary:
	var report: Variant = result.get("validation_report", result.get("report", {}))
	return report if report is Dictionary else {}

func _compact_generation_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", false),
		"status": result.get("status", ""),
		"validation_status": result.get("validation_status", ""),
		"template_id": result.get("normalized_config", {}).get("template_id", ""),
		"profile_id": result.get("normalized_config", {}).get("profile_id", ""),
		"report": _compact_validation_report(_validation_report(result)),
	}

func _compact_validation_report(report: Dictionary) -> Dictionary:
	return {
		"status": report.get("status", ""),
		"validation_status": report.get("validation_status", ""),
		"failure_count": report.get("failure_count", 0),
		"failures": report.get("failures", []),
		"connection_payload_summary": report.get("connection_payload_summary", {}),
	}

func _compact_launch_result(result: Dictionary) -> Dictionary:
	var active_provenance: Dictionary = result.get("active_provenance", {}) if result.get("active_provenance", {}) is Dictionary else {}
	return {
		"started": result.get("started", false),
		"active_generated_random_map": result.get("active_generated_random_map", false),
		"generated_identity": active_provenance.get("generated_identity", {}),
		"retry_attempts": _compact_retry_attempts(_launch_retry_attempts(result)),
	}

func _compact_retry_attempts(attempts: Array) -> Array:
	var compact: Array = []
	for attempt_value in attempts:
		var attempt: Dictionary = attempt_value if attempt_value is Dictionary else {}
		compact.append({
			"attempt": attempt.get("attempt", 0),
			"ok": attempt.get("ok", false),
			"failure_count": attempt.get("failure_count", 0),
			"validation_status": attempt.get("validation_status", ""),
			"template_id": attempt.get("template_id", ""),
			"profile_id": attempt.get("profile_id", ""),
		})
	return compact

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
