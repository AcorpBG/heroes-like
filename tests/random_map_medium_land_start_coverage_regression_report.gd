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
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _assert_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	if not bool(shell.call("validation_set_generated_seed", TEST_SEED)):
		_fail("Medium land menu seed hook failed.")
		return
	if not bool(shell.call("validation_select_generated_size_class", SIZE_CLASS_ID)):
		_fail("Medium land public size option was not exposed.")
		return
	if not bool(shell.call("validation_select_generated_player_count", 4)):
		_fail("Medium land public player-count hook failed.")
		return
	if not bool(shell.call("validation_select_generated_water_mode", "land")):
		_fail("Medium land public water mode hook failed.")
		return
	if bool(shell.call("validation_set_generated_underground", true)):
		_fail("Medium land public setup exposed unsupported underground.")
		return
	if bool(shell.call("validation_select_generated_water_mode", "islands")):
		_fail("Medium public setup exposed unsupported islands water mode.")
		return
	if bool(shell.call("validation_select_generated_size_class", "homm3_large")):
		_fail("Medium public setup exposed unsupported Large size.")
		return
	var menu_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_medium_land_snapshot(menu_snapshot):
		return

	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		direct_config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_fail("Medium 4-player land/no-underground setup failed validation: %s" % JSON.stringify(setup))
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or String(session.scenario_id) == "":
		_fail("Medium 4-player land/no-underground session did not start from validated setup: %s" % JSON.stringify(_compact_launch_result(setup)))
		return
	if not _assert_launch_identity(setup, session):
		return

	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": TEST_SEED,
		"template_id": TEMPLATE_ID,
		"profile_id": PROFILE_ID,
		"direct_validation_status": _validation_report(direct).get("validation_status", _validation_report(direct).get("status", "")),
		"direct_failure_count": int(_validation_report(direct).get("failure_count", 0)),
		"menu_controls": menu_snapshot.get("controls", {}),
		"session_id": session.scenario_id,
		"retry_attempts": _compact_retry_attempts(_launch_retry_attempts(setup)),
	})])
	get_tree().quit(0)

func _assert_direct_validation(result: Dictionary) -> bool:
	var report := _validation_report(result)
	if not bool(result.get("ok", false)):
		_fail("Direct native medium land generation failed: %s" % JSON.stringify(_compact_generation_result(result)))
		return false
	if String(result.get("generation_status", "")) != "h3maped_medium_validated_package_ready" \
			or String(result.get("production_ready_scope", "")) != "strict_medium_72x72_one_level_land_only":
		_fail("Direct native medium land generation did not expose public Medium package readiness: %s" % JSON.stringify(_compact_generation_result(result)))
		return false
	if String(report.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready":
		_fail("Direct native medium land validation did not pass: %s" % JSON.stringify(_compact_validation_report(report)))
		return false
	if int(report.get("failure_count", 0)) != 0:
		_fail("Direct native medium land validation produced failures: %s" % JSON.stringify(_compact_validation_report(report)))
		return false
	var metrics: Dictionary = result.get("validator_metrics", {}) if result.get("validator_metrics", {}) is Dictionary else {}
	if int(metrics.get("expected_tile_count", 0)) != 5184 \
			or int(metrics.get("player_start_count", 0)) != 4 \
			or int(metrics.get("owned_player_town_count", 0)) != 4 \
			or int(metrics.get("route_link_without_guard_count", -1)) != 0 \
			or int(metrics.get("route_link_without_blocker_count", -1)) != 0:
		_fail("Direct native medium land metrics missed required public readiness coverage: %s" % JSON.stringify(metrics))
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
	if String(internal_provenance.get("selection_source", "")) != "native_catalog_auto_on_launch":
		_fail("Medium land snapshot did not defer template/profile to native catalog auto-selection: %s" % JSON.stringify(internal_provenance))
		return false
	if String(internal_provenance.get("template_id", "")) != "native_catalog_auto" or String(internal_provenance.get("profile_id", "")) != "native_catalog_auto":
		_fail("Medium land snapshot exposed non-native-auto launch template/profile: %s" % JSON.stringify(internal_provenance))
		return false
	if String(internal_provenance.get("preview_template_id", "")) != TEMPLATE_ID or String(internal_provenance.get("preview_profile_id", "")) != PROFILE_ID:
		_fail("Medium land snapshot selected the wrong preview template/profile: %s" % JSON.stringify(internal_provenance))
		return false
	var size_options: Array = controls.get("size_options", []) if controls.get("size_options", []) is Array else []
	if size_options != ["Small 36x36", "Medium 72x72"]:
		_fail("Medium land snapshot exposed the wrong public size options: %s" % JSON.stringify(size_options))
		return false
	var water_options: Array = controls.get("water_options", []) if controls.get("water_options", []) is Array else []
	if water_options != ["Land"]:
		_fail("Medium land snapshot exposed unsupported water modes: %s" % JSON.stringify(water_options))
		return false
	var level_options: Array = controls.get("level_options", []) if controls.get("level_options", []) is Array else []
	if level_options != ["Surface Only (1 Level)"]:
		_fail("Medium land snapshot exposed unsupported level options: %s" % JSON.stringify(level_options))
		return false
	if not bool(snapshot.get("start_enabled", false)):
		_fail("Medium land generated launch was disabled before validation: %s" % JSON.stringify(snapshot))
		return false
	return true

func _assert_launch_identity(setup: Dictionary, session) -> bool:
	var active_provenance: Dictionary = setup.get("provenance", {}) if setup.get("provenance", {}) is Dictionary else {}
	var generated_identity: Dictionary = active_provenance.get("generated_identity", setup.get("generated_identity", {})) if active_provenance.get("generated_identity", setup.get("generated_identity", {})) is Dictionary else {}
	var input_config: Dictionary = active_provenance.get("input_config", {}) if active_provenance.get("input_config", {}) is Dictionary else {}
	if not String(generated_identity.get("template_id", "")).begins_with("h3maped_template_") or String(generated_identity.get("profile_id", "")) != "h3maped_exe_rng_profile":
		_fail("Medium land launch did not resolve H3MapEd source template/profile authority: %s" % JSON.stringify(generated_identity))
		return false
	var size_config: Dictionary = input_config.get("size", {}) if input_config.get("size", {}) is Dictionary else {}
	if String(generated_identity.get("size_class_id", "")) != SIZE_CLASS_ID or int(size_config.get("level_count", 0)) != 1:
		_fail("Medium land launch used the wrong size/underground config: %s" % JSON.stringify(active_provenance))
		return false
	var retry_attempts := _launch_retry_attempts(setup)
	if retry_attempts.is_empty():
		_fail("Medium land launch did not expose retry attempts: %s" % JSON.stringify(_compact_launch_result(setup)))
		return false
	var first_attempt: Dictionary = retry_attempts[0] if retry_attempts[0] is Dictionary else {}
	if int(first_attempt.get("failure_count", -1)) != 0:
		_fail("Medium land launch still reported validation failures: %s" % JSON.stringify(first_attempt))
		return false
	if not String(session.scenario_id).begins_with("h3maped_medium_scenario_"):
		_fail("Medium land launch did not start from a Medium H3MapEd package session: %s" % session.scenario_id)
		return false
	return true

func _launch_retry_attempts(result: Dictionary) -> Array:
	var active_provenance: Dictionary = result.get("active_provenance", {}) if result.get("active_provenance", {}) is Dictionary else {}
	var attempts: Variant = active_provenance.get("retry_attempts", result.get("retry_attempts", []))
	return attempts if attempts is Array else []

func _validation_report(result: Dictionary) -> Dictionary:
	var report: Variant = result.get("fast_structural_validator", result.get("validation_report", result.get("report", {})))
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
